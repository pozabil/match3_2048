pub const GameConfig = struct {
    rows: usize = 8,
    cols: usize = 8,
    spawn_two_weight: u8 = 90,
    spawn_four_weight: u8 = 10,
    // Startup board uses more 4s to reduce dense clusters of 2s.
    start_spawn_two_weight: u8 = 70,
    start_spawn_four_weight: u8 = 30,
    max_cascade_waves: u16 = 100,
    initial_shuffles: u8 = 1,
};

pub fn defaultConfig() GameConfig {
    return .{};
}
