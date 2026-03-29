const std = @import("std");
const rl = @import("raylib");
const ui_util = @import("ui_util.zig");

pub const Action = enum {
    back,
    prev,
    next,
};

pub const Page = enum(u8) {
    controls = 0,
    line_merge = 1,
    bombs = 2,
    shuffle = 3,
    scoring = 4,
};

pub const PAGE_COUNT: u8 = 5;

pub fn clampPage(page: u8) u8 {
    return if (page < PAGE_COUNT) page else PAGE_COUNT - 1;
}

pub fn draw(open: bool, page_index: u8) void {
    if (!open) return;

    const clamped_page = clampPage(page_index);
    const page = @as(Page, @enumFromInt(clamped_page));
    const panel = panelRect();
    const back_btn = backButtonRect();
    const prev_btn = prevButtonRect();
    const next_btn = nextButtonRect();
    const mouse = ui_util.logicalPointerPosition(rl.getMousePosition());

    const ink = rl.Color.init(119, 110, 101, 255);
    const dim = rl.Color.init(0, 0, 0, 170);
    const panel_bg = rl.Color.init(245, 239, 230, 255);
    const panel_border = rl.Color.init(187, 173, 160, 255);

    rl.drawRectangle(0, 0, rl.getScreenWidth(), rl.getScreenHeight(), dim);
    rl.drawRectangleRec(panel, panel_bg);
    rl.drawRectangleLinesEx(panel, 2.0, panel_border);

    rl.drawText("HOW TO PLAY", @as(i32, @intFromFloat(panel.x)) + 28, @as(i32, @intFromFloat(panel.y)) + 20, 38, ink);
    drawActionButton(back_btn, "Back", true, ui_util.pointInRect(mouse.x, mouse.y, back_btn));

    const title_x = @as(i32, @intFromFloat(panel.x)) + 354;
    rl.drawText(pageTitle(page), title_x, @as(i32, @intFromFloat(panel.y)) + 88, 32, ink);
    drawPageText(page, title_x, @as(i32, @intFromFloat(panel.y)) + 134, ink);
    drawPageIllustration(page, panel);

    const prev_enabled = clamped_page > 0;
    const next_enabled = clamped_page + 1 < PAGE_COUNT;
    drawActionButton(prev_btn, "<", prev_enabled, prev_enabled and ui_util.pointInRect(mouse.x, mouse.y, prev_btn));
    drawActionButton(next_btn, ">", next_enabled, next_enabled and ui_util.pointInRect(mouse.x, mouse.y, next_btn));

    var page_buf: [16]u8 = undefined;
    const page_text = std.fmt.bufPrintZ(&page_buf, "{d}/{d}", .{ clamped_page + 1, PAGE_COUNT }) catch "1/5";
    rl.drawText(
        page_text,
        @as(i32, @intFromFloat(panel.x + panel.width / 2.0)) - 22,
        @as(i32, @intFromFloat(panel.y + panel.height - 60.0)),
        24,
        ink,
    );
}

pub fn hitTest(mouse_x: f32, mouse_y: f32, page_index: u8) ?Action {
    return hitTestForScreen(mouse_x, mouse_y, page_index, rl.getScreenWidth(), rl.getScreenHeight());
}

pub fn hitTestForScreen(mouse_x: f32, mouse_y: f32, page_index: u8, screen_width: i32, screen_height: i32) ?Action {
    const clamped_page = clampPage(page_index);
    if (ui_util.pointInRect(mouse_x, mouse_y, backButtonRectForScreen(screen_width, screen_height))) return .back;
    if (clamped_page > 0 and ui_util.pointInRect(mouse_x, mouse_y, prevButtonRectForScreen(screen_width, screen_height))) return .prev;
    if (clamped_page + 1 < PAGE_COUNT and ui_util.pointInRect(mouse_x, mouse_y, nextButtonRectForScreen(screen_width, screen_height))) return .next;
    return null;
}

