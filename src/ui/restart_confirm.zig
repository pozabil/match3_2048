const std = @import("std");
const rl = @import("raylib");

pub const Choice = enum {
    yes,
    no,
};

pub const Action = enum {
    restart,
    shuffle,
};

pub fn draw(action: Action, open: bool, shuffles_left: u8) void {
    if (!open) return;

    const panel = panelRect();
    const yes_btn = yesButtonRect(panel);
    const no_btn = noButtonRect(panel);
    const mouse = rl.getMousePosition();

    rl.drawRectangle(0, 0, rl.getScreenWidth(), rl.getScreenHeight(), rl.Color.init(0, 0, 0, 140));
    rl.drawRectangleRec(panel, rl.Color.init(238, 228, 218, 255));
    rl.drawRectangleLinesEx(panel, 2.0, rl.Color.init(187, 173, 160, 255));

    const title = switch (action) {
        .restart => "Start a New Game?",
        .shuffle => "Shuffle Board?",
    };
    rl.drawText(title, @as(i32, @intFromFloat(panel.x)) + 48, @as(i32, @intFromFloat(panel.y)) + 34, 40, rl.Color.init(119, 110, 101, 255));

    var subtitle_buf: [64]u8 = undefined;
    const subtitle = switch (action) {
        .restart => "Current run will be reset.",
        .shuffle => std.fmt.bufPrintZ(&subtitle_buf, "Spend 1 shuffle (left: {d})", .{shuffles_left}) catch "Spend 1 shuffle",
    };
    rl.drawText(subtitle, @as(i32, @intFromFloat(panel.x)) + 72, @as(i32, @intFromFloat(panel.y)) + 90, 24, rl.Color.init(119, 110, 101, 255));

    const yes_hover = pointInRect(mouse.x, mouse.y, yes_btn);
    const no_hover = pointInRect(mouse.x, mouse.y, no_btn);
    const yes_color = if (yes_hover) rl.Color.init(143, 122, 102, 255) else rl.Color.init(161, 136, 127, 255);
    const no_color = if (no_hover) rl.Color.init(220, 120, 100, 255) else rl.Color.init(235, 140, 120, 255);

    rl.drawRectangleRec(yes_btn, yes_color);
    rl.drawRectangleRec(no_btn, no_color);

    rl.drawText("Yes", @as(i32, @intFromFloat(yes_btn.x)) + 52, @as(i32, @intFromFloat(yes_btn.y)) + 20, 34, rl.Color.init(249, 246, 242, 255));
    rl.drawText("No", @as(i32, @intFromFloat(no_btn.x)) + 64, @as(i32, @intFromFloat(no_btn.y)) + 20, 34, rl.Color.init(249, 246, 242, 255));
}

pub fn hitTest(mouse_x: f32, mouse_y: f32) ?Choice {
    const panel = panelRect();
    const yes_btn = yesButtonRect(panel);
    const no_btn = noButtonRect(panel);

    if (pointInRect(mouse_x, mouse_y, yes_btn)) return .yes;
    if (pointInRect(mouse_x, mouse_y, no_btn)) return .no;
    return null;
}

fn panelRect() rl.Rectangle {
    const w: f32 = 520.0;
    const h: f32 = 250.0;
    const x = (@as(f32, @floatFromInt(rl.getScreenWidth())) - w) / 2.0;
    const y = (@as(f32, @floatFromInt(rl.getScreenHeight())) - h) / 2.0;
    return .{ .x = x, .y = y, .width = w, .height = h };
}

fn yesButtonRect(panel: rl.Rectangle) rl.Rectangle {
    return .{
        .x = panel.x + 84.0,
        .y = panel.y + 134.0,
        .width = 150.0,
        .height = 72.0,
    };
}

fn noButtonRect(panel: rl.Rectangle) rl.Rectangle {
    return .{
        .x = panel.x + panel.width - 84.0 - 150.0,
        .y = panel.y + 134.0,
        .width = 150.0,
        .height = 72.0,
    };
}

fn pointInRect(x: f32, y: f32, rect: rl.Rectangle) bool {
    return x >= rect.x and x <= rect.x + rect.width and y >= rect.y and y <= rect.y + rect.height;
}
