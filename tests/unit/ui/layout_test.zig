const std = @import("std");
const game = @import("match3_2048");

const board_renderer = game.ui.board_renderer;

test "board geometry fits 900x720 window" {
    try std.testing.expect(board_renderer.board_y + board_renderer.board_px <= 720);
}
