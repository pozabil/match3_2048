const std = @import("std");
const game = @import("match3_2048");

const types = game.core.types;
const cfg = game.core.config;
const engine = game.core.engine;

fn fillNoMatches(board: *types.Board) void {
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            const v: u32 = if (((r + c) % 2) == 0) 2 else 4;
            board[r][c] = types.Tile.number(v);
        }
    }
}

test "status becomes won when 2048+ is created" {
    var state = types.GameState.init(cfg.defaultConfig());
    fillNoMatches(&state.board);

    state.board[2][1] = types.Tile.number(1024);
    state.board[2][2] = types.Tile.number(1024);
    state.board[2][3] = types.Tile.number(1024);

    var prng = std.Random.DefaultPrng.init(99);
    try engine.resolveCascade(&state, std.testing.allocator, prng.random(), .{ .source = .auto });

    try std.testing.expectEqual(types.GameStatus.won, state.status);
}
