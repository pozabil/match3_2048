const std = @import("std");
const rl = @import("raylib");
const types = @import("../core/types.zig");
const config = @import("../core/config.zig");
const engine = @import("../core/engine.zig");
const turn_planner = @import("turn_planner.zig");
const board_renderer = @import("../ui/board_renderer.zig");
const animations = @import("../ui/animations.zig");
const restart_confirm = @import("../ui/restart_confirm.zig");
const overlay = @import("../ui/overlay.zig");
const menu_ui = @import("../ui/menu.zig");
const how_to_play = @import("../ui/how_to_play.zig");
const hud = @import("../ui/hud.zig");
const ui_util = @import("../ui/ui_util.zig");
const audio_synth = @import("../audio/synth.zig");
const save_data = @import("../persistence/save_data.zig");
const storage = @import("../persistence/storage.zig");
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
    score_phase_cursor: usize = 0,
    confirm_open: bool = false,
    confirm_action: restart_confirm.Action = .restart,
    seen_phase_index: usize = 0,
    seen_phase_presenting: bool = false,
    last_status_seen: types.GameStatus = .running,
    touch_down_prev: bool = false,
    touch_last_pos: rl.Vector2 = .{ .x = 0.0, .y = 0.0 },
    suppress_mouse_until: f64 = 0.0,
    elapsed_seconds: f64 = 0.0,
    best_record: ?save_data.RecordJson = null,
    menu_open: bool = false,
    how_to_play_open: bool = false,
    how_to_play_return_to_menu: bool = false,
    how_to_play_page: u8 = 0,
    sound_enabled: bool = true,
    save_dirty: bool = false,
    save_countdown: u2 = 0,

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
        engine.initializeBoard(&runtime.state, runtime.prng.random());
        runtime.anim.reset();
        runtime.synth.init(seed ^ 0x9E3779B97F4A7C15, audio_options);
        // Attempt to restore persisted state. Errors are silently ignored.
        runtime.loadFromStorage();
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
        self.advanceScoreWithAnimation();
    }

    pub fn debugTryAction(self: *Runtime, from: types.Position, to: types.Position) void {
        self.tryAction(from, to);
    }

    pub fn debugHandleEndOverlayMouseClick(self: *Runtime, logical_pos: rl.Vector2) void {
        if (self.state.status == .running) return;
        self.applyEndOverlayNewGameAt(logical_pos);
    }

    pub fn debugHandleEndOverlayTouch(self: *Runtime, touch_down: bool, logical_pos: rl.Vector2, now: f64) bool {
        if (self.state.status == .running) return false;
        return self.processEndOverlayTouchInput(touch_down, logical_pos, now);
    }

    pub fn debugHandleManualShuffleRequest(self: *Runtime) void {
        self.handleManualShuffleRequest();
    }

    pub fn debugHandleNewGameRequest(self: *Runtime) void {
        self.handleNewGameRequest();
    }

    pub fn debugApplyMenuChoice(self: *Runtime, choice: menu_ui.Choice) void {
        self.applyMenuChoice(choice);
    }

    pub fn debugOpenHowToPlay(self: *Runtime) void {
        self.openHowToPlay();
    }

    pub fn debugDismissHowToPlay(self: *Runtime) void {
        self.closeHowToPlay();
    }

    pub fn debugApplyHowToPlayAction(self: *Runtime, action: how_to_play.Action) void {
        self.applyHowToPlayAction(action);
    }

    pub fn reset(self: *Runtime) void {
        self.state = types.GameState.init(config.defaultConfig());
        self.selected = null;
        self.drag_start = null;
        self.pending_state = null;
        self.score_phase_cursor = 0;
        self.confirm_open = false;
        self.menu_open = false;
        self.how_to_play_open = false;
        self.how_to_play_return_to_menu = false;
        self.how_to_play_page = 0;
        self.touch_down_prev = false;
        self.touch_last_pos = .{ .x = 0.0, .y = 0.0 };
        self.suppress_mouse_until = 0.0;
        self.elapsed_seconds = 0.0;
        engine.initializeBoard(&self.state, self.prng.random());
        self.anim.reset();
        self.syncPhaseCursor();
        self.last_status_seen = self.state.status;
        self.save_dirty = true; // Persist the new fresh board on web.
    }

    pub fn tick(self: *Runtime) void {
        const dt = rl.getFrameTime();
        if (self.state.status == .running and dt > 0.0) {
            self.elapsed_seconds += dt;
        }
        self.pumpAnimationAndAudio(dt);
        self.advanceScoreWithAnimation();

        if (self.pending_state != null and !self.anim.isPresenting()) {
            self.state = self.pending_state.?;
            self.pending_state = null;
            self.score_phase_cursor = 0;
            self.anim.triggerMove();
            self.save_dirty = true; // Board state changed — autosave on web.
        }

        // Autosave: defer write by 2 frames so the save never lands on a busy frame.
        if (self.save_dirty) {
            self.save_dirty = false;
            self.save_countdown = 2;
        }
        if (self.save_countdown > 0) {
            self.save_countdown -= 1;
            if (self.save_countdown == 0) self.saveToStorage();
        }

        if (self.confirm_open) {
            self.handleConfirmInput();
            return;
        }

        if (self.how_to_play_open) {
            self.handleHowToPlayInput();
            return;
        }

        if (rl.isKeyPressed(.h)) {
            self.openHowToPlay();
            return;
        }
        if (rl.isKeyPressed(.r)) {
            self.handleNewGameRequest();
            return;
        }

        // Menu button opens the menu; Escape toggles it.
        // HUD shuffle button mirrors hotkey S behavior.
        const touch_count = rl.getTouchPointCount();
        const touch_down = touch_count > 0;
        if (touch_down) {
            self.touch_last_pos = self.logicalTouchPosition(0);
        }
        if (!self.menu_open and !touch_down and self.touch_down_prev) {
            if (hud.hitTestMenuButton(self.touch_last_pos.x, self.touch_last_pos.y)) {
                self.touch_down_prev = false;
                self.menu_open = true;
                self.selected = null;
                self.drag_start = null;
                return;
            }
            if (hud.hitTestShuffleButton(self.touch_last_pos.x, self.touch_last_pos.y)) {
                self.touch_down_prev = false;
                self.suppress_mouse_until = rl.getTime() + 0.25;
                self.handleManualShuffleRequest();
                return;
            }
        }

        const mouse = self.logicalMousePosition();
        const menu_clicked = !self.menu_open and rl.isMouseButtonPressed(.left) and
            hud.hitTestMenuButton(mouse.x, mouse.y);
        const shuffle_clicked = !self.menu_open and rl.isMouseButtonPressed(.left) and
            hud.hitTestShuffleButton(mouse.x, mouse.y);
        if (menu_clicked or rl.isKeyPressed(.escape)) {
            self.menu_open = !self.menu_open;
            self.selected = null;
            self.drag_start = null;
            return; // Consume the input — don't let it reach gameplay.
        }
        if (shuffle_clicked) {
            self.handleManualShuffleRequest();
            return;
        }
        if (self.menu_open) {
            self.handleMenuInput();
            return;
        }

        if (!self.anim.isPresenting() and self.state.status == .running and rl.isKeyPressed(.s)) {
            self.handleManualShuffleRequest();
            return;
        }

        if (self.state.status != .running) {
            self.handleEndOverlayInput();
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
        return ui_util.logicalPointerPosition(rl.getMousePosition());
    }

    fn logicalTouchPosition(self: *const Runtime, index: i32) rl.Vector2 {
        _ = self;
        return ui_util.logicalPointerPosition(rl.getTouchPosition(index));
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

    fn handleMenuInput(self: *Runtime) void {
        // Touch input — mirrors handleConfirmInput touch pattern.
        const touch_count = rl.getTouchPointCount();
        const touch_down = touch_count > 0;
        if (touch_down) {
            self.touch_last_pos = self.logicalTouchPosition(0);
        }
        if (!touch_down and self.touch_down_prev) {
            self.touch_down_prev = false;
            self.suppress_mouse_until = rl.getTime() + 0.25;
            self.applyMenuChoice(menu_ui.hitTest(self.touch_last_pos.x, self.touch_last_pos.y));
            return;
        } else {
            self.touch_down_prev = touch_down;
        }

        if (rl.getTime() < self.suppress_mouse_until) return;

        // Mouse input.
        if (!rl.isMouseButtonPressed(.left)) return;
        const mouse = self.logicalMousePosition();
        self.applyMenuChoice(menu_ui.hitTest(mouse.x, mouse.y));
    }

    fn handleHowToPlayInput(self: *Runtime) void {
        if (rl.isKeyPressed(.escape)) {
            self.closeHowToPlay();
            return;
        }
        if (rl.isKeyPressed(.left)) {
            self.applyHowToPlayAction(.prev);
            return;
        }
        if (rl.isKeyPressed(.right)) {
            self.applyHowToPlayAction(.next);
            return;
        }

        const touch_count = rl.getTouchPointCount();
        const touch_down = touch_count > 0;
        if (touch_down) {
            self.touch_last_pos = self.logicalTouchPosition(0);
        }
        if (!touch_down and self.touch_down_prev) {
            self.touch_down_prev = false;
            self.suppress_mouse_until = rl.getTime() + 0.25;
            self.applyHowToPlayAction(how_to_play.hitTest(self.touch_last_pos.x, self.touch_last_pos.y, self.how_to_play_page));
            return;
        } else {
            self.touch_down_prev = touch_down;
        }

        if (rl.getTime() < self.suppress_mouse_until) return;

        if (rl.isMouseButtonPressed(.left)) {
            const m = self.logicalMousePosition();
            self.applyHowToPlayAction(how_to_play.hitTest(m.x, m.y, self.how_to_play_page));
        }
    }

    fn handleEndOverlayInput(self: *Runtime) void {
        const touch_count = rl.getTouchPointCount();
        const touch_down = touch_count > 0;
        const touch_pos = if (touch_down) self.logicalTouchPosition(0) else self.touch_last_pos;
        const now = rl.getTime();
        if (self.processEndOverlayTouchInput(touch_down, touch_pos, now)) return;

        if (now < self.suppress_mouse_until) return;

        if (rl.isMouseButtonPressed(.left)) {
            self.applyEndOverlayNewGameAt(self.logicalMousePosition());
        }
    }

    fn processEndOverlayTouchInput(self: *Runtime, touch_down: bool, touch_pos: rl.Vector2, now: f64) bool {
        if (touch_down) {
            self.touch_last_pos = touch_pos;
        }
        if (!touch_down and self.touch_down_prev) {
            self.applyEndOverlayNewGameAt(self.touch_last_pos);
            self.touch_down_prev = false;
            self.suppress_mouse_until = now + 0.25;
            return true;
        }

        self.touch_down_prev = touch_down;
        return false;
    }

    fn applyEndOverlayNewGameAt(self: *Runtime, logical_pos: rl.Vector2) void {
        if (overlay.hitTestNewGameButton(logical_pos.x, logical_pos.y)) self.reset();
    }

    fn applyMenuChoice(self: *Runtime, choice: ?menu_ui.Choice) void {
        switch (choice orelse return) {
            .close => {
                self.menu_open = false;
                self.how_to_play_open = false;
                self.how_to_play_return_to_menu = false;
            },
            .new_game => {
                self.handleNewGameRequest();
            },
            .toggle_sound => self.setSoundEnabled(!self.sound_enabled),
            .how_to_play => self.openHowToPlay(),
        }
    }

    fn applyHowToPlayAction(self: *Runtime, action: ?how_to_play.Action) void {
        switch (action orelse return) {
            .back => self.closeHowToPlay(),
            .prev => {
                if (self.how_to_play_page > 0) self.how_to_play_page -= 1;
            },
            .next => {
                if (self.how_to_play_page + 1 < how_to_play.PAGE_COUNT) {
                    self.how_to_play_page += 1;
                }
            },
        }
    }

    fn openHowToPlay(self: *Runtime) void {
        self.how_to_play_return_to_menu = self.menu_open;
        self.how_to_play_open = true;
        self.how_to_play_page = how_to_play.clampPage(self.how_to_play_page);
        self.selected = null;
        self.drag_start = null;
    }

    fn closeHowToPlay(self: *Runtime) void {
        if (!self.how_to_play_open) return;
        self.how_to_play_open = false;
        self.menu_open = self.how_to_play_return_to_menu;
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

    fn handleManualShuffleRequest(self: *Runtime) void {
        if (self.state.status != .running or self.anim.isPresenting()) return;

        if (self.state.shuffles_left > 0) {
            self.confirm_action = .shuffle;
            self.confirm_open = true;
            self.selected = null;
            self.drag_start = null;
            return;
        }

        self.anim.triggerInvalid();
        self.synth.trigger(.{ .kind = .invalid });
    }

    fn handleNewGameRequest(self: *Runtime) void {
        self.menu_open = false;
        self.how_to_play_open = false;
        self.how_to_play_return_to_menu = false;
        self.confirm_action = .restart;
        self.confirm_open = true;
        self.selected = null;
        self.drag_start = null;
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
        self.commitPendingState(planned);
        self.save_dirty = true; // Shuffles_left changed — autosave on web.
    }

    fn setSoundEnabled(self: *Runtime, enabled: bool) void {
        if (self.sound_enabled == enabled) return;
        self.sound_enabled = enabled;
        self.synth.setMuted(!enabled);
        self.save_dirty = true;
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

        self.commitPendingState(planned);
    }

    fn commitPendingState(self: *Runtime, planned: types.GameState) void {
        self.score_phase_cursor = 0;
        self.pending_state = planned;
        if (!self.anim.isPresenting()) {
            self.state = planned;
            self.pending_state = null;
            self.score_phase_cursor = 0;
            self.anim.triggerMove();
        }
    }

    fn advanceScoreWithAnimation(self: *Runtime) void {
        if (self.pending_state == null) return;
        if (self.anim.phase_count == 0) return;

        const revealed_phase_index: usize = if (self.anim.isPresenting())
            self.anim.phase_index
        else
            self.anim.phase_count - 1;

        while (self.score_phase_cursor <= revealed_phase_index and self.score_phase_cursor < self.anim.phase_count) {
            const delta = self.anim.phases[self.score_phase_cursor].score_delta;
            if (delta > 0) self.state.score += delta;
            self.score_phase_cursor += 1;
        }
    }

    fn syncAudioSignals(self: *Runtime) void {
        self.emitPhaseBoundaryAudio();
        self.onGameEnded(); // must run before emitStatusAudio advances last_status_seen
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

    fn onGameEnded(self: *Runtime) void {
        if (self.state.status == self.last_status_seen) return;
        if (self.state.status != .won and self.state.status != .lost) return;
        const new_record = save_data.gameStateToRecord(&self.state, self.elapsed_seconds);
        if (save_data.isBetterRecord(new_record, self.best_record)) {
            self.best_record = new_record;
        }
        self.save_dirty = true;
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

    /// Serialize current game state + best record and persist to storage.
    /// Errors are silently ignored (best-effort).
    pub fn saveToStorage(self: *Runtime) void {
        var save_buf: [storage.SAVE_BUF_SIZE]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&save_buf);
        const save_file = save_data.SaveFile{
            .record = self.best_record,
            .autosave = save_data.serializeToAutosave(
                &self.state,
                self.elapsed_seconds,
                self.prng.s,
            ),
            .settings = .{
                .sound_enabled = self.sound_enabled,
            },
        };
        const json = save_data.writeToJson(fba.allocator(), save_file) catch return;
        storage.save(self.allocator, json) catch {};
    }

    /// Load persisted state from storage. Silently ignores all errors.
    fn loadFromStorage(self: *Runtime) void {
        const raw = storage.load(self.allocator) catch return;
        defer self.allocator.free(raw);

        const parsed = save_data.readFromJson(self.allocator, raw) catch return;
        defer parsed.deinit();

        // RecordJson and AutosaveJson contain only value types — safe to copy.
        self.best_record = parsed.value.record;
        self.sound_enabled = if (parsed.value.settings) |settings| settings.sound_enabled else true;
        self.synth.setMuted(!self.sound_enabled);

        if (parsed.value.autosave) |auto| {
            if (!save_data.validateAutosave(auto)) return;
            var prng_s: [4]u64 = undefined;
            save_data.deserializeAutosave(auto, &self.state, &self.elapsed_seconds, &prng_s);
            self.prng.s = prng_s;
        }
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
