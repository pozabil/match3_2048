const std = @import("std");
const game = @import("match3_2048");

const types = game.core.types;
const cfg = game.core.config;
const utils = game.core.utils;
const move_scan = game.core.move_scan;
const merge_rules = game.core.merge_rules;
const bomb_pool_reduce = game.core.bomb_pool_reduce;
const player_move = game.core.player_move;
const resolve = game.core.resolve_loop;
const bomb_explosion = game.core.bomb_explosion;
const engine = game.core.engine;

fn clear(board: *types.Board) void {
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            board[r][c] = null;
        }
    }
}

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

fn fillUniqueNoMoveBoard(board: *types.Board) void {
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            const v: u32 = @as(u32, @intCast(r * types.BOARD_COLS + c + 2));
            board[r][c] = types.Tile.number(v);
        }
    }
}

test "invalid swap rolls back board state" {
    var state = types.GameState.init(cfg.defaultConfig());
    fillBaselineNoLines(&state.board);
    const before = state.board;

    var prng = std.Random.DefaultPrng.init(777);
    try std.testing.expectError(
        error.InvalidMoveNoMatch,
        player_move.applyPlayerAction(
            &state,
            std.testing.allocator,
            prng.random(),
            .{ .row = 0, .col = 4 },
            .{ .row = 0, .col = 5 },
        ),
    );

    try std.testing.expectEqualDeep(before, state.board);
    try std.testing.expectEqual(@as(u32, 0), state.stats.moves);
}

test "k > 5 connected match creates a bomb" {
    var state = types.GameState.init(cfg.defaultConfig());
    fillBaselineNoLines(&state.board);

    // Cross shape: horizontal line of 3 + vertical line of 5, connected count > 5.
    state.board[2][3] = types.Tile.number(2);
    state.board[3][2] = types.Tile.number(2);
    state.board[3][3] = types.Tile.number(2);
    state.board[3][4] = types.Tile.number(2);
    state.board[4][3] = types.Tile.number(2);
    state.board[5][3] = types.Tile.number(2);
    state.board[6][3] = types.Tile.number(2);

    var prng = std.Random.DefaultPrng.init(888);
    try resolve.resolveCascade(&state, std.testing.allocator, prng.random(), .{ .source = .auto });

    try std.testing.expect(utils.boardHasAnyBomb(&state.board));
}

test "bomb activates via player swap even without line match" {
    var state = types.GameState.init(cfg.defaultConfig());
    clear(&state.board);

    state.board[7][3] = types.Tile.bomb();
    state.board[7][4] = types.Tile.number(2);
    state.board[6][3] = types.Tile.number(2);
    state.board[6][4] = types.Tile.number(4);
    state.board[6][5] = types.Tile.number(8);
    state.board[7][5] = types.Tile.number(16);

    var prng = std.Random.DefaultPrng.init(889);
    try player_move.applyPlayerAction(
        &state,
        std.testing.allocator,
        prng.random(),
        .{ .row = 7, .col = 3 },
        .{ .row = 7, .col = 4 },
    );

    try std.testing.expectEqual(@as(u32, 1), state.stats.moves);
    try std.testing.expect(state.stats.bomb_activations >= 1);
}

test "bomb explosion computes result from 3x3 pool only" {
    var state = types.GameState.init(cfg.defaultConfig());
    clear(&state.board);

    state.board[4][4] = types.Tile.bomb();
    state.board[3][3] = types.Tile.number(2);
    state.board[3][4] = types.Tile.number(4);
    state.board[3][5] = types.Tile.number(8);
    state.board[4][3] = types.Tile.number(16);
    state.board[4][5] = types.Tile.number(32);
    state.board[5][3] = types.Tile.number(64);
    state.board[5][4] = types.Tile.number(128);
    state.board[5][5] = types.Tile.number(256);

    // Outside the 3x3 area; must not affect final value.
    state.board[0][0] = types.Tile.number(1024);
    state.board[7][7] = types.Tile.number(1024);

    const pool = [_]u32{ 2, 4, 8, 16, 32, 64, 128, 256 };
    const expected = try bomb_pool_reduce.reducePoolToSingleValue(std.testing.allocator, &pool);

    var prng = std.Random.DefaultPrng.init(890);
    try bomb_explosion.explodeBombAt(&state, std.testing.allocator, prng.random(), .{ .row = 4, .col = 4 });

    try std.testing.expectEqual(expected, @as(u32, @intCast(state.score)));
}

