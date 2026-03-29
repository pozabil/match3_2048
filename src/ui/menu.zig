const std = @import("std");
const rl = @import("raylib");
const hud = @import("hud.zig");
const save_data = @import("../persistence/save_data.zig");
const ui_util = @import("ui_util.zig");

pub const Choice = enum { new_game, toggle_sound, how_to_play, close };

pub fn draw(open: bool, record: ?save_data.RecordJson, sound_enabled: bool) void {
    if (!open) return;

    const panel = panelRect();
    const new_game_btn = newGameButtonRect(panel);
    const sound_btn = soundButtonRect(panel);
    const how_to_play_btn = howToPlayButtonRect(panel);
    const close_btn = closeButtonRect(panel);
    const mouse = ui_util.logicalPointerPosition(rl.getMousePosition());

    const ink = rl.Color.init(119, 110, 101, 255);
    const dim = rl.Color.init(0, 0, 0, 140);
    const panel_bg = rl.Color.init(238, 228, 218, 255);
    const panel_border = rl.Color.init(187, 173, 160, 255);

    rl.drawRectangle(0, 0, rl.getScreenWidth(), rl.getScreenHeight(), dim);
    rl.drawRectangleRec(panel, panel_bg);
    rl.drawRectangleLinesEx(panel, 2.0, panel_border);

    // Title
    rl.drawText("MENU", @as(i32, @intFromFloat(panel.x)) + 28, @as(i32, @intFromFloat(panel.y)) + 20, 36, ink);

    // Close [X] button
    const close_hover = pointInRect(mouse.x, mouse.y, close_btn);
    const close_color = if (close_hover)
        rl.Color.init(220, 120, 100, 255)
    else
        rl.Color.init(187, 173, 160, 255);
    rl.drawRectangleRec(close_btn, close_color);
    rl.drawText("[X]", @as(i32, @intFromFloat(close_btn.x)) + 28, @as(i32, @intFromFloat(close_btn.y)) + 14, 20, rl.Color.init(249, 246, 242, 255));

    // Divider
    rl.drawLineEx(
        .{ .x = panel.x + 16, .y = panel.y + 72 },
        .{ .x = panel.x + panel.width - 16, .y = panel.y + 72 },
        1.5,
        panel_border,
    );

    // New Game button
    const ng_hover = pointInRect(mouse.x, mouse.y, new_game_btn);
    const ng_color = if (ng_hover)
        rl.Color.init(143, 122, 102, 255)
    else
        rl.Color.init(161, 136, 127, 255);
    rl.drawRectangleRec(new_game_btn, ng_color);
    drawButtonTextCentered(new_game_btn, "New Game", 28, rl.Color.init(249, 246, 242, 255));

    // Sound toggle button
    const snd_hover = pointInRect(mouse.x, mouse.y, sound_btn);
    const snd_color = if (snd_hover)
        rl.Color.init(143, 122, 102, 255)
    else
        rl.Color.init(161, 136, 127, 255);
    rl.drawRectangleRec(sound_btn, snd_color);
    const sound_label: [:0]const u8 = if (sound_enabled) "Sounds: ON" else "Sounds: OFF";
    drawButtonTextCentered(sound_btn, sound_label, 28, rl.Color.init(249, 246, 242, 255));

    // How to Play button
    const htp_hover = pointInRect(mouse.x, mouse.y, how_to_play_btn);
    const htp_color = if (htp_hover)
        rl.Color.init(143, 122, 102, 255)
    else
        rl.Color.init(161, 136, 127, 255);
    rl.drawRectangleRec(how_to_play_btn, htp_color);
    drawButtonTextCentered(how_to_play_btn, "How to Play", 28, rl.Color.init(249, 246, 242, 255));

    // Records section
    const ry = @as(i32, @intFromFloat(panel.y)) + 228;
    rl.drawText("Best Record", @as(i32, @intFromFloat(panel.x)) + 28, ry, 26, ink);
    rl.drawLineEx(
        .{ .x = panel.x + 16, .y = panel.y + 264 },
        .{ .x = panel.x + panel.width - 16, .y = panel.y + 264 },
        1.0,
        panel_border,
    );

    if (record) |rec| {
        var buf: [128]u8 = undefined;
        const px = @as(i32, @intFromFloat(panel.x)) + 28;
        var y = ry + 46;
        const dy: i32 = 32;

        const score = std.fmt.bufPrintZ(&buf, "Score: {d}", .{rec.score}) catch "score";
        rl.drawText(score, px, y, 24, ink);
        y += dy;

        const status_str: [:0]const u8 = switch (rec.status) {
            .won => "Won",
            .lost => "Lost",
            .running => "In Progress",
        };
        rl.drawText(status_str, px + 320, y, 24, ink);

        const max = std.fmt.bufPrintZ(&buf, "Max tile: {d}", .{rec.max_tile}) catch "max";
        rl.drawText(max, px, y, 24, ink);
        y += dy;

        const moves = std.fmt.bufPrintZ(&buf, "Moves: {d}", .{rec.moves}) catch "moves";
        rl.drawText(moves, px, y, 24, ink);
        y += dy;

        const clock = hud.elapsedClock(rec.elapsed_seconds);
        const timer = if (clock.hours > 0)
            std.fmt.bufPrintZ(&buf, "Time: {d:0>2}:{d:0>2}:{d:0>2}", .{ clock.hours, clock.minutes, clock.seconds }) catch "time"
        else
            std.fmt.bufPrintZ(&buf, "Time: {d:0>2}:{d:0>2}", .{ clock.minutes, clock.seconds }) catch "time";
        rl.drawText(timer, px, y, 24, ink);
        y += dy;

        const cascades = std.fmt.bufPrintZ(&buf, "Cascades: {d}", .{rec.cascade_waves}) catch "cas";
        rl.drawText(cascades, px, y, 24, ink);
        y += dy;

        const bombs = std.fmt.bufPrintZ(&buf, "Bombs: {d}", .{rec.bomb_activations}) catch "bom";
        rl.drawText(bombs, px, y, 24, ink);
    } else {
        rl.drawText("No record yet", @as(i32, @intFromFloat(panel.x)) + 28, ry + 46, 24, ink);
    }
}

