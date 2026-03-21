const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");
const types = @import("../core/types.zig");
const config = @import("../core/config.zig");
const board_init = @import("../core/board_init.zig");
const turn_planner = @import("turn_planner.zig");
const board_renderer = @import("../ui/board_renderer.zig");
const animations = @import("../ui/animations.zig");
const restart_confirm = @import("../ui/restart_confirm.zig");
const audio_synth = @import("../audio/synth.zig");
const MAX_PHASE_AUDIO_STEP: f32 = 0.05;
const IS_WEB = builtin.target.os.tag == .emscripten;

pub const Runtime = struct {
    allocator: std.mem.Allocator,
    prng: std.Random.DefaultPrng,
    state: types.GameState,
    selected: ?types.Position = null,
    drag_start: ?types.Position = null,
    anim: animations.AnimationState = .{},
    synth: audio_synth.Synth = .{},
    pending_state: ?types.GameState = null,
    confirm_open: bool = false,
    confirm_action: restart_confirm.Action = .restart,
    seen_phase_index: usize = 0,
    seen_phase_presenting: bool = false,
    last_status_seen: types.GameStatus = .running,
    touch_down_prev: bool = false,
    touch_last_pos: rl.Vector2 = .{ .x = 0.0, .y = 0.0 },
    suppress_mouse_until: f64 = 0.0,
    elapsed_seconds: f64 = 0.0,

    pub fn init(allocator: std.mem.Allocator, seed: u64) Runtime {
        return initWithAudioOptions(allocator, seed, .{});
    }

    pub fn initWithAudioOptions(
        allocator: std.mem.Allocator,
        seed: u64,
        audio_options: audio_synth.InitOptions,
    ) Runtime {
        var runtime = Runtime{
            .allocator = allocator,
            .prng = std.Random.DefaultPrng.init(seed),
            .state = types.GameState.init(config.defaultConfig()),
        };
        board_init.initializeBoard(&runtime.state, runtime.prng.random());
        runtime.anim.reset();
        runtime.synth.init(seed ^ 0x9E3779B97F4A7C15, audio_options);
        runtime.syncPhaseCursor();
        runtime.last_status_seen = runtime.state.status;
        return runtime;
    }

    pub fn deinit(self: *Runtime) void {
        self.synth.deinit();
    }

    pub fn isAudioEnabled(self: *const Runtime) bool {
        return self.synth.isEnabled();
    }

    pub fn audioTriggerCount(self: *const Runtime, kind: audio_synth.EventKind) u32 {
        return self.synth.triggerCount(kind);
    }

    pub fn debugPumpAudioAndAnimation(self: *Runtime, dt: f32) void {
        self.pumpAnimationAndAudio(dt);
    }

    pub fn reset(self: *Runtime) void {
        self.state = types.GameState.init(config.defaultConfig());
        self.selected = null;
        self.drag_start = null;
        self.pending_state = null;
        self.confirm_open = false;
        self.touch_down_prev = false;
        self.touch_last_pos = .{ .x = 0.0, .y = 0.0 };
        self.suppress_mouse_until = 0.0;
        self.elapsed_seconds = 0.0;
        board_init.initializeBoard(&self.state, self.prng.random());
        self.anim.reset();
        self.syncPhaseCursor();
        self.last_status_seen = self.state.status;
    }

    pub fn tick(self: *Runtime) void {
        const dt = rl.getFrameTime();
        if (self.state.status == .running and dt > 0.0) {
            self.elapsed_seconds += dt;
        }
        self.pumpAnimationAndAudio(dt);

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
                self.synth.trigger(.{ .kind = .invalid });
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

        if (self.handleTouchGameplayInput()) {
            return;
        }

        if (rl.getTime() < self.suppress_mouse_until) return;

        if (rl.isMouseButtonPressed(.left)) {
            self.drag_start = self.boardCellFromMouse();
        }

        if (rl.isMouseButtonReleased(.left)) {
            self.handlePointerRelease(self.boardCellFromMouse());
            self.drag_start = null;
        }
    }

    fn boardCellFromMouse(self: *const Runtime) ?types.Position {
        const m = self.logicalMousePosition();
        return self.boardCellFromPoint(m);
    }

    fn boardCellFromPoint(self: *const Runtime, point: rl.Vector2) ?types.Position {
        _ = self;
        return board_renderer.mouseToCell(
            @as(i32, @intFromFloat(point.x)),
            @as(i32, @intFromFloat(point.y)),
        );
    }

    fn logicalMousePosition(self: *const Runtime) rl.Vector2 {
        _ = self;
        const m = rl.getMousePosition();
        if (!IS_WEB) return m;
        const screen_w = @as(f32, @floatFromInt(@max(rl.getScreenWidth(), 1)));
        const screen_h = @as(f32, @floatFromInt(@max(rl.getScreenHeight(), 1)));
        const render_w = @as(f32, @floatFromInt(@max(rl.getRenderWidth(), 1)));
        const render_h = @as(f32, @floatFromInt(@max(rl.getRenderHeight(), 1)));

        return .{
            .x = m.x * (screen_w / render_w),
            .y = m.y * (screen_h / render_h),
        };
    }

    fn logicalTouchPosition(self: *const Runtime, index: i32) rl.Vector2 {
        _ = self;
        const t = rl.getTouchPosition(index);
        if (!IS_WEB) return t;
        const screen_w = @as(f32, @floatFromInt(@max(rl.getScreenWidth(), 1)));
        const screen_h = @as(f32, @floatFromInt(@max(rl.getScreenHeight(), 1)));
        const render_w = @as(f32, @floatFromInt(@max(rl.getRenderWidth(), 1)));
        const render_h = @as(f32, @floatFromInt(@max(rl.getRenderHeight(), 1)));

        return .{
            .x = t.x * (screen_w / render_w),
            .y = t.y * (screen_h / render_h),
        };
    }

    fn adjacentBySwipeDirection(start: types.Position, finish: types.Position) ?types.Position {
        const dr = @as(i32, @intCast(finish.row)) - @as(i32, @intCast(start.row));
        const dc = @as(i32, @intCast(finish.col)) - @as(i32, @intCast(start.col));
        if (dr == 0 and dc == 0) return null;

        var out = start;
        const abs_dr = if (dr < 0) -dr else dr;
        const abs_dc = if (dc < 0) -dc else dc;

        if (abs_dc >= abs_dr) {
            if (dc > 0) {
                if (start.col + 1 >= types.BOARD_COLS) return null;
                out.col = start.col + 1;
            } else {
                if (start.col == 0) return null;
                out.col = start.col - 1;
            }
        } else {
            if (dr > 0) {
                if (start.row + 1 >= types.BOARD_ROWS) return null;
                out.row = start.row + 1;
            } else {
                if (start.row == 0) return null;
                out.row = start.row - 1;
            }
        }

        return out;
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

        const touch_count = rl.getTouchPointCount();
        const touch_down = touch_count > 0;
        if (touch_down) {
            self.touch_last_pos = self.logicalTouchPosition(0);
        }
        if (!touch_down and self.touch_down_prev) {
            if (restart_confirm.hitTest(self.touch_last_pos.x, self.touch_last_pos.y)) |choice| {
                switch (choice) {
                    .yes => self.applyConfirmedAction(),
                    .no => self.confirm_open = false,
                }
                self.touch_down_prev = false;
                self.suppress_mouse_until = rl.getTime() + 0.25;
                return;
            }
            self.touch_down_prev = false;
            self.suppress_mouse_until = rl.getTime() + 0.25;
        } else {
            self.touch_down_prev = touch_down;
        }

        if (rl.getTime() < self.suppress_mouse_until) return;

        if (rl.isMouseButtonPressed(.left)) {
            const m = self.logicalMousePosition();
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
        const planned = turn_planner.planManualShuffle(
            &self.state,
            self.allocator,
            self.prng.random(),
            &self.anim,
        ) catch |err| {
            switch (err) {
                error.NoShufflesLeft => {
                    self.anim.triggerInvalid();
                    self.synth.trigger(.{ .kind = .invalid });
                },
                else => {
                    self.anim.triggerInvalid();
                    self.synth.trigger(.{ .kind = .invalid });
                },
            }
            return;
        };

        self.selected = null;
        self.drag_start = null;
        self.pending_state = planned;
        if (!self.anim.isPresenting()) {
            self.state = planned;
            self.pending_state = null;
            self.anim.triggerMove();
        }
    }

    fn tryAction(self: *Runtime, from: types.Position, to: types.Position) void {
        const planned = turn_planner.planPlayerTurn(&self.state, self.allocator, self.prng.random(), from, to, &self.anim) catch |err| {
            switch (err) {
                error.InvalidMoveNoMatch => {
                    self.anim.triggerInvalid();
                    self.synth.trigger(.{ .kind = .invalid });
                },
                error.NotAdjacent => {},
                else => {
                    self.anim.triggerInvalid();
                    self.synth.trigger(.{ .kind = .invalid });
                },
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

    fn syncAudioSignals(self: *Runtime) void {
        self.emitPhaseBoundaryAudio();
        self.emitStatusAudio();
    }

    fn pumpAnimationAndAudio(self: *Runtime, dt: f32) void {
        var remaining = if (dt > 0.0) dt else 0.0;
        if (remaining == 0.0) {
            self.anim.tick(0.0);
            self.syncAudioSignals();
            self.synth.tick(0.0);
            return;
        }

        while (remaining > 0.0) {
            const step = @min(remaining, MAX_PHASE_AUDIO_STEP);
            self.anim.tick(step);
            self.syncAudioSignals();
            self.synth.tick(step);
            remaining -= step;
        }
    }

    fn emitPhaseBoundaryAudio(self: *Runtime) void {
        const now_presenting = self.anim.isPresenting();
        const now_index = self.anim.phase_index;

        var should_emit = false;
        if (now_presenting) {
            if (!self.seen_phase_presenting) {
                should_emit = true;
            } else if (now_index != self.seen_phase_index) {
                should_emit = true;
            }
        }

        if (should_emit) {
            const phase = self.anim.currentPhase().?;
            if (phase.audio_event) |event| {
                self.playPhaseAudioEvent(event);
            }
        }

        self.seen_phase_presenting = now_presenting;
        self.seen_phase_index = now_index;
    }

    fn emitStatusAudio(self: *Runtime) void {
        if (self.state.status == self.last_status_seen) return;

        switch (self.state.status) {
            .won => self.synth.trigger(.{ .kind = .win }),
            .lost => self.synth.trigger(.{ .kind = .lose }),
            .running => {},
        }

        self.last_status_seen = self.state.status;
    }

    fn playPhaseAudioEvent(self: *Runtime, event: animations.AudioEvent) void {
        switch (event.kind) {
            .swap => self.synth.trigger(.{ .kind = .swap }),
            .match => self.synth.trigger(.{
                .kind = .match,
                .k_wave = event.k_wave,
                .cascade_wave = event.cascade_wave,
                .phase_intensity = event.phase_intensity,
            }),
            .fall_spawn => self.synth.trigger(.{
                .kind = .fall_spawn,
                .phase_intensity = event.phase_intensity,
            }),
            .bomb => self.synth.trigger(.{
                .kind = .bomb,
                .phase_intensity = event.phase_intensity,
            }),
            .shuffle => self.synth.trigger(.{ .kind = .shuffle }),
        }
    }

    fn syncPhaseCursor(self: *Runtime) void {
        self.seen_phase_presenting = self.anim.isPresenting();
        self.seen_phase_index = self.anim.phase_index;
    }

    fn handleTouchGameplayInput(self: *Runtime) bool {
        const touch_count = rl.getTouchPointCount();
        const touch_down = touch_count > 0;
        if (touch_down) {
            self.touch_last_pos = self.logicalTouchPosition(0);
        }

        if (touch_down and !self.touch_down_prev) {
            self.drag_start = self.boardCellFromPoint(self.touch_last_pos);
            self.touch_down_prev = true;
            self.suppress_mouse_until = rl.getTime() + 0.25;
            return true;
        }

        if (!touch_down and self.touch_down_prev) {
            self.handlePointerRelease(self.boardCellFromPoint(self.touch_last_pos));
            self.drag_start = null;
            self.touch_down_prev = false;
            self.suppress_mouse_until = rl.getTime() + 0.25;
            return true;
        }

        self.touch_down_prev = touch_down;
        return touch_down;
    }

    fn handlePointerRelease(self: *Runtime, end: ?types.Position) void {
        if (self.drag_start) |start| {
            if (end) |finish| {
                if (!(start.row == finish.row and start.col == finish.col)) {
                    // Drag gesture: choose one adjacent target by swipe direction.
                    if (adjacentBySwipeDirection(start, finish)) |target| {
                        self.tryAction(start, target);
                    }
                    self.selected = null;
                } else {
                    // Click/tap gesture: select/toggle, or perform click+click swap.
                    if (self.selected) |s| {
                        if (s.row == start.row and s.col == start.col) {
                            self.selected = null;
                        } else {
                            self.tryAction(s, start);
                            self.selected = null;
                        }
                    } else {
                        self.selected = start;
                    }
                }
            }
        }
    }
};