test "cascade loop obeys configured hard cap" {
    var custom_cfg = cfg.defaultConfig();
    custom_cfg.max_cascade_waves = 1;

    var state = types.GameState.init(custom_cfg);
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            state.board[r][c] = types.Tile.number(2);
        }
    }

    var prng = std.Random.DefaultPrng.init(891);
    try resolve.resolveCascade(&state, std.testing.allocator, prng.random(), .{ .source = .auto });

    try std.testing.expectEqual(@as(u32, 1), state.stats.cascade_waves);
}

test "auto-shuffle runs on no-move board when shuffles remain" {
    var state = types.GameState.init(cfg.defaultConfig());
    fillUniqueNoMoveBoard(&state.board);
    state.shuffles_left = 1;

    try std.testing.expect(!move_scan.hasValidMove(&state.board));

    var prng = std.Random.DefaultPrng.init(892);
    try engine.enforcePostMoveState(&state, std.testing.allocator, prng.random());

    try std.testing.expectEqual(@as(u8, 0), state.shuffles_left);
    try std.testing.expectEqual(types.GameStatus.running, state.status);
    try std.testing.expect(move_scan.hasValidMove(&state.board));
}

test "state becomes lost when no moves and no shuffles left" {
    var state = types.GameState.init(cfg.defaultConfig());
    fillUniqueNoMoveBoard(&state.board);
    state.shuffles_left = 0;

    try std.testing.expect(!move_scan.hasValidMove(&state.board));

    var prng = std.Random.DefaultPrng.init(893);
    try engine.enforcePostMoveState(&state, std.testing.allocator, prng.random());

    try std.testing.expectEqual(types.GameStatus.lost, state.status);
}

test "resolve/apply path is deterministic for same seed and same input" {
    var base = types.GameState.init(cfg.defaultConfig());
    fillBaselineNoLines(&base.board);

    // Prepare a guaranteed valid player move: 2 2 4 2 -> swap col 2/3 => 2 2 2 4.
    base.board[0][0] = types.Tile.number(2);
    base.board[0][1] = types.Tile.number(2);
    base.board[0][2] = types.Tile.number(4);
    base.board[0][3] = types.Tile.number(2);

    var a = base;
    var b = base;

    var prng_a = std.Random.DefaultPrng.init(9999);
    var prng_b = std.Random.DefaultPrng.init(9999);

    try player_move.applyPlayerAction(
        &a,
        std.testing.allocator,
        prng_a.random(),
        .{ .row = 0, .col = 2 },
        .{ .row = 0, .col = 3 },
    );

    try player_move.applyPlayerAction(
        &b,
        std.testing.allocator,
        prng_b.random(),
        .{ .row = 0, .col = 2 },
        .{ .row = 0, .col = 3 },
    );

    try std.testing.expectEqualDeep(a.board, b.board);
    try std.testing.expectEqual(a.score, b.score);
    try std.testing.expectEqual(a.max_tile, b.max_tile);
    try std.testing.expectEqual(a.shuffles_left, b.shuffles_left);
    try std.testing.expectEqual(a.status, b.status);
    try std.testing.expectEqualDeep(a.stats, b.stats);
}

test "merge formulas follow 2V/4V/8V" {
    try std.testing.expectEqual(@as(u32, 4), merge_rules.mergedValue(2, 3));
    try std.testing.expectEqual(@as(u32, 8), merge_rules.mergedValue(2, 4));
    try std.testing.expectEqual(@as(u32, 16), merge_rules.mergedValue(2, 5));
}
