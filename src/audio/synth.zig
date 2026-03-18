const std = @import("std");
const rl = @import("raylib");

pub const SAMPLE_RATE: u32 = 48_000;
pub const SAMPLE_SIZE_BITS: u32 = 32;
pub const CHANNELS: u32 = 1;
pub const BUFFER_FRAMES: usize = 1024;
pub const MAX_VOICES: usize = 8;

pub const InitOptions = struct {
    master_volume: f32 = 0.35,
    force_init_fail: bool = false,
    testing_enabled_without_device: bool = false,
};

pub const EventKind = enum {
    swap,
    invalid,
    shuffle,
    fall_spawn,
    match,
    bomb,
    win,
    lose,
};

pub const Event = struct {
    kind: EventKind,
    k_wave: u8 = 3,
    cascade_wave: u8 = 0,
    phase_intensity: f32 = 1.0,
};

const EVENT_KIND_COUNT: usize = @typeInfo(EventKind).@"enum".fields.len;

const Waveform = enum {
    sine,
    triangle,
    pulse,
    noise,
};

const VoicePreset = struct {
    waveform: Waveform,
    freq_hz: f32,
    gain: f32,
    duration_s: f32,
    attack_s: f32,
    release_s: f32,
    pitch_jitter: f32,
    time_jitter: f32,
    vibrato_depth: f32 = 0.0,
    vibrato_hz: f32 = 0.0,
    tremolo_depth: f32 = 0.0,
    tremolo_hz: f32 = 0.0,
    drift_depth: f32 = 0.0,
    duty: f32 = 0.35,
    duty_jitter: f32 = 0.03,
};

const Voice = struct {
    active: bool = false,
    waveform: Waveform = .sine,
    phase: f32 = 0.0,
    phase_inc: f32 = 0.0,
    duty: f32 = 0.35,
    gain: f32 = 0.0,
    total_samples: u32 = 0,
    samples_remaining: u32 = 0,
    attack_samples: u32 = 0,
    release_samples: u32 = 0,
    vibrato_phase: f32 = 0.0,
    vibrato_phase_inc: f32 = 0.0,
    vibrato_depth: f32 = 0.0,
    tremolo_phase: f32 = 0.0,
    tremolo_phase_inc: f32 = 0.0,
    tremolo_depth: f32 = 0.0,
    pitch_drift: f32 = 0.0,
    pitch_drift_depth: f32 = 0.0,
    noise_state: u32 = 0xA341316C,
};

