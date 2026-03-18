const std = @import("std");
const types = @import("types.zig");
const player_move = @import("player_move.zig");

pub fn activateBySwap(
    state: *types.GameState,
    allocator: std.mem.Allocator,
    rng: std.Random,
    from: types.Position,
    to: types.Position,
) !void {
    try player_move.applyPlayerAction(state, allocator, rng, from, to);
}
