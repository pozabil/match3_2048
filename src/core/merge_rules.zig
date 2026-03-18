const types = @import("types.zig");

pub fn mergedValue(base_value: u32, line_len: usize) u32 {
    return switch (line_len) {
        3 => base_value * 2,
        4 => base_value * 4,
        5 => base_value * 8,
        else => base_value * 2,
    };
}

pub fn isNormalMerge(line_len: usize) bool {
    return line_len >= 3 and line_len <= 5;
}

pub fn applyScoreForMerge(state: *types.GameState, merged_value: u32) void {
    state.score += merged_value;
    if (merged_value > state.max_tile) {
        state.max_tile = merged_value;
    }
    if (merged_value >= 2048) {
        state.status = .won;
    }
}
