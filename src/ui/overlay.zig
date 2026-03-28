const std = @import("std");
const rl = @import("raylib");
const types = @import("../core/types.zig");
const hud = @import("hud.zig");
const ui_util = @import("ui_util.zig");

pub fn drawEndOverlay(state: *const types.GameState, elapsed_seconds: f64) void {
    if (state.status == .running) return;

    const scr_w = rl.getScreenWidth();
    const scr_h = rl.getScreenHeight();
    const ink = rl.Color.init(119, 110, 101, 255);
    const panel = rl.Color.init(238, 228, 218, 235);

    rl.drawRectangle(0, 0, scr_w, scr_h, panel);

    const title = if (state.status == .won) "You Win!" else "Game Over";
    rl.drawText(title, 310, 170, 64, ink);

    var buf: [128]u8 = undefined;

    const score = std.fmt.bufPrintZ(&buf, "Final score: {d}", .{state.score}) catch "score";
    rl.drawText(score, 300, 270, 30, ink);

    const moves = std.fmt.bufPrintZ(&buf, "Moves: {d}", .{state.stats.moves}) catch "moves";
    rl.drawText(moves, 300, 312, 26, ink);

    const clock = hud.elapsedClock(elapsed_seconds);
    const timer = if (clock.hours > 0)
        std.fmt.bufPrintZ(
            &buf,
            "Time: {d:0>2}:{d:0>2}:{d:0>2}",
            .{ clock.hours, clock.minutes, clock.seconds },
        ) catch "time"
    else
        std.fmt.bufPrintZ(
            &buf,
            "Time: {d:0>2}:{d:0>2}",
            .{ clock.minutes, clock.seconds },
        ) catch "time";
    rl.drawText(timer, 300, 348, 26, ink);

    const max_tile = std.fmt.bufPrintZ(&buf, "Max tile: {d}", .{state.max_tile}) catch "max";
    rl.drawText(max_tile, 300, 384, 26, ink);

    const waves = std.fmt.bufPrintZ(&buf, "Cascade waves: {d}", .{state.stats.cascade_waves}) catch "waves";
    rl.drawText(waves, 300, 420, 26, ink);

    const bombs = std.fmt.bufPrintZ(&buf, "Bomb activations: {d}", .{state.stats.bomb_activations}) catch "bombs";
    rl.drawText(bombs, 300, 456, 26, ink);

    const btn = newGameButtonRect();
    const mouse = ui_util.logicalPointerPosition(rl.getMousePosition());
    const hovered = ui_util.pointInRect(mouse.x, mouse.y, btn);
    const btn_color = if (hovered)
        rl.Color.init(143, 122, 102, 255)
    else
        rl.Color.init(161, 136, 127, 255);
    rl.drawRectangleRec(btn, btn_color);
    rl.drawText(
        "New Game",
        @as(i32, @intFromFloat(btn.x)) + 42,
        @as(i32, @intFromFloat(btn.y)) + 14,
        30,
        rl.Color.init(249, 246, 242, 255),
    );
}

pub fn hitTestNewGameButton(mouse_x: f32, mouse_y: f32) bool {
    return hitTestNewGameButtonForScreen(mouse_x, mouse_y, rl.getScreenWidth());
}

pub fn hitTestNewGameButtonForScreen(mouse_x: f32, mouse_y: f32, screen_width: i32) bool {
    return ui_util.pointInRect(mouse_x, mouse_y, newGameButtonRectForScreen(screen_width));
}

pub fn newGameButtonRectForScreen(screen_width: i32) rl.Rectangle {
    const w: f32 = 220.0;
    const h: f32 = 58.0;
    const x = (@as(f32, @floatFromInt(screen_width)) - w) / 2.0;
    const y: f32 = 520.0;
    return .{ .x = x, .y = y, .width = w, .height = h };
}

fn newGameButtonRect() rl.Rectangle {
    return newGameButtonRectForScreen(rl.getScreenWidth());
}
