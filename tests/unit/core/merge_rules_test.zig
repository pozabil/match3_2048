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

test "cascade wave bonus follows stepped powers of two with cap at 16" {
    try std.testing.expectEqual(@as(u32, 1), merge_rules.cascadeWaveBonus(0));
    try std.testing.expectEqual(@as(u32, 2), merge_rules.cascadeWaveBonus(1));
    try std.testing.expectEqual(@as(u32, 2), merge_rules.cascadeWaveBonus(2));
    try std.testing.expectEqual(@as(u32, 4), merge_rules.cascadeWaveBonus(3));
    try std.testing.expectEqual(@as(u32, 4), merge_rules.cascadeWaveBonus(6));
    try std.testing.expectEqual(@as(u32, 8), merge_rules.cascadeWaveBonus(7));
    try std.testing.expectEqual(@as(u32, 8), merge_rules.cascadeWaveBonus(14));
    try std.testing.expectEqual(@as(u32, 16), merge_rules.cascadeWaveBonus(15));
    try std.testing.expectEqual(@as(u32, 16), merge_rules.cascadeWaveBonus(200));
}

test "score scales with cascade wave bonus" {
    var state = types.GameState.init(cfg.defaultConfig());

    merge_rules.applyScoreForMergeInWave(&state, 64, 0);
    try std.testing.expectEqual(@as(u64, 64), state.score);

    merge_rules.applyScoreForMergeInWave(&state, 64, 2);
    try std.testing.expectEqual(@as(u64, 64 + 128), state.score);

    merge_rules.applyScoreForMergeInWave(&state, 64, 7);
    try std.testing.expectEqual(@as(u64, 64 + 128 + 512), state.score);

    merge_rules.applyScoreForMergeInWave(&state, 64, 99);
    try std.testing.expectEqual(@as(u64, 64 + 128 + 512 + 1024), state.score);
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