pub fn panelRectForScreen(screen_width: i32, screen_height: i32) rl.Rectangle {
    const w: f32 = 820.0;
    const h: f32 = 610.0;
    const x = (@as(f32, @floatFromInt(screen_width)) - w) / 2.0;
    const y = (@as(f32, @floatFromInt(screen_height)) - h) / 2.0;
    return .{ .x = x, .y = y, .width = w, .height = h };
}

pub fn backButtonRectForScreen(screen_width: i32, screen_height: i32) rl.Rectangle {
    const panel = panelRectForScreen(screen_width, screen_height);
    return .{ .x = panel.x + panel.width - 144.0, .y = panel.y + 22.0, .width = 120.0, .height = 44.0 };
}

pub fn prevButtonRectForScreen(screen_width: i32, screen_height: i32) rl.Rectangle {
    const panel = panelRectForScreen(screen_width, screen_height);
    return .{ .x = panel.x + 40.0, .y = panel.y + panel.height - 72.0, .width = 92.0, .height = 44.0 };
}

pub fn nextButtonRectForScreen(screen_width: i32, screen_height: i32) rl.Rectangle {
    const panel = panelRectForScreen(screen_width, screen_height);
    return .{
        .x = panel.x + panel.width - 132.0,
        .y = panel.y + panel.height - 72.0,
        .width = 92.0,
        .height = 44.0,
    };
}

fn panelRect() rl.Rectangle {
    return panelRectForScreen(rl.getScreenWidth(), rl.getScreenHeight());
}

fn backButtonRect() rl.Rectangle {
    return backButtonRectForScreen(rl.getScreenWidth(), rl.getScreenHeight());
}

fn prevButtonRect() rl.Rectangle {
    return prevButtonRectForScreen(rl.getScreenWidth(), rl.getScreenHeight());
}

fn nextButtonRect() rl.Rectangle {
    return nextButtonRectForScreen(rl.getScreenWidth(), rl.getScreenHeight());
}

fn pageTitle(page: Page) [:0]const u8 {
    return switch (page) {
        .controls => "Controls",
        .line_merge => "Line Merge",
        .bombs => "Bombs",
        .shuffle => "Shuffle",
        .scoring => "Scoring",
    };
}

fn drawPageText(page: Page, x: i32, y: i32, color: rl.Color) void {
    const lh: i32 = 34;
    switch (page) {
        .controls => {
            rl.drawText("Swap neighbors by drag or click+click.", x, y, 24, color);
            rl.drawText("Hotkeys:", x, y + lh, 24, color);
            rl.drawText("R - New Game", x, y + lh * 2, 24, color);
            rl.drawText("S - Shuffle", x, y + lh * 3, 24, color);
            rl.drawText("H - How to Play", x, y + lh * 4, 24, color);
        },
        .line_merge => {
            rl.drawText("A straight line of 3+ equal tiles merges", x, y, 24, color);
            rl.drawText("into one stronger result tile.", x, y + lh, 24, color);
            rl.drawText("Longer lines usually produce bigger results.", x, y + lh * 2, 24, color);
            rl.drawText("Cascades can continue automatically.", x, y + lh * 3, 24, color);
        },
        .bombs => {
            rl.drawText("A bomb appears when an intersection has", x, y, 24, color);
            rl.drawText("both horizontal 4+ and vertical 4+ lines.", x, y + lh, 24, color);
            rl.drawText("Swap with a bomb to explode a 3x3 area.", x, y + lh * 2, 24, color);
            rl.drawText("That 3x3 value pool reduces to one tile.", x, y + lh * 3, 24, color);
            rl.drawText("Score increases by that resulting value.", x, y + lh * 4, 24, color);
        },
        .shuffle => {
            rl.drawText("Manual Shuffle costs 1 shuffle.", x, y, 24, color);
            rl.drawText("If no moves remain, auto-shuffle", x, y + lh, 24, color);
            rl.drawText("runs if any shuffles are left.", x, y + lh * 2, 24, color);
            rl.drawText("If moves are gone and shuffles are 0,", x, y + lh * 3, 24, color);
            rl.drawText("the run ends.", x, y + lh * 4, 24, color);
        },
        .scoring => {
            rl.drawText("Each merged result tile adds score by", x, y, 24, color);
            rl.drawText("its resulting value.", x, y + lh, 24, color);
            rl.drawText("Cascade waves keep adding extra points.", x, y + lh * 2, 24, color);
            rl.drawText("Reach 2048+ to win.", x, y + lh * 3, 24, color);
        },
    }
}

