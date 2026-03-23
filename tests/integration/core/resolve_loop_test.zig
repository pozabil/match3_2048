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

test "resolve loop processes at least one wave" {
    var state = types.GameState.init(cfg.defaultConfig());
    fillNoMatches(&state.board);

    // force horizontal line match
    state.board[0][0] = types.Tile.number(2);
    state.board[0][1] = types.Tile.number(2);
    state.board[0][2] = types.Tile.number(2);

    var prng = std.Random.DefaultPrng.init(42);
    try engine.resolveCascade(&state, std.testing.allocator, prng.random(), .{ .source = .auto });

    try std.testing.expect(state.stats.cascade_waves >= 1);
    try std.testing.expect(state.score >= 4);
}
