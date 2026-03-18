const std = @import("std");
const game = @import("match3_2048");

const merge_rules = game.core.merge_rules;

test "merged values follow V*2^(k-2)" {
    try std.testing.expectEqual(@as(u32, 4), merge_rules.mergedValue(2, 3));
    try std.testing.expectEqual(@as(u32, 8), merge_rules.mergedValue(2, 4));
    try std.testing.expectEqual(@as(u32, 16), merge_rules.mergedValue(2, 5));
    try std.testing.expectEqual(@as(u32, 32), merge_rules.mergedValue(2, 6));
    try std.testing.expectEqual(@as(u32, 64), merge_rules.mergedValue(2, 7));
    try std.testing.expectEqual(@as(u32, 128), merge_rules.mergedValue(2, 8));
}
