const std = @import("std");
const types = @import("types.zig");
const engine = @import("engine.zig");

pub fn applyPlayerAction(
    state: *types.GameState,
    allocator: std.mem.Allocator,
    rng: std.Random,
    from: types.Position,
    to: types.Position,
) !void {
    try engine.applyPlayerAction(state, allocator, rng, from, to);
}
