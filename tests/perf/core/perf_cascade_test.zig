const std = @import("std");
const game = @import("match3_2048");

const types = game.core.types;
const cfg = game.core.config;
const resolve = game.core.resolve_loop;

fn fillDense(board: *types.Board) void {
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            const v: u32 = switch ((r + c) % 4) {
                0 => 2,
                1 => 4,
                2 => 8,
                else => 16,
            };
            board[r][c] = types.Tile.number(v);
        }
    }
}

test "cascade perf smoke" {
    var state = types.GameState.init(cfg.defaultConfig());
    fillDense(&state.board);

    // force one guaranteed match
    state.board[0][0] = types.Tile.number(2);
    state.board[0][1] = types.Tile.number(2);
    state.board[0][2] = types.Tile.number(2);

    var prng = std.Random.DefaultPrng.init(1234);

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        try resolve.resolveCascade(&state, std.testing.allocator, prng.random(), .{ .source = .auto });
    }

    try std.testing.expect(state.stats.cascade_waves >= 1);
}
