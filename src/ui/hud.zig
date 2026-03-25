const std = @import("std");
const rl = @import("raylib");
const types = @import("../core/types.zig");
const ui_util = @import("ui_util.zig");

pub const ElapsedClock = struct {
    hours: u64,
    minutes: u64,
    seconds: u64,
};

pub fn elapsedClock(elapsed_seconds: f64) ElapsedClock {
    const safe_seconds = if (std.math.isFinite(elapsed_seconds) and elapsed_seconds > 0.0) elapsed_seconds else 0.0;
    const total_seconds: u64 = @intFromFloat(@floor(safe_seconds));
    return .{
        .hours = total_seconds / 3600,
        .minutes = (total_seconds % 3600) / 60,
        .seconds = total_seconds % 60,
    };
}

pub fn drawHUD(state: *const types.GameState, elapsed_seconds: f64) void {
    const ink = rl.Color.init(119, 110, 101, 255);

    rl.drawText("MATCH3 2048", 46, 18, 40, ink);

    var score_buf: [96]u8 = undefined;
    const score_text = std.fmt.bufPrintZ(&score_buf, "Score: {d}", .{state.score}) catch "score";
    rl.drawText(score_text, 610, 24, 26, ink);

    var shuffle_buf: [96]u8 = undefined;
    const shuffle_text = std.fmt.bufPrintZ(&shuffle_buf, "Shuffles: {d}", .{state.shuffles_left}) catch "shf";
    rl.drawText(shuffle_text, 610, 54, 22, ink);

    const clock = elapsedClock(elapsed_seconds);
    var timer_buf: [96]u8 = undefined;
    const timer_text = if (clock.hours > 0)
        std.fmt.bufPrintZ(
            &timer_buf,
            "Time: {d:0>2}:{d:0>2}:{d:0>2}",
            .{ clock.hours, clock.minutes, clock.seconds },
        ) catch "timer"
    else
        std.fmt.bufPrintZ(
            &timer_buf,
            "Time: {d:0>2}:{d:0>2}",
            .{ clock.minutes, clock.seconds },
        ) catch "timer";
    rl.drawText(timer_text, 760, 54, 22, ink);

    rl.drawText("Mouse: click+click or drag    S: shuffle", 46, 70, 20, ink);

    // Menu button (top-right corner)
    const btn = menuButtonRect();
    const mouse = rl.getMousePosition();
    const hover = mouseInMenuButton(mouse.x, mouse.y);
    const btn_color = if (hover)
        rl.Color.init(143, 122, 102, 255)
    else
        rl.Color.init(161, 136, 127, 255);
    rl.drawRectangleRec(btn, btn_color);
    rl.drawText("Menu", @as(i32, @intFromFloat(btn.x)) + 24, @as(i32, @intFromFloat(btn.y)) + 14, 24, rl.Color.init(249, 246, 242, 255));
}

pub fn hitTestMenuButton(mouse_x: f32, mouse_y: f32) bool {
    return mouseInMenuButton(mouse_x, mouse_y);
}

fn menuButtonRect() rl.Rectangle {
    return .{ .x = 472, .y = 26, .width = 108, .height = 48 };
}

fn mouseInMenuButton(x: f32, y: f32) bool {
    return ui_util.pointInRect(x, y, menuButtonRect());
}
