const std = @import("std");

pub const AnimationState = struct {
    clock: f32 = 0.0,
    intro: f32 = 0.7,
    move_pulse: f32 = 0.0,
    invalid_pulse: f32 = 0.0,

    pub fn reset(self: *AnimationState) void {
        self.* = .{};
        self.intro = 0.7;
    }

    pub fn tick(self: *AnimationState, dt: f32) void {
        self.clock += dt;
        self.intro = decay(self.intro, dt, 1.8);
        self.move_pulse = decay(self.move_pulse, dt, 3.0);
        self.invalid_pulse = decay(self.invalid_pulse, dt, 6.0);
    }

    pub fn triggerMove(self: *AnimationState) void {
        self.move_pulse = 1.0;
    }

    pub fn triggerInvalid(self: *AnimationState) void {
        self.invalid_pulse = 1.0;
    }

    pub fn tileScale(self: *const AnimationState, row: usize, col: usize) f32 {
        const phase = self.clock * 16.0 + @as(f32, @floatFromInt(row * 7 + col * 13));
        const wobble = std.math.sin(phase) * 0.02 * self.move_pulse;
        const intro_boost = 0.06 * self.intro;
        return 1.0 + wobble + intro_boost;
    }
};

fn decay(v: f32, dt: f32, speed: f32) f32 {
    const next = v - dt * speed;
    if (next < 0.0) return 0.0;
    return next;
}
