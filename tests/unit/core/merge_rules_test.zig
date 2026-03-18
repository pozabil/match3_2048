const std = @import("std");
const game = @import("match3_2048");

const merge_rules = game.core.merge_rules;

test "merged values follow 2V/4V/8V" {
    try std.testing.expectEqual(@as(u32, 4), merge_rules.mergedValue(2, 3));
    try std.testing.expectEqual(@as(u32, 8), merge_rules.mergedValue(2, 4));
    try std.testing.expectEqual(@as(u32, 16), merge_rules.mergedValue(2, 5));
}
