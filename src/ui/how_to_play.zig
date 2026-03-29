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
    const title_y = @as(i32, @intFromFloat(panel.y)) + 96;
    const text_right = @as(i32, @intFromFloat(panel.x + panel.width)) - 30;
    const text_max_width = text_right - title_x;
    rl.drawText(pageTitle(page), title_x, title_y, 32, ink);
    drawPageText(page, title_x, @as(i32, @intFromFloat(panel.y)) + 134, text_max_width, ink);
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

fn drawPageText(page: Page, x: i32, y: i32, max_width: i32, color: rl.Color) void {
    const lh: i32 = 34;
    var cursor = y;
    switch (page) {
        .controls => {
            cursor += drawGuideWrapped("Swap neighbors by drag or click+click.", x, cursor, 24, max_width, lh, color);
            cursor += lh; // empty line before hotkeys
            cursor += drawGuideWrapped("Hotkeys:", x, cursor, 24, max_width, lh, color);
            cursor += drawGuideWrapped("R - New Game", x, cursor, 24, max_width, lh, color);
            cursor += drawGuideWrapped("S - Shuffle", x, cursor, 24, max_width, lh, color);
            _ = drawGuideWrapped("H - How to Play", x, cursor, 24, max_width, lh, color);
        },
        .line_merge => {
            cursor += drawGuideWrapped("A straight line of 3+ equal tiles merges", x, cursor, 24, max_width, lh, color);
            cursor += drawGuideWrapped("into one stronger result tile.", x, cursor, 24, max_width, lh, color);
            cursor += drawGuideWrapped("Longer lines usually produce bigger results.", x, cursor, 24, max_width, lh, color);
            _ = drawGuideWrapped("Cascades can continue automatically.", x, cursor, 24, max_width, lh, color);
        },
        .bombs => {
            cursor += drawGuideWrapped("A bomb appears when an intersection has", x, cursor, 24, max_width, lh, color);
            cursor += drawGuideWrapped("both horizontal 4+ and vertical 4+ lines.", x, cursor, 24, max_width, lh, color);
            cursor += drawGuideWrapped("Swap with a bomb to explode a 3x3 area.", x, cursor, 24, max_width, lh, color);
            cursor += drawGuideWrapped("That 3x3 value pool reduces to one tile.", x, cursor, 24, max_width, lh, color);
            _ = drawGuideWrapped("Score increases by that resulting value.", x, cursor, 24, max_width, lh, color);
        },
        .shuffle => {
            cursor += drawGuideWrapped("Manual Shuffle costs 1 shuffle.", x, cursor, 24, max_width, lh, color);
            cursor += drawGuideWrapped("If no moves remain, auto-shuffle", x, cursor, 24, max_width, lh, color);
            cursor += drawGuideWrapped("runs if any shuffles are left.", x, cursor, 24, max_width, lh, color);
            cursor += drawGuideWrapped("If moves are gone and shuffles are 0,", x, cursor, 24, max_width, lh, color);
            _ = drawGuideWrapped("the run ends.", x, cursor, 24, max_width, lh, color);
        },
        .scoring => {
            cursor += drawGuideWrapped("Each merged result tile adds score by", x, cursor, 24, max_width, lh, color);
            cursor += drawGuideWrapped("its resulting value.", x, cursor, 24, max_width, lh, color);
            cursor += drawGuideWrapped("Cascade waves keep adding extra points.", x, cursor, 24, max_width, lh, color);
            _ = drawGuideWrapped("Reach 2048+ to win.", x, cursor, 24, max_width, lh, color);
        },
    }
}