pub const Synth = struct {
    enabled: bool = false,
    master_volume: f32 = 0.35,
    stream: ?rl.AudioStream = null,
    rng: std.Random.DefaultPrng = std.Random.DefaultPrng.init(1),
    voices: [MAX_VOICES]Voice = [_]Voice{.{}} ** MAX_VOICES,
    cooldowns: [EVENT_KIND_COUNT]f32 = [_]f32{0.0} ** EVENT_KIND_COUNT,
    trigger_counts: [EVENT_KIND_COUNT]u32 = [_]u32{0} ** EVENT_KIND_COUNT,
    frame_buffer: [BUFFER_FRAMES]f32 = [_]f32{0.0} ** BUFFER_FRAMES,

    pub fn init(self: *Synth, seed: u64, options: InitOptions) void {
        self.deinit();
        self.* = .{};
        self.rng = std.Random.DefaultPrng.init(seed);
        self.master_volume = std.math.clamp(options.master_volume, 0.0, 1.0);

        if (options.force_init_fail) {
            self.enabled = false;
            return;
        }

        if (!rl.isAudioDeviceReady()) {
            if (options.testing_enabled_without_device) {
                self.enabled = true;
                self.stream = null;
                return;
            }
            self.enabled = false;
            return;
        }

        const stream = rl.loadAudioStream(SAMPLE_RATE, SAMPLE_SIZE_BITS, CHANNELS) catch {
            if (options.testing_enabled_without_device) {
                self.enabled = true;
                self.stream = null;
                return;
            }
            self.enabled = false;
            return;
        };

        self.stream = stream;
        rl.playAudioStream(stream);
        self.enabled = true;
    }

    pub fn initForTesting(self: *Synth, seed: u64) void {
        self.deinit();
        self.* = .{};
        self.rng = std.Random.DefaultPrng.init(seed);
        self.enabled = true;
        self.stream = null;
    }

    pub fn deinit(self: *Synth) void {
        if (self.stream) |stream| {
            rl.unloadAudioStream(stream);
        }
        self.stream = null;
        self.enabled = false;
    }

    pub fn isEnabled(self: *const Synth) bool {
        return self.enabled;
    }

    pub fn activeVoiceCount(self: *const Synth) usize {
        var count: usize = 0;
        for (self.voices) |voice| {
            if (voice.active) count += 1;
        }
        return count;
    }

    pub fn triggerCount(self: *const Synth, kind: EventKind) u32 {
        return self.trigger_counts[kindIndex(kind)];
    }

    pub fn debugActiveMaxFreqHz(self: *const Synth) f32 {
        var best: f32 = 0.0;
        for (self.voices) |voice| {
            if (!voice.active) continue;
            const hz = voice.phase_inc * @as(f32, @floatFromInt(SAMPLE_RATE));
            if (hz > best) best = hz;
        }
        return best;
    }

    pub fn debugActiveGainSum(self: *const Synth) f32 {
        var sum: f32 = 0.0;
        for (self.voices) |voice| {
            if (voice.active) sum += voice.gain;
        }
        return sum;
    }

    pub fn tick(self: *Synth, dt: f32) void {
        self.updateCooldowns(dt);
        if (!self.enabled) return;

        const stream = self.stream orelse return;
        while (rl.isAudioStreamProcessed(stream)) {
            self.mixFrameBuffer();
            rl.updateAudioStream(stream, @ptrCast(self.frame_buffer[0..].ptr), @as(i32, @intCast(BUFFER_FRAMES)));
        }
    }

    pub fn trigger(self: *Synth, event: Event) void {
        if (!self.enabled) return;

        const event_idx = kindIndex(event.kind);
        if (self.cooldowns[event_idx] > 0.0) return;
        self.cooldowns[event_idx] = cooldownDuration(event.kind);
        self.trigger_counts[event_idx] += 1;

        self.emitEvent(event);
    }

    fn emitEvent(self: *Synth, event: Event) void {
        switch (event.kind) {
            .swap => {
                self.spawnPreset(.{
                    .waveform = .noise,
                    .freq_hz = 1.0,
                    .gain = 0.07,
                    .duration_s = 0.018,
                    .attack_s = 0.0005,
                    .release_s = 0.013,
                    .pitch_jitter = 0.0,
                    .time_jitter = 0.02,
                    .drift_depth = 0.0015,
                });
                self.spawnPreset(.{
                    .waveform = .pulse,
                    .freq_hz = 440.0,
                    .gain = 0.15,
                    .duration_s = 0.05,
                    .attack_s = 0.001,
                    .release_s = 0.03,
                    .pitch_jitter = 0.010,
                    .time_jitter = 0.03,
                    .vibrato_depth = 0.003,
                    .vibrato_hz = 5.0,
                    .tremolo_depth = 0.012,
                    .tremolo_hz = 4.0,
                    .drift_depth = 0.003,
                    .duty = 0.32,
                    .duty_jitter = 0.02,
                });
            },
            .invalid => self.spawnPreset(.{
                .waveform = .pulse,
                .freq_hz = 180.0,
                .gain = 0.16,
                .duration_s = 0.10,
                .attack_s = 0.001,
                .release_s = 0.065,
                .pitch_jitter = 0.010,
                .time_jitter = 0.03,
                .vibrato_depth = 0.003,
                .vibrato_hz = 4.6,
                .tremolo_depth = 0.01,
                .tremolo_hz = 3.8,
                .drift_depth = 0.003,
                .duty = 0.32,
                .duty_jitter = 0.02,
            }),
            .shuffle => {
                self.spawnPreset(.{
                    .waveform = .noise,
                    .freq_hz = 1.0,
                    .gain = 0.08,
                    .duration_s = 0.04,
                    .attack_s = 0.0005,
                    .release_s = 0.03,
                    .pitch_jitter = 0.0,
                    .time_jitter = 0.02,
                    .drift_depth = 0.0015,
                });
                self.spawnPreset(.{
                    .waveform = .pulse,
                    .freq_hz = 260.0,
                    .gain = 0.14,
                    .duration_s = 0.09,
                    .attack_s = 0.001,
                    .release_s = 0.06,
                    .pitch_jitter = 0.010,
                    .time_jitter = 0.03,
                    .vibrato_depth = 0.003,
                    .vibrato_hz = 5.2,
                    .tremolo_depth = 0.012,
                    .tremolo_hz = 4.0,
                    .drift_depth = 0.003,
                    .duty = 0.34,
                    .duty_jitter = 0.02,
                });
            },
            .fall_spawn => {
                const intensity = std.math.clamp(event.phase_intensity, 0.2, 2.0);
                self.spawnPreset(.{
                    .waveform = .pulse,
                    .freq_hz = 175.0 + 20.0 * (intensity - 1.0),
                    .gain = 0.047 * intensity,
                    .duration_s = 0.035,
                    .attack_s = 0.001,
                    .release_s = 0.02,
                    .pitch_jitter = 0.008,
                    .time_jitter = 0.03,
                    .vibrato_depth = 0.002,
                    .vibrato_hz = 4.0,
                    .tremolo_depth = 0.01,
                    .tremolo_hz = 3.6,
                    .drift_depth = 0.0025,
                    .duty = 0.35,
                    .duty_jitter = 0.02,
                });
            },
            .match => {
                const k = @as(f32, @floatFromInt(@max(event.k_wave, 3)));
                const wave = @as(f32, @floatFromInt(event.cascade_wave));
                const bright = 1.0 + (k - 3.0) * 0.12;
                const wave_boost = 1.0 + std.math.clamp(wave, 0.0, 6.0) * 0.03;

                self.spawnPreset(.{
                    .waveform = .pulse,
                    .freq_hz = 262.0 * bright,
                    .gain = 0.15 * wave_boost,
                    .duration_s = 0.085,
                    .attack_s = 0.0015,
                    .release_s = 0.055,
                    .pitch_jitter = 0.010,
                    .time_jitter = 0.03,
                    .vibrato_depth = 0.003,
                    .vibrato_hz = 5.0,
                    .tremolo_depth = 0.012,
                    .tremolo_hz = 4.0,
                    .drift_depth = 0.003,
                    .duty = 0.33,
                    .duty_jitter = 0.02,
                });
                self.spawnPreset(.{
                    .waveform = .noise,
                    .freq_hz = 1.0,
                    .gain = 0.05,
                    .duration_s = 0.03,
                    .attack_s = 0.0005,
                    .release_s = 0.02,
                    .pitch_jitter = 0.0,
                    .time_jitter = 0.02,
                    .drift_depth = 0.0015,
                });
            },
            .bomb => {
                self.spawnPreset(.{
                    .waveform = .noise,
                    .freq_hz = 1.0,
                    .gain = 0.22,
                    .duration_s = 0.09,
                    .attack_s = 0.0005,
                    .release_s = 0.07,
                    .pitch_jitter = 0.0,
                    .time_jitter = 0.02,
                    .drift_depth = 0.002,
                });
                self.spawnPreset(.{
                    .waveform = .sine,
                    .freq_hz = 82.0,
                    .gain = 0.15,
                    .duration_s = 0.13,
                    .attack_s = 0.001,
                    .release_s = 0.10,
                    .pitch_jitter = 0.008,
                    .time_jitter = 0.03,
                    .vibrato_depth = 0.002,
                    .vibrato_hz = 4.0,
                    .tremolo_depth = 0.01,
                    .tremolo_hz = 3.5,
                    .drift_depth = 0.0025,
                });
            },
            .win => {
                self.spawnPreset(.{
                    .waveform = .pulse,
                    .freq_hz = 430.0,
                    .gain = 0.14,
                    .duration_s = 0.15,
                    .attack_s = 0.002,
                    .release_s = 0.11,
                    .pitch_jitter = 0.010,
                    .time_jitter = 0.03,
                    .vibrato_depth = 0.003,
                    .vibrato_hz = 4.8,
                    .tremolo_depth = 0.012,
                    .tremolo_hz = 4.0,
                    .drift_depth = 0.003,
                    .duty = 0.34,
                    .duty_jitter = 0.02,
                });
                self.spawnPreset(.{
                    .waveform = .sine,
                    .freq_hz = 650.0,
                    .gain = 0.10,
                    .duration_s = 0.17,
                    .attack_s = 0.002,
                    .release_s = 0.12,
                    .pitch_jitter = 0.010,
                    .time_jitter = 0.03,
                    .vibrato_depth = 0.003,
                    .vibrato_hz = 4.8,
                    .tremolo_depth = 0.012,
                    .tremolo_hz = 4.0,
                    .drift_depth = 0.003,
                });
            },
            .lose => self.spawnPreset(.{
                .waveform = .sine,
                .freq_hz = 130.0,
                .gain = 0.15,
                .duration_s = 0.16,
                .attack_s = 0.002,
                .release_s = 0.12,
                .pitch_jitter = 0.010,
                .time_jitter = 0.03,
                .vibrato_depth = 0.003,
                .vibrato_hz = 4.4,
                .tremolo_depth = 0.01,
                .tremolo_hz = 3.8,
                .drift_depth = 0.003,
            }),
        }
    }

    fn spawnPreset(self: *Synth, preset: VoicePreset) void {
        const pitch_mul = 1.0 + self.randSigned(preset.pitch_jitter);
        const time_mul = 1.0 + self.randSigned(preset.time_jitter);

        const duration_s = @max(0.01, preset.duration_s * time_mul);
        const attack_s = @max(0.0005, preset.attack_s * time_mul);
        const release_s = @max(0.0005, preset.release_s * time_mul);

        const total_samples = @as(u32, @intFromFloat(@as(f32, @floatFromInt(SAMPLE_RATE)) * duration_s));
        const attack_samples = @as(u32, @intFromFloat(@as(f32, @floatFromInt(SAMPLE_RATE)) * attack_s));
        const release_samples = @as(u32, @intFromFloat(@as(f32, @floatFromInt(SAMPLE_RATE)) * release_s));
        const base_phase_inc = @max(0.0001, (preset.freq_hz * pitch_mul) / @as(f32, @floatFromInt(SAMPLE_RATE)));

        const vibrato_rate = if (preset.vibrato_hz <= 0.0) 0.0 else (preset.vibrato_hz * (1.0 + self.randSigned(0.15))) / @as(f32, @floatFromInt(SAMPLE_RATE));
        const tremolo_rate = if (preset.tremolo_hz <= 0.0) 0.0 else (preset.tremolo_hz * (1.0 + self.randSigned(0.15))) / @as(f32, @floatFromInt(SAMPLE_RATE));

        const slot = self.pickVoiceSlot();
        self.voices[slot] = .{
            .active = true,
            .waveform = preset.waveform,
            .phase = self.rng.random().float(f32),
            .phase_inc = base_phase_inc,
            .duty = std.math.clamp(preset.duty + self.randSigned(preset.duty_jitter), 0.08, 0.92),
            .gain = preset.gain,
            .total_samples = @max(total_samples, 1),
            .samples_remaining = @max(total_samples, 1),
            .attack_samples = attack_samples,
            .release_samples = release_samples,
            .vibrato_phase = self.rng.random().float(f32),
            .vibrato_phase_inc = vibrato_rate,
            .vibrato_depth = @max(0.0, preset.vibrato_depth * (1.0 + self.randSigned(0.2))),
            .tremolo_phase = self.rng.random().float(f32),
            .tremolo_phase_inc = tremolo_rate,
            .tremolo_depth = std.math.clamp(preset.tremolo_depth * (1.0 + self.randSigned(0.2)), 0.0, 0.9),
            .pitch_drift = 0.0,
            .pitch_drift_depth = @max(0.0, preset.drift_depth * (1.0 + self.randSigned(0.2))),
            .noise_state = self.rng.random().int(u32) | 1,
        };
    }

    fn pickVoiceSlot(self: *Synth) usize {
        for (self.voices, 0..) |voice, idx| {
            if (!voice.active) return idx;
        }

        var quietest_idx: usize = 0;
        var quietest_level = self.voiceCurrentLevel(&self.voices[0]);
        for (self.voices[1..], 1..) |*voice, idx| {
            const level = self.voiceCurrentLevel(voice);
            if (level < quietest_level) {
                quietest_level = level;
                quietest_idx = idx;
            }
        }
        return quietest_idx;
    }

    fn voiceCurrentLevel(self: *const Synth, voice: *const Voice) f32 {
        _ = self;
        if (!voice.active) return 0.0;
        return voice.gain * envelopeFor(voice.total_samples, voice.samples_remaining, voice.attack_samples, voice.release_samples);
    }

    fn mixFrameBuffer(self: *Synth) void {
        for (&self.frame_buffer) |*dst| {
            var mixed: f32 = 0.0;

            for (&self.voices) |*voice| {
                mixed += self.nextVoiceSample(voice);
            }

            const clamped = std.math.clamp(mixed * self.master_volume, -1.0, 1.0);
            dst.* = clamped;
        }
    }

    fn nextVoiceSample(self: *Synth, voice: *Voice) f32 {
        _ = self;
        if (!voice.active) return 0.0;
        if (voice.samples_remaining == 0) {
            voice.active = false;
            return 0.0;
        }

        const env = envelopeFor(voice.total_samples, voice.samples_remaining, voice.attack_samples, voice.release_samples);
        var phase_inc = voice.phase_inc;
        var amp_mod: f32 = 1.0;

        if (voice.vibrato_depth > 0.0 and voice.vibrato_phase_inc > 0.0) {
            const vib = std.math.sin(voice.vibrato_phase * std.math.tau);
            phase_inc *= 1.0 + vib * voice.vibrato_depth;
            voice.vibrato_phase += voice.vibrato_phase_inc;
            if (voice.vibrato_phase >= 1.0) voice.vibrato_phase -= @floor(voice.vibrato_phase);
        }

        if (voice.pitch_drift_depth > 0.0) {
            voice.noise_state = xorshift32(voice.noise_state);
            const rnd = randSignedFromState(voice.noise_state);
            voice.pitch_drift = std.math.clamp(
                voice.pitch_drift * 0.988 + rnd * voice.pitch_drift_depth * 0.03,
                -voice.pitch_drift_depth,
                voice.pitch_drift_depth,
            );
            phase_inc *= 1.0 + voice.pitch_drift;
        }

        if (voice.tremolo_depth > 0.0 and voice.tremolo_phase_inc > 0.0) {
            const trem = (std.math.sin(voice.tremolo_phase * std.math.tau) + 1.0) * 0.5;
            amp_mod = (1.0 - voice.tremolo_depth * 0.5) + trem * voice.tremolo_depth;
            voice.tremolo_phase += voice.tremolo_phase_inc;
            if (voice.tremolo_phase >= 1.0) voice.tremolo_phase -= @floor(voice.tremolo_phase);
        }

        var raw: f32 = 0.0;

        switch (voice.waveform) {
            .sine => raw = std.math.sin(voice.phase * std.math.tau),
            .triangle => raw = 1.0 - 4.0 * @abs(voice.phase - 0.5),
            .pulse => raw = if (voice.phase < voice.duty) 1.0 else -1.0,
            .noise => {
                voice.noise_state = xorshift32(voice.noise_state);
                const n = @as(f32, @floatFromInt(voice.noise_state)) / @as(f32, @floatFromInt(std.math.maxInt(u32)));
                raw = n * 2.0 - 1.0;
            },
        }

        voice.phase += phase_inc;
        if (voice.phase >= 1.0) {
            voice.phase -= @floor(voice.phase);
        }

        voice.samples_remaining -= 1;
        if (voice.samples_remaining == 0) voice.active = false;

        return raw * voice.gain * env * amp_mod;
    }

    fn updateCooldowns(self: *Synth, dt: f32) void {
        for (&self.cooldowns) |*value| {
            value.* = @max(0.0, value.* - dt);
        }
    }

    fn randSigned(self: *Synth, amount: f32) f32 {
        if (amount <= 0.0) return 0.0;
        return (self.rng.random().float(f32) * 2.0 - 1.0) * amount;
    }
};

