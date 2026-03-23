const std = @import("std");
const game = @import("match3_2048");

const types = game.core.types;
const cfg = game.core.config;
const engine = game.core.engine;

fn clear(board: *types.Board) void {
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            board[r][c] = null;
        }
    }
}

test "bomb activation increments counter once even with neighboring bomb" {
    var state = types.GameState.init(cfg.defaultConfig());
    clear(&state.board);

    state.board[7][3] = types.Tile.bombWithValue(2);
    state.board[6][3] = types.Tile.bombWithValue(2);
    state.board[7][2] = types.Tile.number(2);
    state.board[7][4] = types.Tile.number(2);
    state.board[6][2] = types.Tile.number(4);
    state.board[6][4] = types.Tile.number(4);

    var prng = std.Random.DefaultPrng.init(11);
    try engine.explodeBombAt(&state, std.testing.allocator, prng.random(), .{ .row = 7, .col = 3 });

    try std.testing.expectEqual(@as(u32, 1), state.stats.bomb_activations);
    try std.testing.expect(state.score > 0);
}

test "neighbor bomb is consumed without secondary blast propagation" {
    var state = types.GameState.init(cfg.defaultConfig());
    clear(&state.board);

    // Origin bomb and neighboring bomb inside origin 3x3.
    state.board[7][3] = types.Tile.bombWithValue(2);
    state.board[6][3] = types.Tile.bombWithValue(2);

    // In origin 3x3.
    state.board[7][2] = types.Tile.number(2);
    state.board[7][4] = types.Tile.number(2);
    state.board[6][2] = types.Tile.number(4);
    state.board[6][4] = types.Tile.number(4);

    // Outside origin 3x3; must not be affected without chain reaction.
    state.board[5][2] = types.Tile.number(64);

    var prng = std.Random.DefaultPrng.init(12);
    try engine.explodeBombAt(&state, std.testing.allocator, prng.random(), .{ .row = 7, .col = 3 });

    try std.testing.expectEqual(@as(u32, 1), state.stats.bomb_activations);
    try std.testing.expectEqual(@as(u64, 16), state.score);
}
