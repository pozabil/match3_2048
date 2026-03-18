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
};

const Voice = struct {
    active: bool = false,
    waveform: Waveform = .sine,
    phase: f32 = 0.0,
    phase_inc: f32 = 0.0,
    gain: f32 = 0.0,
    total_samples: u32 = 0,
    samples_remaining: u32 = 0,
    attack_samples: u32 = 0,
    release_samples: u32 = 0,
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
        // Safe re-init: release previous stream before resetting state.
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
                    .waveform = .triangle,
                    .freq_hz = 420.0,
                    .gain = 0.22,
                    .duration_s = 0.07,
                    .attack_s = 0.004,
                    .release_s = 0.05,
                    .pitch_jitter = 0.04,
                    .time_jitter = 0.08,
                });
            },
            .invalid => {
                self.spawnPreset(.{
                    .waveform = .sine,
                    .freq_hz = 220.0,
                    .gain = 0.20,
                    .duration_s = 0.10,
                    .attack_s = 0.002,
                    .release_s = 0.07,
                    .pitch_jitter = 0.03,
                    .time_jitter = 0.08,
                });
            },
            .shuffle => {
                self.spawnPreset(.{
                    .waveform = .triangle,
                    .freq_hz = 300.0,
                    .gain = 0.20,
                    .duration_s = 0.12,
                    .attack_s = 0.005,
                    .release_s = 0.10,
                    .pitch_jitter = 0.05,
                    .time_jitter = 0.10,
                });
                self.spawnPreset(.{
                    .waveform = .sine,
                    .freq_hz = 520.0,
                    .gain = 0.12,
                    .duration_s = 0.08,
                    .attack_s = 0.003,
                    .release_s = 0.06,
                    .pitch_jitter = 0.05,
                    .time_jitter = 0.10,
                });
            },
            .fall_spawn => {
                const intensity = std.math.clamp(event.phase_intensity, 0.2, 2.0);
                self.spawnPreset(.{
                    .waveform = .sine,
                    .freq_hz = 170.0 + 40.0 * intensity,
                    .gain = 0.05 * intensity,
                    .duration_s = 0.05,
                    .attack_s = 0.002,
                    .release_s = 0.04,
                    .pitch_jitter = 0.03,
                    .time_jitter = 0.08,
                });
            },
            .match => {
                const k = @as(f32, @floatFromInt(@max(event.k_wave, 3)));
                const wave = @as(f32, @floatFromInt(event.cascade_wave));
                const bright = 1.0 + (k - 3.0) * 0.18;
                const depth_boost = 1.0 + std.math.clamp(wave, 0.0, 6.0) * 0.04;

                self.spawnPreset(.{
                    .waveform = .triangle,
                    .freq_hz = 300.0 * bright,
                    .gain = 0.16 * depth_boost,
                    .duration_s = 0.10,
                    .attack_s = 0.003,
                    .release_s = 0.08,
                    .pitch_jitter = 0.05,
                    .time_jitter = 0.08,
                });
                self.spawnPreset(.{
                    .waveform = .sine,
                    .freq_hz = 460.0 * bright,
                    .gain = 0.11 * depth_boost,
                    .duration_s = 0.08,
                    .attack_s = 0.003,
                    .release_s = 0.06,
                    .pitch_jitter = 0.05,
                    .time_jitter = 0.08,
                });
            },
            .bomb => {
                self.spawnPreset(.{
                    .waveform = .noise,
                    .freq_hz = 1.0,
                    .gain = 0.18,
                    .duration_s = 0.09,
                    .attack_s = 0.001,
                    .release_s = 0.07,
                    .pitch_jitter = 0.0,
                    .time_jitter = 0.10,
                });
                self.spawnPreset(.{
                    .waveform = .triangle,
                    .freq_hz = 120.0,
                    .gain = 0.12,
                    .duration_s = 0.12,
                    .attack_s = 0.002,
                    .release_s = 0.10,
                    .pitch_jitter = 0.04,
                    .time_jitter = 0.08,
                });
            },
            .win => {
                self.spawnPreset(.{
                    .waveform = .triangle,
                    .freq_hz = 520.0,
                    .gain = 0.20,
                    .duration_s = 0.16,
                    .attack_s = 0.003,
                    .release_s = 0.12,
                    .pitch_jitter = 0.03,
                    .time_jitter = 0.06,
                });
                self.spawnPreset(.{
                    .waveform = .sine,
                    .freq_hz = 780.0,
                    .gain = 0.16,
                    .duration_s = 0.20,
                    .attack_s = 0.004,
                    .release_s = 0.14,
                    .pitch_jitter = 0.03,
                    .time_jitter = 0.06,
                });
            },
            .lose => {
                self.spawnPreset(.{
                    .waveform = .sine,
                    .freq_hz = 180.0,
                    .gain = 0.18,
                    .duration_s = 0.16,
                    .attack_s = 0.003,
                    .release_s = 0.12,
                    .pitch_jitter = 0.03,
                    .time_jitter = 0.06,
                });
            },
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

        const slot = self.pickVoiceSlot();
        self.voices[slot] = .{
            .active = true,
            .waveform = preset.waveform,
            .phase = self.rng.random().float(f32),
            .phase_inc = @max(0.0001, (preset.freq_hz * pitch_mul) / @as(f32, @floatFromInt(SAMPLE_RATE))),
            .gain = preset.gain,
            .total_samples = @max(total_samples, 1),
            .samples_remaining = @max(total_samples, 1),
            .attack_samples = attack_samples,
            .release_samples = release_samples,
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
        var raw: f32 = 0.0;

        switch (voice.waveform) {
            .sine => {
                raw = std.math.sin(voice.phase * std.math.tau);
            },
            .triangle => {
                raw = 1.0 - 4.0 * @abs(voice.phase - 0.5);
            },
            .noise => {
                voice.noise_state = xorshift32(voice.noise_state);
                const n = @as(f32, @floatFromInt(voice.noise_state)) / @as(f32, @floatFromInt(std.math.maxInt(u32)));
                raw = n * 2.0 - 1.0;
            },
        }

        voice.phase += voice.phase_inc;
        if (voice.phase >= 1.0) {
            voice.phase -= @floor(voice.phase);
        }

        voice.samples_remaining -= 1;
        if (voice.samples_remaining == 0) voice.active = false;

        return raw * voice.gain * env;
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
