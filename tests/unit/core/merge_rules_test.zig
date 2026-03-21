const std = @import("std");
const game = @import("match3_2048");

const merge_rules = game.core.merge_rules;
const cfg = game.core.config;
const types = game.core.types;

test "merged values follow V*2^(k-2)" {
    try std.testing.expectEqual(@as(u32, 4), merge_rules.mergedValue(2, 3));
    try std.testing.expectEqual(@as(u32, 8), merge_rules.mergedValue(2, 4));
    try std.testing.expectEqual(@as(u32, 16), merge_rules.mergedValue(2, 5));
    try std.testing.expectEqual(@as(u32, 32), merge_rules.mergedValue(2, 6));
    try std.testing.expectEqual(@as(u32, 64), merge_rules.mergedValue(2, 7));
    try std.testing.expectEqual(@as(u32, 128), merge_rules.mergedValue(2, 8));
}

test "first 1024+ merge grants exactly one shuffle bonus" {
    var state = types.GameState.init(cfg.defaultConfig());
    state.shuffles_left = 0;

    merge_rules.applyScoreForMerge(&state, 512);
    try std.testing.expectEqual(@as(u8, 0), state.shuffles_left);
    try std.testing.expect(!state.shuffle_bonus_1024_awarded);

    merge_rules.applyScoreForMerge(&state, 1024);
    try std.testing.expectEqual(@as(u8, 1), state.shuffles_left);
    try std.testing.expect(state.shuffle_bonus_1024_awarded);

    merge_rules.applyScoreForMerge(&state, 1024);
    merge_rules.applyScoreForMerge(&state, 2048);
    try std.testing.expectEqual(@as(u8, 1), state.shuffles_left);
}
