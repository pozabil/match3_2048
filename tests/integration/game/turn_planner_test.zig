const std = @import("std");
const game = @import("match3_2048");

const cfg = game.core.config;
const types = game.core.types;
const player_move = game.core.player_move;
const turn_planner = game.game.turn_planner;
const animations = game.ui.animations;

fn fillBaselineNoLines(board: *types.Board) void {
    const pattern_a = [_]u32{ 2, 2, 4, 2, 4, 2, 4, 2 };
    const pattern_b = [_]u32{ 4, 4, 2, 4, 2, 4, 2, 4 };

    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            const v = if ((r % 2) == 0) pattern_a[c] else pattern_b[c];
            board[r][c] = types.Tile.number(v);
        }
    }
}

test "turn planner matches core final state for same seed" {
    var base = types.GameState.init(cfg.defaultConfig());
    fillBaselineNoLines(&base.board);

    // guaranteed valid swap: 2 2 4 2 -> swap 4 and 2
    base.board[0][0] = types.Tile.number(2);
    base.board[0][1] = types.Tile.number(2);
    base.board[0][2] = types.Tile.number(4);
    base.board[0][3] = types.Tile.number(2);

    var expected = base;
    var planned_base = base;

    var prng_a = std.Random.DefaultPrng.init(54321);
    var prng_b = std.Random.DefaultPrng.init(54321);

    try player_move.applyPlayerAction(
        &expected,
        std.testing.allocator,
        prng_a.random(),
        .{ .row = 0, .col = 2 },
        .{ .row = 0, .col = 3 },
    );

    var anim: animations.AnimationState = .{};
    anim.reset();

    const planned = try turn_planner.planPlayerTurn(
        &planned_base,
        std.testing.allocator,
        prng_b.random(),
        .{ .row = 0, .col = 2 },
        .{ .row = 0, .col = 3 },
        &anim,
    );

    try std.testing.expect(anim.phase_count >= 2);
    try std.testing.expectEqualDeep(expected.board, planned.board);
    try std.testing.expectEqual(expected.score, planned.score);
    try std.testing.expectEqual(expected.max_tile, planned.max_tile);
    try std.testing.expectEqual(expected.shuffles_left, planned.shuffles_left);
    try std.testing.expectEqual(expected.status, planned.status);
    try std.testing.expectEqualDeep(expected.stats, planned.stats);
}
