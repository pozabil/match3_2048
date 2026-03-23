pub const GameConfig = struct {
    rows: usize = 8,
    cols: usize = 8,
    spawn_two_weight: u8 = 60,
    spawn_four_weight: u8 = 40,
    spawn_eight_weight: u8 = 0,
    high_tier_spawn_threshold: u32 = 128,
    // 55 / 37.5 / 7.5 represented as proportional integer weights.
    high_tier_spawn_two_weight: u8 = 110,
    high_tier_spawn_four_weight: u8 = 75,
    high_tier_spawn_eight_weight: u8 = 15,
    // Startup board uses more 4s to reduce dense clusters of 2s.
    start_spawn_two_weight: u8 = 70,
    start_spawn_four_weight: u8 = 30,
    max_cascade_waves: u16 = 80,
    initial_shuffles: u8 = 1,
};

pub fn defaultConfig() GameConfig {
    return .{};
}
