const std = @import("std");
const rl = @import("raylib");
const types = @import("../core/types.zig");
const config = @import("../core/config.zig");
const board_init = @import("../core/board_init.zig");
const turn_planner = @import("turn_planner.zig");
const engine = @import("../core/engine.zig");
const board_renderer = @import("../ui/board_renderer.zig");
const animations = @import("../ui/animations.zig");
const restart_confirm = @import("../ui/restart_confirm.zig");

pub const Runtime = struct {
    allocator: std.mem.Allocator,
    prng: std.Random.DefaultPrng,
    state: types.GameState,
    selected: ?types.Position = null,
    drag_start: ?types.Position = null,
    anim: animations.AnimationState = .{},
    pending_state: ?types.GameState = null,
    confirm_open: bool = false,
    confirm_action: restart_confirm.Action = .restart,

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
        self.pending_state = null;
        self.confirm_open = false;
        board_init.initializeBoard(&self.state, self.prng.random());
        self.anim.reset();
    }

    pub fn tick(self: *Runtime) void {
        const dt = rl.getFrameTime();
        self.anim.tick(dt);

        if (self.pending_state != null and !self.anim.isPresenting()) {
            self.state = self.pending_state.?;
            self.pending_state = null;
            self.anim.triggerMove();
        }

        if (!self.confirm_open and !self.anim.isPresenting() and rl.isKeyPressed(.r)) {
            self.confirm_action = .restart;
            self.confirm_open = true;
            self.selected = null;
            self.drag_start = null;
            return;
        }

        if (!self.confirm_open and !self.anim.isPresenting() and self.state.status == .running and rl.isKeyPressed(.s)) {
            if (self.state.shuffles_left > 0) {
                self.confirm_action = .shuffle;
                self.confirm_open = true;
                self.selected = null;
                self.drag_start = null;
            } else {
                self.anim.triggerInvalid();
            }
            return;
        }

        if (self.confirm_open) {
            self.handleConfirmInput();
            return;
        }

        if (self.state.status != .running) {
            return;
        }

        if (self.anim.isPresenting()) return;

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

    fn handleConfirmInput(self: *Runtime) void {
        if (rl.isKeyPressed(.enter)) {
            self.applyConfirmedAction();
            return;
        }

        if (rl.isKeyPressed(.escape)) {
            self.confirm_open = false;
            return;
        }

        if (rl.isMouseButtonPressed(.left)) {
            const m = rl.getMousePosition();
            if (restart_confirm.hitTest(m.x, m.y)) |choice| {
                switch (choice) {
                    .yes => self.applyConfirmedAction(),
                    .no => self.confirm_open = false,
                }
            }
        }
    }

    fn applyConfirmedAction(self: *Runtime) void {
        switch (self.confirm_action) {
            .restart => self.reset(),
            .shuffle => {
                self.confirm_open = false;
                self.applyManualShuffle();
            },
        }
    }

    fn applyManualShuffle(self: *Runtime) void {
        if (self.state.status != .running) return;
        if (self.state.shuffles_left == 0) {
            self.anim.triggerInvalid();
            return;
        }

        self.state.shuffles_left -= 1;
        engine.shuffleBoard(&self.state, self.allocator, self.prng.random()) catch {
            self.state.shuffles_left += 1;
            self.anim.triggerInvalid();
            return;
        };

        self.selected = null;
        self.drag_start = null;
        self.pending_state = null;
        self.anim.clearPresentation();
    }

    fn tryAction(self: *Runtime, from: types.Position, to: types.Position) void {
        const planned = turn_planner.planPlayerTurn(&self.state, self.allocator, self.prng.random(), from, to, &self.anim) catch |err| {
            switch (err) {
                error.InvalidMoveNoMatch => self.anim.triggerInvalid(),
                error.NotAdjacent => {},
                else => self.anim.triggerInvalid(),
            }
            return;
        };

        self.pending_state = planned;
        if (!self.anim.isPresenting()) {
            self.state = planned;
            self.pending_state = null;
            self.anim.triggerMove();
        }
    }
};
