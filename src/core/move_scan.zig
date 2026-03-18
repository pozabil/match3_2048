const types = @import("types.zig");
const engine = @import("engine.zig");

pub fn hasValidMove(board: *const types.Board) bool {
    return engine.hasValidMove(board);
}
