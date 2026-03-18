const std = @import("std");
const types = @import("types.zig");
const engine = @import("engine.zig");

pub fn initializeBoard(state: *types.GameState, rng: std.Random) void {
    engine.initializeBoard(state, rng);
}
