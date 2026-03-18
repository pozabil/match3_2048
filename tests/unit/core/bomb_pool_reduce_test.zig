const std = @import("std");
const game = @import("match3_2048");

const reduce = game.core.bomb_pool_reduce.reducePoolToSingleValue;

test "pool reduction follows pairing logic" {
    const allocator = std.testing.allocator;
    const values = [_]u32{ 2, 2, 2, 4, 16, 16 };
    const result = try reduce(allocator, &values);
    try std.testing.expectEqual(@as(u32, 32), result);
}
