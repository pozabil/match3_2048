const types = @import("types.zig");

pub const LineMatch = struct {
    value: u32,
    positions: [types.BOARD_ROWS]types.Position,
    len: usize,
};

pub const MAX_LINE_MATCHES: usize = 32;

pub const LineMatchResult = struct {
    items: [MAX_LINE_MATCHES]LineMatch,
    len: usize,
};

fn readNumber(cell: ?types.Tile) ?u32 {
    if (cell) |t| {
        if (t.kind == .number) return t.value;
    }
    return null;
}

pub fn hasAnyLineMatch(board: *const types.Board) bool {
    // Horizontal
    for (0..types.BOARD_ROWS) |r| {
        var c: usize = 0;
        while (c < types.BOARD_COLS) {
            const v = readNumber(board[r][c]) orelse {
                c += 1;
                continue;
            };
            var end = c + 1;
            while (end < types.BOARD_COLS and readNumber(board[r][end]) == v) : (end += 1) {}
            if (end - c >= 3) return true;
            c = end;
        }
    }

    // Vertical
    for (0..types.BOARD_COLS) |c| {
        var r: usize = 0;
        while (r < types.BOARD_ROWS) {
            const v = readNumber(board[r][c]) orelse {
                r += 1;
                continue;
            };
            var end = r + 1;
            while (end < types.BOARD_ROWS and readNumber(board[end][c]) == v) : (end += 1) {}
            if (end - r >= 3) return true;
            r = end;
        }
    }

    return false;
}

pub fn findLineMatches(board: *const types.Board) LineMatchResult {
    var result = LineMatchResult{ .items = undefined, .len = 0 };

    // Horizontal
    for (0..types.BOARD_ROWS) |r| {
        var c: usize = 0;
        while (c < types.BOARD_COLS) {
            const v = readNumber(board[r][c]) orelse {
                c += 1;
                continue;
            };

            var end = c + 1;
            while (end < types.BOARD_COLS and readNumber(board[r][end]) == v) : (end += 1) {}

            if (end - c >= 3) {
                var m = LineMatch{ .value = v, .positions = undefined, .len = end - c };
                for (c..end, 0..) |cc, i| {
                    m.positions[i] = .{ .row = r, .col = cc };
                }
                result.items[result.len] = m;
                result.len += 1;
            }
            c = end;
        }
    }

    // Vertical
    for (0..types.BOARD_COLS) |c| {
        var r: usize = 0;
        while (r < types.BOARD_ROWS) {
            const v = readNumber(board[r][c]) orelse {
                r += 1;
                continue;
            };

            var end = r + 1;
            while (end < types.BOARD_ROWS and readNumber(board[end][c]) == v) : (end += 1) {}

            if (end - r >= 3) {
                var m = LineMatch{ .value = v, .positions = undefined, .len = end - r };
                for (r..end, 0..) |rr, i| {
                    m.positions[i] = .{ .row = rr, .col = c };
                }
                result.items[result.len] = m;
                result.len += 1;
            }
            r = end;
        }
    }

    return result;
}
