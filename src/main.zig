const std = @import("std");
const app = @import("match3_2048").game.app;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try app.run(allocator);
}