fn drawPageIllustration(page: Page, panel: rl.Rectangle) void {
    const box = rl.Rectangle{
        .x = panel.x + 30.0,
        .y = panel.y + 100.0,
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
    const tile_size: f32 = 28.0;
    const gap: f32 = 5.0;
    const step = tile_size + gap;
    const board_w = tile_size * 2.0 + gap * 3.0;
    const board_h = tile_size * 3.0 + gap * 4.0;
    const scene_x = box.x + (box.width - board_w) / 2.0;

    // Animation 1: valid cycle (swap -> merge -> pause)
    const top_y = box.y + 48.0;
    drawMiniBoardBackdrop(scene_x, top_y, 2, 3, tile_size, gap);
    const tl = miniGridTilePos(scene_x, top_y, 0, 0, tile_size, gap);
    const tr = miniGridTilePos(scene_x, top_y, 1, 0, tile_size, gap);
    const cl = miniGridTilePos(scene_x, top_y, 0, 1, tile_size, gap);
    const cr = miniGridTilePos(scene_x, top_y, 1, 1, tile_size, gap);
    const bl = miniGridTilePos(scene_x, top_y, 0, 2, tile_size, gap);
    const br = miniGridTilePos(scene_x, top_y, 1, 2, tile_size, gap);

    const loop_period: f64 = 3.0;
    const t = @as(f32, @floatCast(@mod(rl.getTime(), loop_period)));
    const swap_start: f32 = 0.20;
    const swap_dur: f32 = 0.46;
    const swap_end = swap_start + swap_dur;
    const merge_start: f32 = 0.86;
    const merge_dur: f32 = 0.40;
    const merge_end = merge_start + merge_dur;

    const in_swap = t >= swap_start and t < swap_end;
    const after_swap = t >= swap_end;
    const in_merge = t >= merge_start and t < merge_end;
    const after_merge = t >= merge_end;

    drawMiniTile(tl.x, tl.y, tile_size, 4, miniTileColor(4), miniTileTextColor(4));
    drawMiniTile(bl.x, bl.y, tile_size, 4, miniTileColor(4), miniTileTextColor(4));

    if (!in_merge and !after_merge) {
        drawMiniTile(tr.x, tr.y, tile_size, 2, miniTileColor(2), miniTileTextColor(2));
        drawMiniTile(br.x, br.y, tile_size, 2, miniTileColor(2), miniTileTextColor(2));
    }

    if (in_swap) {
        const p = easeInOut01((t - swap_start) / swap_dur);
        const swap_scale = 1.0 + 0.05 * (1.0 - p);
        drawMiniTileScaled(
            lerpF32(cl.x, cr.x, p),
            cl.y,
            tile_size,
            swap_scale,
            2,
            miniTileColor(2),
            miniTileTextColor(2),
        );
        drawMiniTileScaled(
            lerpF32(cr.x, cl.x, p),
            cr.y,
            tile_size,
            swap_scale,
            8,
            miniTileColor(8),
            miniTileTextColor(8),
        );
    } else if (!after_swap) {
        drawMiniTile(cl.x, cl.y, tile_size, 2, miniTileColor(2), miniTileTextColor(2));
        drawMiniTile(cr.x, cr.y, tile_size, 8, miniTileColor(8), miniTileTextColor(8));
    } else {
        drawMiniTile(cl.x, cl.y, tile_size, 8, miniTileColor(8), miniTileTextColor(8));
        if (!in_merge and !after_merge) {
            drawMiniTile(cr.x, cr.y, tile_size, 2, miniTileColor(2), miniTileTextColor(2));
        }
    }

    if (in_merge) {
        const mp = easeInOut01((t - merge_start) / merge_dur);
        const match_scale = 1.0 + 0.22 * (1.0 - mp);
        const match_alpha = 1.0 - mp;
        drawMiniTileScaledAlpha(tr.x, tr.y, tile_size, match_scale, match_alpha, 2, miniTileColor(2), miniTileTextColor(2));
        drawMiniTileScaledAlpha(cr.x, cr.y, tile_size, match_scale, match_alpha, 2, miniTileColor(2), miniTileTextColor(2));
        drawMiniTileScaledAlpha(br.x, br.y, tile_size, match_scale, match_alpha, 2, miniTileColor(2), miniTileTextColor(2));

        const out_alpha = std.math.clamp((mp - 0.45) / 0.55, 0.0, 1.0);
        const out_scale = 1.08 - 0.08 * out_alpha;
        drawMiniTileScaledAlpha(cr.x, cr.y, tile_size, out_scale, out_alpha, 4, miniTileColor(4), miniTileTextColor(4));
    } else if (after_merge) {
        drawMiniTile(cr.x, cr.y, tile_size, 4, miniTileColor(4), miniTileTextColor(4));
    }

    rl.drawText(
        "Swap -> Merge",
        centeredTextX(box, "Swap -> Merge", 20),
        @as(i32, @intFromFloat(top_y + board_h + 8.0)),
        20,
        ink,
    );

    // Animation 2: invalid move attempt (4 nudges into 2, then columns shake)
    const bottom_y = box.y + 214.0;
    drawMiniBoardBackdrop(scene_x, bottom_y, 2, 3, tile_size, gap);
    const invalid_values = [_]u32{
        2, 4,
        4, 2,
        8, 2,
    };
    const invalid_active_period: f64 = 1.45;
    const invalid_pause_period: f64 = 1.55;
    const invalid_loop_period = invalid_active_period + invalid_pause_period;
    const invalid_loop_t = @mod(rl.getTime(), invalid_loop_period);
    const invalid_active = invalid_loop_t < invalid_active_period;
    const invalid_phase = if (invalid_active)
        @as(f32, @floatCast(invalid_loop_t / invalid_active_period))
    else
        1.0;
    var push: f32 = 0.0;
    if (invalid_active and invalid_phase < 0.34) {
        push = 0.42 * easeInOut01(invalid_phase / 0.34);
    } else if (invalid_active and invalid_phase < 0.50) {
        push = 0.42 * (1.0 - easeInOut01((invalid_phase - 0.34) / 0.16));
    }
    var shake_x: f32 = 0.0;
    if (invalid_active and invalid_phase >= 0.50) {
        const shake_t = (invalid_phase - 0.50) / 0.50;
        const decay = 1.0 - shake_t;
        shake_x = @as(f32, @floatCast(std.math.sin(shake_t * 50.0))) * 2.3 * decay;
    }
    for (0..3) |r| {
        for (0..2) |c| {
            if (r == 1 and c == 0) continue;
            const idx = r * 2 + c;
            var p = miniGridTilePos(scene_x, bottom_y, c, r, tile_size, gap);
            p.x += shake_x;
            const v = invalid_values[idx];
            drawMiniTile(p.x, p.y, tile_size, v, miniTileColor(v), miniTileTextColor(v));
        }
    }
    var moving = miniGridTilePos(scene_x, bottom_y, 0, 1, tile_size, gap);
    moving.x += shake_x + push * step;
    drawMiniTileScaled(moving.x, moving.y, tile_size, 1.0, 4, miniTileColor(4), miniTileTextColor(4));
    rl.drawText(
        "Invalid move: no line match",
        centeredTextX(box, "Invalid move: no line match", 20),
        @as(i32, @intFromFloat(bottom_y + board_h + 8.0)),
        20,
        ink,
    );
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
    drawMiniTileAlpha(x, y, size, value, bg, text_color, 1.0);
}

fn drawMiniTileAlpha(
    x: f32,
    y: f32,
    size: f32,
    value: u32,
    bg: rl.Color,
    text_color: rl.Color,
    alpha: f32,
) void {
    rl.drawRectangleRec(.{ .x = x, .y = y, .width = size, .height = size }, colorWithAlpha(bg, alpha));
    rl.drawRectangleLinesEx(
        .{ .x = x, .y = y, .width = size, .height = size },
        1.0,
        colorWithAlpha(rl.Color.init(205, 193, 180, 255), alpha),
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
        colorWithAlpha(text_color, alpha),
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

fn drawMiniTileScaled(
    x: f32,
    y: f32,
    size: f32,
    scale: f32,
    value: u32,
    bg: rl.Color,
    text_color: rl.Color,
) void {
    drawMiniTileScaledAlpha(x, y, size, scale, 1.0, value, bg, text_color);
}

fn drawMiniTileScaledAlpha(
    x: f32,
    y: f32,
    size: f32,
    scale: f32,
    alpha: f32,
    value: u32,
    bg: rl.Color,
    text_color: rl.Color,
) void {
    const scaled = size * scale;
    const ox = (size - scaled) / 2.0;
    const oy = (size - scaled) / 2.0;
    drawMiniTileAlpha(x + ox, y + oy, scaled, value, bg, text_color, alpha);
}

fn drawMiniBoardBackdrop(
    x: f32,
    y: f32,
    cols: usize,
    rows: usize,
    tile_size: f32,
    gap: f32,
) void {
    const w = tile_size * @as(f32, @floatFromInt(cols)) + gap * (@as(f32, @floatFromInt(cols)) + 1.0);
    const h = tile_size * @as(f32, @floatFromInt(rows)) + gap * (@as(f32, @floatFromInt(rows)) + 1.0);
    const board_rect = rl.Rectangle{ .x = x, .y = y, .width = w, .height = h };
    rl.drawRectangleRec(board_rect, rl.Color.init(187, 173, 160, 255));
    rl.drawRectangleLinesEx(board_rect, 1.0, rl.Color.init(161, 136, 127, 255));
}

fn miniGridTilePos(
    origin_x: f32,
    origin_y: f32,
    col: usize,
    row: usize,
    tile_size: f32,
    gap: f32,
) rl.Vector2 {
    return .{
        .x = origin_x + gap + @as(f32, @floatFromInt(col)) * (tile_size + gap),
        .y = origin_y + gap + @as(f32, @floatFromInt(row)) * (tile_size + gap),
    };
}

fn cycle01(period_s: f64) f32 {
    return @as(f32, @floatCast(@mod(rl.getTime(), period_s) / period_s));
}

fn easeInOut01(t: f32) f32 {
    const c = std.math.clamp(t, 0.0, 1.0);
    return c * c * (3.0 - 2.0 * c);
}

fn lerpF32(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

fn drawGuideWrapped(
    text: []const u8,
    x: i32,
    y: i32,
    font_size: i32,
    max_width: i32,
    line_height: i32,
    color: rl.Color,
) i32 {
    var line_buf: [256]u8 = undefined;
    var line_len: usize = 0;
    var lines: i32 = 0;

    var words = std.mem.tokenizeScalar(u8, text, ' ');
    while (words.next()) |word| {
        var candidate_len = line_len;
        if (candidate_len != 0) {
            line_buf[candidate_len] = ' ';
            candidate_len += 1;
        }
        if (candidate_len + word.len >= line_buf.len) continue;
        @memcpy(line_buf[candidate_len .. candidate_len + word.len], word);
        candidate_len += word.len;
        line_buf[candidate_len] = 0;

        if (line_len != 0 and rl.measureText(line_buf[0..candidate_len :0], font_size) > max_width) {
            line_buf[line_len] = 0;
            rl.drawText(line_buf[0..line_len :0], x, y + lines * line_height, font_size, color);
            lines += 1;

            if (word.len >= line_buf.len) continue;
            @memcpy(line_buf[0..word.len], word);
            line_len = word.len;
        } else {
            line_len = candidate_len;
        }
    }

    if (line_len > 0) {
        line_buf[line_len] = 0;
        rl.drawText(line_buf[0..line_len :0], x, y + lines * line_height, font_size, color);
        lines += 1;
    }

    return @max(lines, 1) * line_height;
}

fn centeredTextX(rect: rl.Rectangle, text: [:0]const u8, font_size: i32) i32 {
    const text_w = rl.measureText(text, font_size);
    return @as(i32, @intFromFloat(rect.x + rect.width / 2.0)) - @divTrunc(text_w, 2);
}

fn colorWithAlpha(color: rl.Color, alpha: f32) rl.Color {
    const scaled = @as(i32, @intFromFloat(@as(f32, @floatFromInt(color.a)) * std.math.clamp(alpha, 0.0, 1.0)));
    return rl.Color.init(color.r, color.g, color.b, @as(u8, @intCast(std.math.clamp(scaled, 0, 255))));
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
