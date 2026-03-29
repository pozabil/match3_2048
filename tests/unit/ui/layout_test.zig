const std = @import("std");
const game = @import("match3_2048");

const config = game.core.config;
const board_renderer = game.ui.board_renderer;

test "board geometry fits configured window height" {
    try std.testing.expect(board_renderer.board_y + board_renderer.board_px <= config.window_height);
}
