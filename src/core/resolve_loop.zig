const std = @import("std");
const types = @import("types.zig");
const engine = @import("engine.zig");

pub fn resolveCascade(
    state: *types.GameState,
    allocator: std.mem.Allocator,
    rng: std.Random,
    source: engine.ResolveSource,
) !void {
    try engine.resolveCascade(state, allocator, rng, source);
}
