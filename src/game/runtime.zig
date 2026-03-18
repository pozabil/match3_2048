const std = @import("std");
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
        board_init.initializeBoard(&self.state, self.prng.random());
        self.anim.reset();
        self.syncPhaseCursor();
        self.last_status_seen = self.state.status;
    }

    pub fn tick(self: *Runtime) void {
        const dt = rl.getFrameTime();
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
            self.synth.tick(0.0);
            self.anim.tick(0.0);
            self.syncAudioSignals();
            return;
        }

        while (remaining > 0.0) {
            const step = @min(remaining, MAX_PHASE_AUDIO_STEP);
            self.synth.tick(step);
            self.anim.tick(step);
            self.syncAudioSignals();
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
};