fn drawPageIllustration(page: Page, panel: rl.Rectangle) void {
    const box = rl.Rectangle{
        .x = panel.x + 30.0,
        .y = panel.y + 104.0,
        .width = 300.0,
        .height = 400.0,
    };
    rl.drawRectangleRec(box, rl.Color.init(187, 173, 160, 255));
    rl.drawRectangleLinesEx(box, 1.5, rl.Color.init(161, 136, 127, 255));

    switch (page) {
        .controls => drawControlsIllustration(box),
        .line_merge => drawLineMergeIllustration(box),
        .bombs => drawBombIllustration(box),
        .shuffle => drawShuffleIllustration(box),
        .scoring => drawScoringIllustration(box),
    }
}

fn drawControlsIllustration(box: rl.Rectangle) void {
    const ink = rl.Color.init(119, 110, 101, 255);
    const tile_size: f32 = 68.0;
    const gap: f32 = 54.0;
    const cx = box.x + box.width / 2.0;
    const cy = box.y + box.height / 2.0 - 20.0;
    const left_x = cx - gap / 2.0 - tile_size;
    const right_x = cx + gap / 2.0;
    const top_y = cy - tile_size / 2.0;

    drawMiniTile(left_x, top_y, tile_size, 2, rl.Color.init(238, 228, 218, 255), ink);
    drawMiniTile(right_x, top_y, tile_size, 4, rl.Color.init(237, 224, 200, 255), ink);
    drawBidirectionalArrow(
        left_x + tile_size + 12.0,
        cy,
        right_x - 12.0,
        cy,
        rl.Color.init(142, 128, 112, 255),
    );
    rl.drawText("Swap adjacent tiles", @as(i32, @intFromFloat(box.x)) + 58, @as(i32, @intFromFloat(top_y + tile_size + 44.0)), 24, ink);
}

fn drawLineMergeIllustration(box: rl.Rectangle) void {
    drawMiniTile(box.x + 20.0, box.y + 90.0, 52.0, 2, rl.Color.init(238, 228, 218, 255), rl.Color.init(119, 110, 101, 255));
    drawMiniTile(box.x + 82.0, box.y + 90.0, 52.0, 2, rl.Color.init(238, 228, 218, 255), rl.Color.init(119, 110, 101, 255));
    drawMiniTile(box.x + 144.0, box.y + 90.0, 52.0, 2, rl.Color.init(238, 228, 218, 255), rl.Color.init(119, 110, 101, 255));
    rl.drawText("=>", @as(i32, @intFromFloat(box.x)) + 204, @as(i32, @intFromFloat(box.y)) + 106, 28, rl.Color.init(119, 110, 101, 255));
    drawMiniTile(box.x + 238.0, box.y + 90.0, 52.0, 4, rl.Color.init(237, 224, 200, 255), rl.Color.init(119, 110, 101, 255));
    rl.drawText("2-2-2 => 4", @as(i32, @intFromFloat(box.x)) + 82, @as(i32, @intFromFloat(box.y)) + 176, 24, rl.Color.init(119, 110, 101, 255));
}

