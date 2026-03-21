const types = @import("types.zig");

pub fn mergedValue(base_value: u32, line_len: usize) u32 {
    if (line_len < 3) return base_value;
    var out = base_value;
    var i: usize = 0;
    while (i < line_len - 2) : (i += 1) {
        out *= 2;
    }
    return out;
}

pub fn isNormalMerge(line_len: usize) bool {
    return line_len >= 3 and line_len <= 5;
}

pub fn applyScoreForMerge(state: *types.GameState, merged_value: u32) void {
    applyScoreForMergeInWave(state, merged_value, 0);
}

pub fn cascadeWaveBonus(wave: usize) u32 {
    var bonus: u32 = 1;
    var threshold: usize = 2;
    while (threshold <= wave + 1 and bonus < 16) {
        bonus *= 2;
        threshold *= 2;
    }
    return bonus;
}

pub fn applyScoreForMergeInWave(state: *types.GameState, merged_value: u32, wave: usize) void {
    const bonus = cascadeWaveBonus(wave);
    const delta = @as(u64, merged_value) * @as(u64, bonus);
    state.score += delta;
    if (merged_value > state.max_tile) {
        state.max_tile = merged_value;
    }

    if (!state.shuffle_bonus_1024_awarded and merged_value >= 1024) {
        state.shuffle_bonus_1024_awarded = true;
        state.shuffles_left +|= 1;
    }

    if (merged_value >= 2048) {
        state.status = .won;
    }
}
