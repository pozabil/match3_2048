const std = @import("std");
const game = @import("match3_2048");

const types = game.core.types;
const move_scan = game.core.move_scan;

fn clear(board: *types.Board) void {
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            board[r][c] = null;
        }
    }
}

test "has valid move on simple swap" {
    var board: types.Board = undefined;
    clear(&board);

    // row 0: 2 2 4 2
    board[0][0] = types.Tile.number(2);
    board[0][1] = types.Tile.number(2);
    board[0][2] = types.Tile.number(4);
    board[0][3] = types.Tile.number(2);

    try std.testing.expect(move_scan.hasValidMove(&board));
}

test "bomb adjacency is always valid move" {
    var board: types.Board = undefined;
    clear(&board);
    board[3][3] = types.Tile.bomb();
    board[3][4] = types.Tile.number(2);

    try std.testing.expect(move_scan.hasValidMove(&board));
}
