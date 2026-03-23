const std = @import("std");
const game = @import("match3_2048");

const types = game.core.types;
const cfg = game.core.config;
const engine = game.core.engine;
const match_lines = game.core.match_lines;

test "startup board has no auto-line-matches and has at least one valid move" {
    var state = types.GameState.init(cfg.defaultConfig());
    var prng = std.Random.DefaultPrng.init(123456);
    engine.initializeBoard(&state, prng.random());

    try std.testing.expect(!match_lines.hasAnyLineMatch(&state.board));
    try std.testing.expect(engine.hasValidMove(&state.board));
}

test "startup board uses increased 4 share vs normal spawn defaults" {
    var state = types.GameState.init(cfg.defaultConfig());
    var prng = std.Random.DefaultPrng.init(987654);
    engine.initializeBoard(&state, prng.random());

    var twos: usize = 0;
    var fours: usize = 0;

    for (state.board) |row| {
        for (row) |cell| {
            if (cell) |tile| {
                if (tile.kind != .number) continue;
                if (tile.value == 2) twos += 1;
                if (tile.value == 4) fours += 1;
            }
        }
    }

    // We do not require a strict ratio per seed, but at startup 4s should be visible.
    try std.testing.expect(fours >= 8);
    try std.testing.expect(twos + fours == types.BOARD_ROWS * types.BOARD_COLS);
}
