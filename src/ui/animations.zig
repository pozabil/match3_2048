const std = @import("std");
const types = @import("../core/types.zig");

pub const MAX_PHASES: usize = 256;
pub const MAX_TRACKS: usize = types.BOARD_ROWS * types.BOARD_COLS;

pub const PhaseKind = enum {
    swap,
    match_flash,
    fall_spawn,
};

pub const AudioEventKind = enum {
    swap,
    match,
    fall_spawn,
    bomb,
    shuffle,
};

pub const AudioEvent = struct {
    kind: AudioEventKind,
    k_wave: u8 = 3,
    cascade_wave: u8 = 0,
    phase_intensity: f32 = 1.0,
};

pub const TileTrack = struct {
    tile: types.Tile,
    from_row: f32,
    from_col: f32,
    to_row: f32,
    to_col: f32,
};

pub const Phase = struct {
    kind: PhaseKind,
    duration: f32,
    base_board: types.Board,
    audio_event: ?AudioEvent,
    score_delta: u64,
    hide_mask: [types.BOARD_ROWS][types.BOARD_COLS]bool,
    tracks: [MAX_TRACKS]TileTrack,
    track_count: usize,

    pub fn init(kind: PhaseKind, duration: f32, board: types.Board) Phase {
        var p = Phase{
            .kind = kind,
            .duration = duration,
            .base_board = board,
            .audio_event = null,
            .score_delta = 0,
            .hide_mask = undefined,
            .tracks = undefined,
            .track_count = 0,
        };
        for (0..types.BOARD_ROWS) |r| {
            for (0..types.BOARD_COLS) |c| {
                p.hide_mask[r][c] = false;
            }
        }
        return p;
    }

    pub fn addTrack(self: *Phase, track: TileTrack) !void {
        if (self.track_count >= MAX_TRACKS) return error.TooManyTracks;
        self.tracks[self.track_count] = track;
        self.track_count += 1;
    }
};

pub const AnimationState = struct {
    clock: f32 = 0.0,
    intro: f32 = 0.7,
    move_pulse: f32 = 0.0,
    invalid_pulse: f32 = 0.0,
    phases: [MAX_PHASES]Phase = undefined,
    phase_count: usize = 0,
    phase_index: usize = 0,
    phase_elapsed: f32 = 0.0,

    pub fn reset(self: *AnimationState) void {
        self.* = .{};
        self.intro = 0.7;
        self.clearPresentation();
    }

    pub fn tick(self: *AnimationState, dt: f32) void {
        self.clock += dt;
        self.intro = decay(self.intro, dt, 1.8);
        self.move_pulse = decay(self.move_pulse, dt, 3.0);
        self.invalid_pulse = decay(self.invalid_pulse, dt, 6.0);

        self.phase_elapsed += dt;
        while (self.isPresenting()) {
            const d = self.currentDuration();
            if (self.phase_elapsed < d) break;
            self.phase_elapsed -= d;
            self.phase_index += 1;
        }

        if (!self.isPresenting() and self.phase_count != 0) {
            self.clearPresentation();
        }
    }

    pub fn triggerMove(self: *AnimationState) void {
        self.move_pulse = 1.0;
    }

    pub fn triggerInvalid(self: *AnimationState) void {
        self.invalid_pulse = 1.0;
    }

    pub fn tileScale(self: *const AnimationState, row: usize, col: usize) f32 {
        const intro_boost = 0.06 * self.intro;
        if (self.move_pulse < 0.0001) return 1.0 + intro_boost;
        const phase = self.clock * 16.0 + @as(f32, @floatFromInt(row * 7 + col * 13));
        const wobble = std.math.sin(phase) * 0.02 * self.move_pulse;
        return 1.0 + wobble + intro_boost;
    }

    pub fn clearPresentation(self: *AnimationState) void {
        self.phase_count = 0;
        self.phase_index = 0;
        self.phase_elapsed = 0.0;
    }

    pub fn appendPhase(self: *AnimationState, phase: Phase) !void {
        if (self.phase_count >= MAX_PHASES) return error.TooManyPhases;
        self.phases[self.phase_count] = phase;
        self.phase_count += 1;
    }

    pub fn isPresenting(self: *const AnimationState) bool {
        return self.phase_index < self.phase_count;
    }

    pub fn currentPhase(self: *const AnimationState) ?*const Phase {
        if (!self.isPresenting()) return null;
        return &self.phases[self.phase_index];
    }

    pub fn phaseProgress(self: *const AnimationState) f32 {
        if (!self.isPresenting()) return 1.0;
        const d = self.currentDuration();
        const p = self.phase_elapsed / d;
        return std.math.clamp(p, 0.0, 1.0);
    }

    fn currentDuration(self: *const AnimationState) f32 {
        if (!self.isPresenting()) return 0.0001;
        const d = self.phases[self.phase_index].duration;
        if (d <= 0.0001) return 0.0001;
        return d;
    }
};

fn decay(v: f32, dt: f32, speed: f32) f32 {
    const next = v - dt * speed;
    if (next < 0.0) return 0.0;
    return next;
}