fn drawBombIllustration(box: rl.Rectangle) void {
    const ink = rl.Color.init(119, 110, 101, 255);
    const two_bg = rl.Color.init(238, 228, 218, 255);
    drawMiniTile(box.x + 46.0, box.y + 58.0, 34.0, 2, two_bg, ink);
    drawMiniTile(box.x + 84.0, box.y + 58.0, 34.0, 2, two_bg, ink);
    drawMiniTile(box.x + 122.0, box.y + 58.0, 34.0, 2, two_bg, ink);
    drawMiniTile(box.x + 160.0, box.y + 58.0, 34.0, 2, two_bg, ink);
    drawMiniTile(box.x + 122.0, box.y + 20.0, 34.0, 2, two_bg, ink);
    drawMiniTile(box.x + 122.0, box.y + 96.0, 34.0, 2, two_bg, ink);
    drawMiniTile(box.x + 122.0, box.y + 134.0, 34.0, 2, two_bg, ink);
    drawMiniBomb(box.x + 226.0, box.y + 53.0, 44.0, 8);
    rl.drawText("H4 + V4 => bomb", @as(i32, @intFromFloat(box.x)) + 58, @as(i32, @intFromFloat(box.y)) + 182, 22, ink);

    const pool = [_]u32{ 2, 4, 2, 4, 8, 4, 2, 4, 2 };
    drawSmallBoard3x3(box.x + 24.0, box.y + 236.0, 18.0, 4.0, &pool);
    rl.drawText("=>", @as(i32, @intFromFloat(box.x)) + 138, @as(i32, @intFromFloat(box.y)) + 264, 24, ink);
    drawMiniTile(box.x + 174.0, box.y + 248.0, 44.0, 32, rl.Color.init(242, 177, 121, 255), rl.Color.init(249, 246, 242, 255));
    rl.drawText("3x3 pool => one tile", @as(i32, @intFromFloat(box.x)) + 24, @as(i32, @intFromFloat(box.y)) + 332, 21, ink);
}

fn drawShuffleIllustration(box: rl.Rectangle) void {
    const ink = rl.Color.init(119, 110, 101, 255);
    const board_before = [_]u32{
        2, 4, 2, 4,
        4, 8, 4, 8,
        2, 4, 2, 4,
        8, 2, 8, 2,
    };
    const board_after = [_]u32{
        8, 2, 4, 2,
        2, 8, 4, 4,
        4, 2, 8, 2,
        2, 4, 8, 4,
    };
    rl.drawText("Same values, different layout", @as(i32, @intFromFloat(box.x)) + 18, @as(i32, @intFromFloat(box.y)) + 48, 22, ink);
    drawSmallBoard4x4(box.x + 10.0, box.y + 92.0, 18.0, 4.0, &board_before);
    drawSmallBoard4x4(box.x + 188.0, box.y + 92.0, 18.0, 4.0, &board_after);
    rl.drawText("=>", @as(i32, @intFromFloat(box.x)) + 148, @as(i32, @intFromFloat(box.y)) + 132, 24, ink);
    rl.drawText("Auto-shuffle spends 1 shuffle", @as(i32, @intFromFloat(box.x)) + 20, @as(i32, @intFromFloat(box.y)) + 250, 22, ink);
    rl.drawText("when no valid moves remain.", @as(i32, @intFromFloat(box.x)) + 28, @as(i32, @intFromFloat(box.y)) + 280, 22, ink);
}

