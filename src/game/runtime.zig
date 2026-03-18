const std = @import("std");
const rl = @import("raylib");
const types = @import("../core/types.zig");
const config = @import("../core/config.zig");
const board_init = @import("../core/board_init.zig");
const player_move = @import("../core/player_move.zig");
const board_renderer = @import("../ui/board_renderer.zig");
const animations = @import("../ui/animations.zig");

pub const Runtime = struct {
    allocator: std.mem.Allocator,
    prng: std.Random.DefaultPrng,
    state: types.GameState,
    selected: ?types.Position = null,
    drag_start: ?types.Position = null,
    anim: animations.AnimationState = .{},

    pub fn init(allocator: std.mem.Allocator, seed: u64) Runtime {
        var runtime = Runtime{
            .allocator = allocator,
            .prng = std.Random.DefaultPrng.init(seed),
            .state = types.GameState.init(config.defaultConfig()),
        };
        board_init.initializeBoard(&runtime.state, runtime.prng.random());
        runtime.anim.reset();
        return runtime;
    }

    pub fn reset(self: *Runtime) void {
        self.state = types.GameState.init(config.defaultConfig());
        self.selected = null;
        self.drag_start = null;
        board_init.initializeBoard(&self.state, self.prng.random());
        self.anim.reset();
    }

    pub fn tick(self: *Runtime) void {
        const dt = rl.getFrameTime();
        self.anim.tick(dt);

        if (self.state.status != .running) {
            if (rl.isKeyPressed(.r)) self.reset();
            return;
        }

        if (rl.isMouseButtonPressed(.left)) {
            const m = rl.getMousePosition();
            self.drag_start = board_renderer.mouseToCell(@as(i32, @intFromFloat(m.x)), @as(i32, @intFromFloat(m.y)));

            if (self.drag_start) |p| {
                if (self.selected == null) {
                    self.selected = p;
                } else if (self.selected) |s| {
                    if (s.row == p.row and s.col == p.col) {
                        self.selected = null;
                    } else {
                        self.tryAction(s, p);
                        self.selected = null;
                    }
                }
            }
        }

        if (rl.isMouseButtonReleased(.left)) {
            const m = rl.getMousePosition();
            const end = board_renderer.mouseToCell(@as(i32, @intFromFloat(m.x)), @as(i32, @intFromFloat(m.y)));
            if (self.drag_start) |start| {
                if (end) |finish| {
                    if (!(start.row == finish.row and start.col == finish.col)) {
                        self.tryAction(start, finish);
                        self.selected = null;
                    }
                }
            }
            self.drag_start = null;
        }
    }

    fn tryAction(self: *Runtime, from: types.Position, to: types.Position) void {
        player_move.applyPlayerAction(&self.state, self.allocator, self.prng.random(), from, to) catch |err| {
            switch (err) {
                error.InvalidMoveNoMatch => self.anim.triggerInvalid(),
                error.NotAdjacent => {},
                else => self.anim.triggerInvalid(),
            }
            return;
        };

        self.anim.triggerMove();
    }
};
