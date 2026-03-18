const std = @import("std");
const game = @import("match3_2048");

const types = game.core.types;
const runtime_mod = game.game.runtime;
const animations = game.ui.animations;
const engine = game.core.engine;

fn emptyBoard() types.Board {
    var board: types.Board = undefined;
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            board[r][c] = null;
        }
    }
    return board;
}

test "runtime survives forced audio init failure" {
    var runtime = runtime_mod.Runtime.initWithAudioOptions(
        std.testing.allocator,
        555,
        .{ .force_init_fail = true },
    );
    defer runtime.deinit();

    try std.testing.expect(!runtime.isAudioEnabled());
    runtime.reset();
    try std.testing.expectEqual(types.GameStatus.running, runtime.state.status);
    try std.testing.expect(engine.hasValidMove(&runtime.state.board));
}

test "phase audio emits on phase boundary, not when phase is appended" {
    var runtime = runtime_mod.Runtime.initWithAudioOptions(
        std.testing.allocator,
        777,
        .{ .testing_enabled_without_device = true },
    );
    defer runtime.deinit();

    runtime.anim.clearPresentation();

    var p1 = animations.Phase.init(.swap, 0.10, runtime.state.board);
    p1.audio_event = .{ .kind = .swap };
    try runtime.anim.appendPhase(p1);

    var p2 = animations.Phase.init(.fall_spawn, 0.10, runtime.state.board);
    p2.audio_event = .{ .kind = .fall_spawn, .phase_intensity = 1.0 };
    try runtime.anim.appendPhase(p2);

    try std.testing.expectEqual(@as(u32, 0), runtime.audioTriggerCount(.swap));
    try std.testing.expectEqual(@as(u32, 0), runtime.audioTriggerCount(.fall_spawn));

    runtime.debugPumpAudioAndAnimation(0.0);
    try std.testing.expectEqual(@as(u32, 1), runtime.audioTriggerCount(.swap));
    try std.testing.expectEqual(@as(u32, 0), runtime.audioTriggerCount(.fall_spawn));

    runtime.debugPumpAudioAndAnimation(0.0);
    try std.testing.expectEqual(@as(u32, 1), runtime.audioTriggerCount(.swap));

    runtime.anim.phase_elapsed = 0.11;
    runtime.debugPumpAudioAndAnimation(0.0);
    try std.testing.expectEqual(@as(u32, 1), runtime.audioTriggerCount(.fall_spawn));
}

test "fall_spawn event is phase-level, not per tile track" {
    var runtime = runtime_mod.Runtime.initWithAudioOptions(
        std.testing.allocator,
        778,
        .{ .testing_enabled_without_device = true },
    );
    defer runtime.deinit();

    runtime.anim.clearPresentation();

    var phase = animations.Phase.init(.fall_spawn, 0.20, emptyBoard());
    phase.audio_event = .{ .kind = .fall_spawn, .phase_intensity = 1.0 };

    var i: usize = 0;
    while (i < 6) : (i += 1) {
        const row = @as(f32, @floatFromInt(i));
        try phase.addTrack(.{
            .tile = types.Tile.number(2),
            .from_row = row - 1.0,
            .from_col = 1.0,
            .to_row = row,
            .to_col = 1.0,
        });
    }

    try runtime.anim.appendPhase(phase);

    runtime.debugPumpAudioAndAnimation(0.0);
    try std.testing.expectEqual(@as(u32, 1), runtime.audioTriggerCount(.fall_spawn));
}

test "large dt still emits audio for each crossed phase boundary" {
    var runtime = runtime_mod.Runtime.initWithAudioOptions(
        std.testing.allocator,
        779,
        .{ .testing_enabled_without_device = true },
    );
    defer runtime.deinit();

    runtime.anim.clearPresentation();

    var p1 = animations.Phase.init(.swap, 0.04, emptyBoard());
    p1.audio_event = .{ .kind = .swap };
    try runtime.anim.appendPhase(p1);

    var p2 = animations.Phase.init(.fall_spawn, 0.04, emptyBoard());
    p2.audio_event = .{ .kind = .shuffle };
    try runtime.anim.appendPhase(p2);

    var p3 = animations.Phase.init(.match_flash, 0.04, emptyBoard());
    p3.audio_event = .{ .kind = .bomb };
    try runtime.anim.appendPhase(p3);

    runtime.debugPumpAudioAndAnimation(0.20);

    try std.testing.expectEqual(@as(u32, 1), runtime.audioTriggerCount(.swap));
    try std.testing.expectEqual(@as(u32, 1), runtime.audioTriggerCount(.shuffle));
    try std.testing.expectEqual(@as(u32, 1), runtime.audioTriggerCount(.bomb));
}