fn drawScoringIllustration(box: rl.Rectangle) void {
    const ink = rl.Color.init(119, 110, 101, 255);
    drawMiniTile(box.x + 28.0, box.y + 90.0, 40.0, 2, rl.Color.init(238, 228, 218, 255), ink);
    drawMiniTile(box.x + 74.0, box.y + 90.0, 40.0, 2, rl.Color.init(238, 228, 218, 255), ink);
    drawMiniTile(box.x + 120.0, box.y + 90.0, 40.0, 2, rl.Color.init(238, 228, 218, 255), ink);
    rl.drawText("=>", @as(i32, @intFromFloat(box.x)) + 168, @as(i32, @intFromFloat(box.y)) + 102, 24, ink);
    drawMiniTile(box.x + 204.0, box.y + 90.0, 40.0, 4, rl.Color.init(237, 224, 200, 255), ink);
    rl.drawText("+4", @as(i32, @intFromFloat(box.x)) + 248, @as(i32, @intFromFloat(box.y)) + 102, 24, ink);

    drawMiniTile(box.x + 28.0, box.y + 158.0, 40.0, 4, rl.Color.init(237, 224, 200, 255), ink);
    drawMiniTile(box.x + 74.0, box.y + 158.0, 40.0, 4, rl.Color.init(237, 224, 200, 255), ink);
    drawMiniTile(box.x + 120.0, box.y + 158.0, 40.0, 4, rl.Color.init(237, 224, 200, 255), ink);
    rl.drawText("=>", @as(i32, @intFromFloat(box.x)) + 168, @as(i32, @intFromFloat(box.y)) + 170, 24, ink);
    drawMiniTile(box.x + 204.0, box.y + 158.0, 40.0, 8, rl.Color.init(242, 177, 121, 255), rl.Color.init(249, 246, 242, 255));
    rl.drawText("+8", @as(i32, @intFromFloat(box.x)) + 248, @as(i32, @intFromFloat(box.y)) + 170, 24, ink);

    rl.drawText("Each result tile adds its value.", @as(i32, @intFromFloat(box.x)) + 28, @as(i32, @intFromFloat(box.y)) + 254, 23, ink);
    rl.drawText("Cascades stack those gains.", @as(i32, @intFromFloat(box.x)) + 28, @as(i32, @intFromFloat(box.y)) + 286, 23, ink);
}

fn drawMiniTile(x: f32, y: f32, size: f32, value: u32, bg: rl.Color, text_color: rl.Color) void {
    rl.drawRectangleRec(.{ .x = x, .y = y, .width = size, .height = size }, bg);
    rl.drawRectangleLinesEx(
        .{ .x = x, .y = y, .width = size, .height = size },
        1.0,
        rl.Color.init(205, 193, 180, 255),
    );
    var buf: [16]u8 = undefined;
    const txt = std.fmt.bufPrintZ(&buf, "{d}", .{value}) catch "?";
    const preferred_fs: i32 = if (value < 100) 22 else 18;
    const max_fs = @as(i32, @intFromFloat(size * 0.55));
    const fs: i32 = @max(10, @min(preferred_fs, max_fs));
    const tw = rl.measureText(txt, fs);
    rl.drawText(
        txt,
        @as(i32, @intFromFloat(x + size / 2.0)) - @divTrunc(tw, 2),
        @as(i32, @intFromFloat(y + size / 2.0)) - @divTrunc(fs, 2),
        fs,
        text_color,
    );
}

fn drawMiniBomb(x: f32, y: f32, size: f32, value: u32) void {
    const rect = rl.Rectangle{ .x = x, .y = y, .width = size, .height = size };
    rl.drawRectangleRec(rect, rl.Color.init(142, 74, 74, 255));
    rl.drawRectangleLinesEx(rect, 1.0, rl.Color.init(205, 193, 180, 255));
    var bomb_buf: [24]u8 = undefined;
    const txt = std.fmt.bufPrintZ(&bomb_buf, "B{d}", .{value}) catch "B?";
    const preferred_fs: i32 = if (value < 100) 22 else if (value < 1000) 18 else 16;
    const max_fs = @as(i32, @intFromFloat(size * 0.55));
    const fs: i32 = @max(10, @min(preferred_fs, max_fs));
    const tw = rl.measureText(txt, fs);
    rl.drawText(
        txt,
        @as(i32, @intFromFloat(x + size / 2.0)) - @divTrunc(tw, 2),
        @as(i32, @intFromFloat(y + size / 2.0)) - @divTrunc(fs, 2),
        fs,
        rl.Color.init(249, 246, 242, 255),
    );
}

