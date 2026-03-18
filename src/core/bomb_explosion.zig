const std = @import("std");
const types = @import("types.zig");
const engine = @import("engine.zig");

pub fn explodeBombAt(
    state: *types.GameState,
    allocator: std.mem.Allocator,
    rng: std.Random,
    origin: types.Position,
) !void {
    try engine.explodeBombAt(state, allocator, rng, origin);
}
