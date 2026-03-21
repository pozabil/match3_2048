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
    state.score += merged_value;
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
