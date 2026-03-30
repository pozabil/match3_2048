const std = @import("std");
const rl = @import("raylib");
const ui_util = @import("ui_util.zig");

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
    drawPanelTextCentered(panel, title, @as(i32, @intFromFloat(panel.y)) + 34, 40, rl.Color.init(119, 110, 101, 255));

    var subtitle_buf: [64]u8 = undefined;
    const subtitle = switch (action) {
        .restart => "Current run will be reset.",
        .shuffle => std.fmt.bufPrintZ(&subtitle_buf, "Spend 1 shuffle (left: {d})", .{shuffles_left}) catch "Spend 1 shuffle",
    };
    drawPanelTextCentered(panel, subtitle, @as(i32, @intFromFloat(panel.y)) + 90, 24, rl.Color.init(119, 110, 101, 255));

    const yes_hover = pointInRect(mouse.x, mouse.y, yes_btn);
    const no_hover = pointInRect(mouse.x, mouse.y, no_btn);
    const yes_color = if (yes_hover) rl.Color.init(143, 122, 102, 255) else rl.Color.init(161, 136, 127, 255);
    const no_color = if (no_hover) rl.Color.init(220, 120, 100, 255) else rl.Color.init(235, 140, 120, 255);

    rl.drawRectangleRec(yes_btn, yes_color);
    rl.drawRectangleRec(no_btn, no_color);

    const btn_text = rl.Color.init(249, 246, 242, 255);
    drawButtonTextCentered(yes_btn, "Yes", 34, btn_text);
    drawButtonTextCentered(no_btn, "No", 34, btn_text);
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

fn drawButtonTextCentered(rect: rl.Rectangle, text: [:0]const u8, font_size: i32, color: rl.Color) void {
    const text_width = rl.measureText(text, font_size);
    const tx = @as(i32, @intFromFloat(rect.x + rect.width / 2.0)) - @divTrunc(text_width, 2);
    const ty = @as(i32, @intFromFloat(rect.y + rect.height / 2.0)) - @divTrunc(font_size, 2);
    rl.drawText(text, tx, ty, font_size, color);
}

fn drawPanelTextCentered(panel: rl.Rectangle, text: [:0]const u8, y: i32, font_size: i32, color: rl.Color) void {
    const text_width = rl.measureText(text, font_size);
    const tx = @as(i32, @intFromFloat(panel.x + panel.width / 2.0)) - @divTrunc(text_width, 2);
    rl.drawText(text, tx, y, font_size, color);
}

const pointInRect = ui_util.pointInRect;
