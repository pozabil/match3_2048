const std = @import("std");
const builtin = @import("builtin");
const app = @import("match3_2048").game.app;

pub fn main() !void {
    if (builtin.target.os.tag == .emscripten) {
        try app.run(std.heap.c_allocator);
        return;
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const status = gpa.deinit();
        std.debug.assert(status == .ok);
    }
    const allocator = gpa.allocator();

    try app.run(allocator);
}