fn cooldownDuration(kind: EventKind) f32 {
    return switch (kind) {
        .swap => 0.03,
        .invalid => 0.08,
        .shuffle => 0.14,
        .fall_spawn => 0.05,
        .match => 0.04,
        .bomb => 0.10,
        .win => 0.40,
        .lose => 0.40,
    };
}

fn kindIndex(kind: EventKind) usize {
    return @intFromEnum(kind);
}

fn envelopeFor(total: u32, remaining: u32, attack: u32, release: u32) f32 {
    if (total == 0 or remaining == 0) return 0.0;

    const elapsed = total - remaining;
    var env: f32 = 1.0;

    if (attack > 0 and elapsed < attack) {
        env = @as(f32, @floatFromInt(elapsed)) / @as(f32, @floatFromInt(attack));
    }

    if (release > 0 and remaining < release) {
        const tail = @as(f32, @floatFromInt(remaining)) / @as(f32, @floatFromInt(release));
        env = @min(env, tail);
    }

    return std.math.clamp(env, 0.0, 1.0);
}

fn xorshift32(seed: u32) u32 {
    var x = if (seed == 0) @as(u32, 0x1234567) else seed;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    return x;
}

fn randSignedFromState(state: u32) f32 {
    const n = @as(f32, @floatFromInt(state)) / @as(f32, @floatFromInt(std.math.maxInt(u32)));
    return n * 2.0 - 1.0;
}
