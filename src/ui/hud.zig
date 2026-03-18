const std = @import("std");
const rl = @import("raylib");
const types = @import("../core/types.zig");

pub fn drawHUD(state: *const types.GameState) void {
    const ink = rl.Color.init(119, 110, 101, 255);

    rl.drawText("MATCH3 2048", 46, 18, 40, ink);

    var score_buf: [96]u8 = undefined;
    const score_text = std.fmt.bufPrintZ(&score_buf, "Score: {d}", .{state.score}) catch "score";
    rl.drawText(score_text, 610, 24, 26, ink);

    var shuffle_buf: [96]u8 = undefined;
    const shuffle_text = std.fmt.bufPrintZ(&shuffle_buf, "Shuffles: {d}", .{state.shuffles_left}) catch "shf";
    rl.drawText(shuffle_text, 610, 54, 22, ink);

    rl.drawText("Mouse: click+click or drag    R: new game", 46, 70, 20, ink);
}
