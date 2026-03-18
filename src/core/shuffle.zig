const std = @import("std");
const types = @import("types.zig");
const engine = @import("engine.zig");

pub fn shuffleBoard(state: *types.GameState, allocator: std.mem.Allocator, rng: std.Random) !void {
    try engine.shuffleBoard(state, allocator, rng);
}