fn drawBidirectionalArrow(x1: f32, y1: f32, x2: f32, y2: f32, color: rl.Color) void {
    const head: f32 = 8.0;
    rl.drawLineEx(.{ .x = x1, .y = y1 }, .{ .x = x2, .y = y2 }, 3.0, color);
    rl.drawTriangle(
        .{ .x = x1, .y = y1 },
        .{ .x = x1 + head, .y = y1 - head * 0.7 },
        .{ .x = x1 + head, .y = y1 + head * 0.7 },
        color,
    );
    rl.drawTriangle(
        .{ .x = x2, .y = y2 },
        .{ .x = x2 - head, .y = y2 - head * 0.7 },
        .{ .x = x2 - head, .y = y2 + head * 0.7 },
        color,
    );
}

fn drawSmallBoard3x3(x: f32, y: f32, tile_size: f32, gap: f32, values: *const [9]u32) void {
    const side = tile_size * 3.0 + gap * 4.0;
    const board_rect = rl.Rectangle{ .x = x, .y = y, .width = side, .height = side };
    rl.drawRectangleRec(board_rect, rl.Color.init(187, 173, 160, 255));
    rl.drawRectangleLinesEx(board_rect, 1.0, rl.Color.init(161, 136, 127, 255));

    for (0..3) |r| {
        for (0..3) |c| {
            const idx = r * 3 + c;
            const tx = x + gap + @as(f32, @floatFromInt(c)) * (tile_size + gap);
            const ty = y + gap + @as(f32, @floatFromInt(r)) * (tile_size + gap);
            const v = values[idx];
            drawMiniTile(tx, ty, tile_size, v, miniTileColor(v), miniTileTextColor(v));
        }
    }
}

fn drawSmallBoard4x4(x: f32, y: f32, tile_size: f32, gap: f32, values: *const [16]u32) void {
    const side = tile_size * 4.0 + gap * 5.0;
    const board_rect = rl.Rectangle{ .x = x, .y = y, .width = side, .height = side };
    rl.drawRectangleRec(board_rect, rl.Color.init(187, 173, 160, 255));
    rl.drawRectangleLinesEx(board_rect, 1.0, rl.Color.init(161, 136, 127, 255));

    for (0..4) |r| {
        for (0..4) |c| {
            const idx = r * 4 + c;
            const tx = x + gap + @as(f32, @floatFromInt(c)) * (tile_size + gap);
            const ty = y + gap + @as(f32, @floatFromInt(r)) * (tile_size + gap);
            const v = values[idx];
            drawMiniTile(tx, ty, tile_size, v, miniTileColor(v), miniTileTextColor(v));
        }
    }
}

fn miniTileColor(value: u32) rl.Color {
    return switch (value) {
        2 => rl.Color.init(238, 228, 218, 255),
        4 => rl.Color.init(237, 224, 200, 255),
        8 => rl.Color.init(242, 177, 121, 255),
        16 => rl.Color.init(245, 149, 99, 255),
        32 => rl.Color.init(246, 124, 95, 255),
        64 => rl.Color.init(246, 94, 59, 255),
        else => rl.Color.init(205, 193, 180, 255),
    };
}

fn miniTileTextColor(value: u32) rl.Color {
    return if (value <= 4) rl.Color.init(119, 110, 101, 255) else rl.Color.init(249, 246, 242, 255);
}

fn drawActionButton(rect: rl.Rectangle, label: [:0]const u8, enabled: bool, hovered: bool) void {
    const fill = if (!enabled)
        rl.Color.init(189, 180, 170, 255)
    else if (hovered)
        rl.Color.init(143, 122, 102, 255)
    else
        rl.Color.init(161, 136, 127, 255);
    rl.drawRectangleRec(rect, fill);

    const fs: i32 = 24;
    const tw = rl.measureText(label, fs);
    rl.drawText(
        label,
        @as(i32, @intFromFloat(rect.x + rect.width / 2.0)) - @divTrunc(tw, 2),
        @as(i32, @intFromFloat(rect.y + rect.height / 2.0)) - @divTrunc(fs, 2),
        fs,
        rl.Color.init(249, 246, 242, 255),
    );
}
