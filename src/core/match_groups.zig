const std = @import("std");
const types = @import("types.zig");

pub const Group = struct {
    value: u32,
    positions: std.ArrayList(types.Position),

    pub fn deinit(self: *Group, allocator: std.mem.Allocator) void {
        self.positions.deinit(allocator);
    }
};

pub fn deinitGroups(allocator: std.mem.Allocator, groups: *std.ArrayList(Group)) void {
    for (groups.items) |*g| g.deinit(allocator);
    groups.deinit(allocator);
}

fn readNumber(cell: ?types.Tile) ?u32 {
    if (cell) |t| {
        if (t.kind == .number) return t.value;
    }
    return null;
}

pub fn findConnectedGroupsOver(
    allocator: std.mem.Allocator,
    board: *const types.Board,
    min_size: usize,
) !std.ArrayList(Group) {
    var out = std.ArrayList(Group).empty;
    errdefer deinitGroups(allocator, &out);

    var visited: [types.BOARD_ROWS][types.BOARD_COLS]bool = undefined;
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            visited[r][c] = false;
        }
    }

    var stack = std.ArrayList(types.Position).empty;
    defer stack.deinit(allocator);

    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            if (visited[r][c]) continue;
            const v = readNumber(board[r][c]) orelse {
                visited[r][c] = true;
                continue;
            };

            visited[r][c] = true;
            stack.clearRetainingCapacity();
            try stack.append(allocator, .{ .row = r, .col = c });

            var positions = std.ArrayList(types.Position).empty;
            errdefer positions.deinit(allocator);

            while (stack.items.len > 0) {
                const p = stack.pop().?;
                try positions.append(allocator, p);

                const neighbors = [_]types.Position{
                    .{ .row = if (p.row == 0) p.row else p.row - 1, .col = p.col },
                    .{ .row = if (p.row + 1 >= types.BOARD_ROWS) p.row else p.row + 1, .col = p.col },
                    .{ .row = p.row, .col = if (p.col == 0) p.col else p.col - 1 },
                    .{ .row = p.row, .col = if (p.col + 1 >= types.BOARD_COLS) p.col else p.col + 1 },
                };

                for (neighbors) |n| {
                    if (n.row == p.row and n.col == p.col) continue;
                    if (visited[n.row][n.col]) continue;
                    visited[n.row][n.col] = true;

                    if (readNumber(board[n.row][n.col]) == v) {
                        try stack.append(allocator, n);
                    }
                }
            }

            if (positions.items.len > min_size) {
                try out.append(allocator, .{ .value = v, .positions = positions });
            } else {
                positions.deinit(allocator);
            }
        }
    }

    return out;
}
