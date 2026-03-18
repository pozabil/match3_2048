const std = @import("std");
const game = @import("match3_2048");

const types = game.core.types;
const match_lines = game.core.match_lines;

fn clear(board: *types.Board) void {
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            board[r][c] = null;
        }
    }
}

test "line matcher detects horizontal/vertical sequences" {
    var board: types.Board = undefined;
    clear(&board);

    board[1][1] = types.Tile.number(2);
    board[1][2] = types.Tile.number(2);
    board[1][3] = types.Tile.number(2);

    try std.testing.expect(match_lines.hasAnyLineMatch(&board));
}

test "normal matches are only linear, not L-shape groups" {
    var board: types.Board = undefined;
    clear(&board);

    // L-shape with 3 identical tiles is connected but not a line of 3.
    board[2][2] = types.Tile.number(4);
    board[2][3] = types.Tile.number(4);
    board[3][2] = types.Tile.number(4);

    try std.testing.expect(!match_lines.hasAnyLineMatch(&board));

    var matches = try match_lines.findLineMatches(std.testing.allocator, &board);
    defer matches.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), matches.items.len);
}