pub fn hitTest(mouse_x: f32, mouse_y: f32) ?Choice {
    const panel = panelRect();
    if (ui_util.pointInRect(mouse_x, mouse_y, closeButtonRect(panel))) return .close;
    if (ui_util.pointInRect(mouse_x, mouse_y, newGameButtonRect(panel))) return .new_game;
    if (ui_util.pointInRect(mouse_x, mouse_y, soundButtonRect(panel))) return .toggle_sound;
    if (ui_util.pointInRect(mouse_x, mouse_y, howToPlayButtonRect(panel))) return .how_to_play;
    return null;
}

fn panelRect() rl.Rectangle {
    const w: f32 = 560.0;
    const h: f32 = 580.0;
    const x = (@as(f32, @floatFromInt(rl.getScreenWidth())) - w) / 2.0;
    const y = (@as(f32, @floatFromInt(rl.getScreenHeight())) - h) / 2.0;
    return .{ .x = x, .y = y, .width = w, .height = h };
}

fn newGameButtonRect(panel: rl.Rectangle) rl.Rectangle {
    return .{
        .x = panel.x + 28,
        .y = panel.y + 90,
        .width = 216,
        .height = 104,
    };
}

fn soundButtonRect(panel: rl.Rectangle) rl.Rectangle {
    return .{
        .x = panel.x + panel.width - 28 - 216,
        .y = panel.y + 90,
        .width = 216,
        .height = 48,
    };
}

fn howToPlayButtonRect(panel: rl.Rectangle) rl.Rectangle {
    return .{
        .x = panel.x + panel.width - 28 - 216,
        .y = panel.y + 146,
        .width = 216,
        .height = 48,
    };
}

fn closeButtonRect(panel: rl.Rectangle) rl.Rectangle {
    return .{
        .x = panel.x + panel.width - 108,
        .y = panel.y + 15,
        .width = 80,
        .height = 44,
    };
}

const pointInRect = ui_util.pointInRect;

fn drawButtonTextCentered(rect: rl.Rectangle, text: [:0]const u8, font_size: i32, color: rl.Color) void {
    const text_width = rl.measureText(text, font_size);
    const tx = @as(i32, @intFromFloat(rect.x + rect.width / 2.0)) - @divTrunc(text_width, 2);
    const ty = @as(i32, @intFromFloat(rect.y + rect.height / 2.0)) - @divTrunc(font_size, 2);
    rl.drawText(text, tx, ty, font_size, color);
}
