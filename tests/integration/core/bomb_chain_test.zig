const std = @import("std");
const game = @import("match3_2048");

const types = game.core.types;
const cfg = game.core.config;
const bomb_explosion = game.core.bomb_explosion;

fn clear(board: *types.Board) void {
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            board[r][c] = null;
        }
    }
}

test "bomb chain increments activation counter" {
    var state = types.GameState.init(cfg.defaultConfig());
    clear(&state.board);

    state.board[7][3] = types.Tile.bombWithValue(2);
    state.board[6][3] = types.Tile.bombWithValue(2);
    state.board[7][2] = types.Tile.number(2);
    state.board[7][4] = types.Tile.number(2);
    state.board[6][2] = types.Tile.number(4);
    state.board[6][4] = types.Tile.number(4);

    var prng = std.Random.DefaultPrng.init(11);
    try bomb_explosion.explodeBombAt(&state, std.testing.allocator, prng.random(), .{ .row = 7, .col = 3 });

    try std.testing.expect(state.stats.bomb_activations >= 2);
    try std.testing.expect(state.score > 0);
}
