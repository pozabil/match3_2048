const std = @import("std");

pub fn reducePoolToSingleValue(allocator: std.mem.Allocator, values: []const u32) !u32 {
    var pool = std.ArrayList(u32).empty;
    defer pool.deinit(allocator);

    try pool.appendSlice(allocator, values);
    if (pool.items.len == 0) return error.EmptyPool;

    while (pool.items.len > 1) {
        std.sort.pdq(u32, pool.items, {}, comptime std.sort.asc(u32));

        const smallest = pool.items[0];
        var pair_index: ?usize = null;
        var i: usize = 1;
        while (i < pool.items.len) : (i += 1) {
            if (pool.items[i] == smallest) {
                pair_index = i;
                break;
            }
        }

        if (pair_index) |idx| {
            _ = pool.orderedRemove(idx);
            _ = pool.orderedRemove(0);
            try pool.append(allocator, smallest * 2);
        } else {
            _ = pool.orderedRemove(0);
            if (pool.items.len == 0) {
                return error.InvalidPoolInvariant;
            }
        }
    }

    return pool.items[0];
}
