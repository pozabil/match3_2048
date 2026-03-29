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

var anim_anchor_open: bool = false;
var anim_anchor_page: u8 = 0;
var anim_anchor_time: f64 = 0.0;

pub fn clampPage(page: u8) u8 {
    return if (page < PAGE_COUNT) page else PAGE_COUNT - 1;
}

pub fn draw(open: bool, page_index: u8) void {
    if (!open) {
        updateAnimationAnchor(false, 0);
        return;
    }

    const clamped_page = clampPage(page_index);
    updateAnimationAnchor(true, clamped_page);
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

fn updateAnimationAnchor(open: bool, page: u8) void {
    if (!open) {
        anim_anchor_open = false;
        return;
    }

    if (!anim_anchor_open or anim_anchor_page != page) {
        anim_anchor_open = true;
        anim_anchor_page = page;
        anim_anchor_time = rl.getTime();
    }
}

fn pageLoopTime(period_s: f64) f64 {
    if (period_s <= 0.0001) return 0.0;
    const elapsed = @max(0.0, rl.getTime() - anim_anchor_time);
    return @mod(elapsed, period_s);
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
            cursor += drawGuideWrapped("A straight line of 3+ equal tiles merges into one stronger result tile. When lines with the same value intersect, they merge as one shared group.", x, cursor, 24, max_width, lh, color);
            cursor += drawGuideWrapped("Longer lines usually produce bigger results, and cascades can continue automatically.", x, cursor, 24, max_width, lh, color);
            _ = drawGuideWrapped("Reach 2048+ to win.", x, cursor, 24, max_width, lh, color);
        },
        .bombs => {
            cursor += drawGuideWrapped("A bomb appears when an intersection has both horizontal 4+ and vertical 4+ lines.", x, cursor, 24, max_width, lh, color);
            cursor += drawGuideWrapped("Swap with a bomb to explode a 3x3 area.", x, cursor, 24, max_width, lh, color);
            cursor += drawGuideWrapped("Bomb result tile: that 3x3 value pool resolves from lowest to highest; matching pairs merge, and unpaired values are removed until one final tile remains.", x, cursor, 24, max_width, lh, color);
        },
        .shuffle => {
            cursor += drawGuideWrapped("Shuffle rearranges tiles on the board.", x, cursor, 24, max_width, lh, color);
            cursor += drawGuideWrapped("You can use Shuffle if you're stuck; it costs 1 shuffle.", x, cursor, 24, max_width, lh, color);
            cursor += drawGuideWrapped("If no valid moves remain, auto-shuffle spends 1 shuffle if you have any left.", x, cursor, 24, max_width, lh, color);
            cursor += drawGuideWrapped("You gain +1 shuffle the first time you create a 1024+ tile.", x, cursor, 24, max_width, lh, color);
            _ = drawGuideWrapped("If no moves remain and shuffles are 0, the run is lost.", x, cursor, 24, max_width, lh, color);
        },
        .scoring => {
            cursor += drawGuideWrapped("Each merged result tile adds score by its resulting value.", x, cursor, 24, max_width, lh, color);
            _ = drawGuideWrapped("Cascade waves add score too, with a higher multiplier.", x, cursor, 24, max_width, lh, color);
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
    const t = @as(f32, @floatCast(pageLoopTime(loop_period)));
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
    const invalid_loop_t = pageLoopTime(invalid_loop_period);
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
    const tile_size: f32 = 28.0;
    const gap: f32 = 5.0;
    const board_w = tile_size * 4.0 + gap * 5.0;
    const board_h = board_w;
    const board_x = box.x + (box.width - board_w) / 2.0;
    const board_y = box.y + (box.height - board_h) / 2.0;

    const initial = [_]u32{
        8,  4, 8, 2,
        2,  4, 8, 2,
        16, 2, 4, 4,
        2,  4, 2, 2,
    };
    const after_swap = [_]u32{
        8,  4, 8, 2,
        2,  4, 8, 2,
        16, 4, 4, 4,
        2,  2, 2, 2,
    };
    const after_wave1_clear = [_]u32{
        8,  0,  8, 2,
        2,  0,  8, 2,
        16, 16, 0, 0,
        0,  8,  0, 0,
    };
    const after_fall1 = [_]u32{
        4,  4,  8, 4,
        8,  4,  4, 4,
        2,  16, 8, 2,
        16, 8,  8, 2,
    };
    const after_wave2_clear = [_]u32{
        4,  4,  8, 4,
        8,  0,  8, 0,
        2,  16, 8, 2,
        16, 8,  8, 2,
    };
    const after_fall2 = [_]u32{
        4,  4,  8, 4,
        8,  4,  8, 4,
        2,  16, 8, 2,
        16, 8,  8, 2,
    };
    const after_wave3_clear = [_]u32{
        4,  4,  0,  4,
        8,  4,  0,  4,
        2,  16, 32, 2,
        16, 8,  0,  2,
    };
    const after_fall3 = [_]u32{
        4,  4,  2,  4,
        8,  4,  8,  4,
        2,  16, 4,  2,
        16, 8,  32, 2,
    };

    const wave1_mask = [_]bool{
        false, true, false, false,
        false, true, false, false,
        false, true, true,  true,
        true,  true, true,  true,
    };
    const wave2_mask = [_]bool{
        false, false, false, false,
        false, true,  true,  true,
        false, false, false, false,
        false, false, false, false,
    };
    const wave3_mask = [_]bool{
        false, false, true, false,
        false, false, true, false,
        false, false, true, false,
        false, false, true, false,
    };

    const wave1_outcomes = [_]MiniOutcome{
        .{ .row = 2, .col = 1, .value = 16 },
        .{ .row = 3, .col = 1, .value = 8 },
    };
    const wave2_outcomes = [_]MiniOutcome{
        .{ .row = 1, .col = 2, .value = 8 },
    };
    const wave3_outcomes = [_]MiniOutcome{
        .{ .row = 2, .col = 2, .value = 32 },
    };

    const time_scale: f32 = 2.0;

    var phases: [12]MiniPhase = undefined;
    var phase_count: usize = 0;

    var swap_phase = initMiniPhase(.swap, 0.17 * time_scale, initial, "Swap");
    swap_phase.hide[idx4(2, 1)] = true;
    swap_phase.hide[idx4(3, 1)] = true;
    miniPhaseAddTrack(&swap_phase, initial[idx4(2, 1)], 2.0, 1.0, 3.0, 1.0);
    miniPhaseAddTrack(&swap_phase, initial[idx4(3, 1)], 3.0, 1.0, 2.0, 1.0);
    pushMiniPhase(phases[0..], &phase_count, swap_phase);

    pushMiniPhase(phases[0..], &phase_count, buildMiniMatchPhase(&after_swap, &wave1_mask, 0.13 * time_scale, "Wave 1: match"));
    pushMiniPhase(phases[0..], &phase_count, buildMiniResolvePhase(&after_swap, &wave1_mask, wave1_outcomes[0..], 0.13 * time_scale, "Wave 1: merge"));
    pushMiniPhase(phases[0..], &phase_count, buildMiniFallPhase(&after_wave1_clear, &after_fall1, 0.22 * time_scale, "Wave 1: fall"));

    pushMiniPhase(phases[0..], &phase_count, buildMiniMatchPhase(&after_fall1, &wave2_mask, 0.13 * time_scale, "Wave 2: match"));
    pushMiniPhase(phases[0..], &phase_count, buildMiniResolvePhase(&after_fall1, &wave2_mask, wave2_outcomes[0..], 0.13 * time_scale, "Wave 2: merge"));
    pushMiniPhase(phases[0..], &phase_count, buildMiniFallPhase(&after_wave2_clear, &after_fall2, 0.22 * time_scale, "Wave 2: fall"));

    pushMiniPhase(phases[0..], &phase_count, buildMiniMatchPhase(&after_fall2, &wave3_mask, 0.13 * time_scale, "Wave 3: match"));
    pushMiniPhase(phases[0..], &phase_count, buildMiniResolvePhase(&after_fall2, &wave3_mask, wave3_outcomes[0..], 0.13 * time_scale, "Wave 3: merge"));
    pushMiniPhase(phases[0..], &phase_count, buildMiniFallPhase(&after_wave3_clear, &after_fall3, 0.22 * time_scale, "Wave 3: fall"));
    pushMiniPhase(phases[0..], &phase_count, initMiniPhase(.fall_spawn, 1.05 * time_scale, after_fall3, "Result + pause"));

    var period: f32 = 0.0;
    for (phases[0..phase_count]) |ph| {
        period += ph.duration;
    }
    const t = @as(f32, @floatCast(pageLoopTime(@as(f64, @floatCast(period)))));

    var active_idx: usize = phase_count - 1;
    var phase_start: f32 = 0.0;
    var cursor: f32 = 0.0;
    for (phases[0..phase_count], 0..) |ph, i| {
        const phase_end = cursor + ph.duration;
        if (t < phase_end) {
            active_idx = i;
            phase_start = cursor;
            break;
        }
        cursor = phase_end;
    }

    const active = phases[active_idx];
    const progress = if (active.duration > 0.0001)
        std.math.clamp((t - phase_start) / active.duration, 0.0, 1.0)
    else
        1.0;
    drawMiniPhase(board_x, board_y, tile_size, gap, &active, progress);
}

const MiniPhaseKind = enum {
    swap,
    match_flash,
    fall_spawn,
};

const MiniTrack = struct {
    value: u32,
    from_row: f32,
    from_col: f32,
    to_row: f32,
    to_col: f32,
};

const MiniOutcome = struct {
    row: usize,
    col: usize,
    value: u32,
    mult: u32 = 1,
};

const MiniPhase = struct {
    kind: MiniPhaseKind,
    duration: f32,
    base: [16]u32,
    hide: [16]bool,
    tracks: [16]MiniTrack,
    track_count: usize,
    score_pops: [16]MiniOutcome,
    score_pop_count: usize,
    label: [:0]const u8,
};

fn initMiniPhase(kind: MiniPhaseKind, duration: f32, base: [16]u32, label: [:0]const u8) MiniPhase {
    return .{
        .kind = kind,
        .duration = duration,
        .base = base,
        .hide = [_]bool{false} ** 16,
        .tracks = undefined,
        .track_count = 0,
        .score_pops = undefined,
        .score_pop_count = 0,
        .label = label,
    };
}

fn pushMiniPhase(phases: []MiniPhase, phase_count: *usize, phase: MiniPhase) void {
    if (phase_count.* >= phases.len) return;
    phases[phase_count.*] = phase;
    phase_count.* += 1;
}

fn miniPhaseAddTrack(phase: *MiniPhase, value: u32, from_row: f32, from_col: f32, to_row: f32, to_col: f32) void {
    if (phase.track_count >= phase.tracks.len) return;
    phase.tracks[phase.track_count] = .{
        .value = value,
        .from_row = from_row,
        .from_col = from_col,
        .to_row = to_row,
        .to_col = to_col,
    };
    phase.track_count += 1;
}

fn miniPhaseAddScorePop(phase: *MiniPhase, row: usize, col: usize, value: u32) void {
    if (phase.score_pop_count >= phase.score_pops.len) return;
    phase.score_pops[phase.score_pop_count] = .{ .row = row, .col = col, .value = value };
    phase.score_pop_count += 1;
}

fn miniPhaseAddScorePopWithMult(phase: *MiniPhase, row: usize, col: usize, value: u32, mult: u32) void {
    if (phase.score_pop_count >= phase.score_pops.len) return;
    phase.score_pops[phase.score_pop_count] = .{ .row = row, .col = col, .value = value, .mult = mult };
    phase.score_pop_count += 1;
}

fn buildMiniMatchPhase(base: *const [16]u32, mask: *const [16]bool, duration: f32, label: [:0]const u8) MiniPhase {
    var phase = initMiniPhase(.match_flash, duration, base.*, label);
    for (0..4) |r| {
        for (0..4) |c| {
            const idx = idx4(r, c);
            if (!mask[idx]) continue;
            const value = base[idx];
            if (value == 0) continue;
            phase.hide[idx] = true;
            miniPhaseAddTrack(
                &phase,
                value,
                @as(f32, @floatFromInt(r)),
                @as(f32, @floatFromInt(c)),
                @as(f32, @floatFromInt(r)),
                @as(f32, @floatFromInt(c)),
            );
        }
    }
    return phase;
}

fn buildMiniResolvePhase(
    base: *const [16]u32,
    matched_mask: *const [16]bool,
    outcomes: []const MiniOutcome,
    duration: f32,
    label: [:0]const u8,
) MiniPhase {
    var phase = initMiniPhase(.fall_spawn, duration, base.*, label);
    for (0..16) |i| {
        if (matched_mask[i]) phase.hide[i] = true;
    }
    for (outcomes) |o| {
        const idx = idx4(o.row, o.col);
        phase.hide[idx] = true;
        miniPhaseAddTrack(
            &phase,
            o.value,
            @as(f32, @floatFromInt(o.row)),
            @as(f32, @floatFromInt(o.col)),
            @as(f32, @floatFromInt(o.row)),
            @as(f32, @floatFromInt(o.col)),
        );
        miniPhaseAddScorePopWithMult(&phase, o.row, o.col, o.value, o.mult);
    }
    return phase;
}

fn buildMiniFallPhase(before: *const [16]u32, after: *const [16]u32, duration: f32, label: [:0]const u8) MiniPhase {
    var phase = initMiniPhase(.fall_spawn, duration, after.*, label);
    for (0..4) |col| {
        var used_src = [_]bool{false} ** 4;

        var rr: isize = 3;
        while (rr >= 0) : (rr -= 1) {
            const row: usize = @intCast(rr);
            const dst_value = after[idx4(row, col)];
            if (dst_value == 0) continue;

            if (findMiniSourceRow(before, col, row, dst_value, &used_src)) |src_row| {
                used_src[src_row] = true;
                if (src_row != row) {
                    phase.hide[idx4(row, col)] = true;
                    miniPhaseAddTrack(
                        &phase,
                        dst_value,
                        @as(f32, @floatFromInt(src_row)),
                        @as(f32, @floatFromInt(col)),
                        @as(f32, @floatFromInt(row)),
                        @as(f32, @floatFromInt(col)),
                    );
                }
            } else {
                phase.hide[idx4(row, col)] = true;
                miniPhaseAddTrack(
                    &phase,
                    dst_value,
                    -1.2,
                    @as(f32, @floatFromInt(col)),
                    @as(f32, @floatFromInt(row)),
                    @as(f32, @floatFromInt(col)),
                );
            }
        }
    }
    return phase;
}

fn findMiniSourceRow(before: *const [16]u32, col: usize, dst_row: usize, dst_value: u32, used_src: *[4]bool) ?usize {
    var rr: isize = 3;
    while (rr >= 0) : (rr -= 1) {
        const row: usize = @intCast(rr);
        if (used_src[row]) continue;
        if (before[idx4(row, col)] != dst_value) continue;
        if (row <= dst_row) return row;
    }
    return null;
}

fn drawMiniPhase(board_x: f32, board_y: f32, tile_size: f32, gap: f32, phase: *const MiniPhase, progress_01: f32) void {
    drawMiniBoard4x4StateHidden(board_x, board_y, tile_size, gap, &phase.base, &phase.hide);
    const progress_linear = std.math.clamp(progress_01, 0.0, 1.0);
    const progress = easeInOut01(progress_linear);

    for (0..phase.track_count) |i| {
        const track = phase.tracks[i];
        var row = lerpF32(track.from_row, track.to_row, progress);
        var col = lerpF32(track.from_col, track.to_col, progress);
        var scale: f32 = 1.0;
        var alpha: f32 = 1.0;

        switch (phase.kind) {
            .swap => {
                scale = 1.0 + 0.05 * (1.0 - progress);
            },
            .match_flash => {
                row = track.to_row;
                col = track.to_col;
                scale = 1.0 + 0.22 * (1.0 - progress);
                alpha = 1.0 - progress;
            },
            .fall_spawn => {},
        }

        drawMiniTrackTile(board_x, board_y, tile_size, gap, row, col, scale, alpha, track.value);
    }
}

fn drawMiniPhaseScorePops(
    board_x: f32,
    board_y: f32,
    tile_size: f32,
    gap: f32,
    phase: *const MiniPhase,
    pop_time_01: f32,
) void {
    if (phase.score_pop_count == 0) return;
    const fade_start: f32 = 0.66;
    const fade_end: f32 = 1.00;
    const t = std.math.clamp(pop_time_01, 0.0, 1.0);
    const fade_t = std.math.clamp(t, 0.0, fade_end);
    const fade = std.math.clamp((fade_t - fade_start) / (fade_end - fade_start), 0.0, 1.0);
    const pop_alpha = 1.0 - fade;
    const rise = 24.0 * t;
    for (0..phase.score_pop_count) |i| {
        const pop = phase.score_pops[i];
        const pos = miniGridTilePos(board_x, board_y, pop.col, pop.row, tile_size, gap);
        var txt_buf: [24]u8 = undefined;
        const txt = if (pop.mult <= 1)
            (std.fmt.bufPrintZ(&txt_buf, "+{d}", .{pop.value}) catch "+?")
        else
            (std.fmt.bufPrintZ(&txt_buf, "+{d}x{d}", .{ pop.value, pop.mult }) catch "+?");
        const fs: i32 = 20;
        const tw = rl.measureText(txt, fs);
        const tx = @as(i32, @intFromFloat(pos.x + tile_size / 2.0)) - @divTrunc(tw, 2);
        const ty = @as(i32, @intFromFloat(pos.y - 10.0 - rise));
        const outline = colorWithAlpha(rl.Color.init(119, 110, 101, 255), pop_alpha);
        const fill = colorWithAlpha(rl.Color.init(249, 246, 242, 255), pop_alpha);

        rl.drawText(txt, tx - 1, ty, fs, outline);
        rl.drawText(txt, tx + 1, ty, fs, outline);
        rl.drawText(txt, tx, ty - 1, fs, outline);
        rl.drawText(txt, tx, ty + 1, fs, outline);
        rl.drawText(txt, tx - 1, ty - 1, fs, outline);
        rl.drawText(txt, tx + 1, ty - 1, fs, outline);
        rl.drawText(txt, tx - 1, ty + 1, fs, outline);
        rl.drawText(txt, tx + 1, ty + 1, fs, outline);
        rl.drawText(
            txt,
            tx,
            ty,
            fs,
            fill,
        );
    }
}

fn drawMiniTrackTile(
    board_x: f32,
    board_y: f32,
    tile_size: f32,
    gap: f32,
    row: f32,
    col: f32,
    scale: f32,
    alpha: f32,
    value: u32,
) void {
    const step = tile_size + gap;
    const x = board_x + gap + col * step;
    const y = board_y + gap + row * step;
    drawMiniTileScaledAlpha(
        x,
        y,
        tile_size,
        scale,
        alpha,
        value,
        miniTileColor(value),
        miniTileTextColor(value),
    );
}

fn drawBombIllustration(box: rl.Rectangle) void {
    const tile_size: f32 = 28.0;
    const gap: f32 = 5.0;
    const board_w = tile_size * 4.0 + gap * 5.0;
    const board_h = tile_size * 4.0 + gap * 5.0;
    const scene_x = box.x + (box.width - board_w) / 2.0;

    // Animation 1: H4 + V4 intersection produces a bomb.
    const top_y = box.y + 30.0;
    const cross_values = [_]u32{
        2, 8, 2, 4,
        8, 8, 8, 8,
        2, 8, 4, 16,
        4, 8, 2, 2,
    };
    const cross_match_mask = [_]bool{
        false, true, false, false,
        true,  true, true,  true,
        false, true, false, false,
        false, true, false, false,
    };
    const cross_after = [_]u32{
        2, 0,  2, 4,
        0, 16, 0, 0,
        2, 0,  4, 16,
        4, 0,  2, 2,
    };

    const top_period: f64 = 3.2;
    const top_t = @as(f32, @floatCast(pageLoopTime(top_period)));
    const top_match_start: f32 = 0.95;
    const top_match_end: f32 = 1.38;
    const top_resolve_end: f32 = 1.85;

    if (top_t < top_match_start) {
        var hide = [_]bool{false} ** 16;
        drawMiniBoard4x4StateHidden(scene_x, top_y, tile_size, gap, &cross_values, &hide);
    } else if (top_t < top_match_end) {
        const p = easeInOut01((top_t - top_match_start) / (top_match_end - top_match_start));
        drawMiniBoard4x4StateHidden(scene_x, top_y, tile_size, gap, &cross_values, &cross_match_mask);
        for (0..4) |r| {
            for (0..4) |c| {
                const idx = idx4(r, c);
                if (!cross_match_mask[idx]) continue;
                const pos = miniGridTilePos(scene_x, top_y, c, r, tile_size, gap);
                drawMiniTileScaledAlpha(
                    pos.x,
                    pos.y,
                    tile_size,
                    1.0 + 0.22 * (1.0 - p),
                    1.0 - p,
                    8,
                    miniTileColor(8),
                    miniTileTextColor(8),
                );
            }
        }
    } else if (top_t < top_resolve_end) {
        const p = easeInOut01((top_t - top_match_end) / (top_resolve_end - top_match_end));
        var hide = [_]bool{false} ** 16;
        hide[idx4(1, 1)] = true;
        drawMiniBoard4x4StateHidden(scene_x, top_y, tile_size, gap, &cross_after, &hide);
        const bomb_pos = miniGridTilePos(scene_x, top_y, 1, 1, tile_size, gap);
        drawMiniBombScaledAlpha(
            bomb_pos.x,
            bomb_pos.y,
            tile_size,
            1.08 - 0.08 * p,
            std.math.clamp((p - 0.20) / 0.80, 0.0, 1.0),
            16,
        );
    } else {
        var hide = [_]bool{false} ** 16;
        drawMiniBoard4x4StateHidden(scene_x, top_y, tile_size, gap, &cross_after, &hide);
        const bomb_pos = miniGridTilePos(scene_x, top_y, 1, 1, tile_size, gap);
        drawMiniBomb(bomb_pos.x, bomb_pos.y, tile_size, 16);
    }

    // Animation 2: swap bomb, reduce 3x3 values, place result on bomb position.
    const bottom_y = box.y + 216.0;
    const before_swap = [_]u32{
        8, 2,  4,  4,
        4, 16, 2,  2,
        8, 2,  32, 2,
        4, 8,  4,  8,
    };
    const after_swap = [_]u32{
        8, 2, 4,  4,
        4, 2, 16, 2,
        8, 2, 32, 2,
        4, 8, 4,  8,
    };
    const after_clear = [_]u32{
        8, 0, 0, 0,
        4, 0, 0, 0,
        8, 0, 0, 0,
        4, 8, 4, 8,
    };
    const after_result = [_]u32{
        8, 0, 0,  0,
        4, 0, 64, 0,
        8, 0, 0,  0,
        4, 8, 4,  8,
    };
    const blast_mask = [_]bool{
        false, true,  true,  true,
        false, true,  true,  true,
        false, true,  true,  true,
        false, false, false, false,
    };
    const pool_stages = [_][9]u32{
        [_]u32{ 2, 2, 2, 2, 2, 4, 4, 16, 32 },
        [_]u32{ 2, 4, 4, 4, 4, 16, 32, 0, 0 },
        [_]u32{ 4, 4, 4, 4, 16, 32, 0, 0, 0 },
        [_]u32{ 8, 8, 16, 32, 0, 0, 0, 0, 0 },
        [_]u32{ 16, 16, 32, 0, 0, 0, 0, 0, 0 },
        [_]u32{ 32, 32, 0, 0, 0, 0, 0, 0, 0 },
        [_]u32{ 64, 0, 0, 0, 0, 0, 0, 0, 0 },
    };
    const pool_bomb_idx_stages = [_]isize{ 7, 5, 4, 2, 1, -1, -1 };

    const bomb_from_idx = idx4(1, 1);
    const bomb_to_idx = idx4(1, 2);
    const bottom_period: f64 = 8.0;
    const bt = @as(f32, @floatCast(pageLoopTime(bottom_period)));
    const swap_start: f32 = 0.70;
    const swap_end: f32 = 1.10;
    const blast_end: f32 = 1.58;
    const reduce_end: f32 = 6.20;
    const fly_end: f32 = 7.00;
    const pool_tile_size: f32 = 22.0;
    const pool_gap: f32 = 3.0;

    if (bt < swap_start) {
        var hide = [_]bool{false} ** 16;
        drawMiniBoard4x4StateHidden(scene_x, bottom_y, tile_size, gap, &before_swap, &hide);
        const bomb_pos = miniGridTilePos(scene_x, bottom_y, 1, 1, tile_size, gap);
        drawMiniBomb(bomb_pos.x, bomb_pos.y, tile_size, 16);
    } else if (bt < swap_end) {
        const p = easeInOut01((bt - swap_start) / (swap_end - swap_start));
        var hide = [_]bool{false} ** 16;
        hide[bomb_from_idx] = true;
        hide[bomb_to_idx] = true;
        drawMiniBoard4x4StateHidden(scene_x, bottom_y, tile_size, gap, &before_swap, &hide);

        const from = miniGridTilePos(scene_x, bottom_y, 1, 1, tile_size, gap);
        const to = miniGridTilePos(scene_x, bottom_y, 2, 1, tile_size, gap);
        drawMiniBombScaledAlpha(lerpF32(from.x, to.x, p), lerpF32(from.y, to.y, p), tile_size, 1.0 + 0.05 * (1.0 - p), 1.0, 16);
        drawMiniTileScaled(
            lerpF32(to.x, from.x, p),
            lerpF32(to.y, from.y, p),
            tile_size,
            1.0 + 0.05 * (1.0 - p),
            2,
            miniTileColor(2),
            miniTileTextColor(2),
        );
    } else if (bt < blast_end) {
        const p = easeInOut01((bt - swap_end) / (blast_end - swap_end));
        drawMiniBoard4x4StateHidden(scene_x, bottom_y, tile_size, gap, &after_swap, &blast_mask);

        for (0..4) |r| {
            for (0..4) |c| {
                const idx = idx4(r, c);
                if (!blast_mask[idx]) continue;
                const pos = miniGridTilePos(scene_x, bottom_y, c, r, tile_size, gap);
                if (idx == bomb_to_idx) {
                    drawMiniBombScaledAlpha(pos.x, pos.y, tile_size, 1.0 + 0.20 * (1.0 - p), 1.0 - p, 16);
                } else {
                    drawMiniTileScaledAlpha(
                        pos.x,
                        pos.y,
                        tile_size,
                        1.0 + 0.20 * (1.0 - p),
                        1.0 - p,
                        after_swap[idx],
                        miniTileColor(after_swap[idx]),
                        miniTileTextColor(after_swap[idx]),
                    );
                }
            }
        }
    } else if (bt < reduce_end) {
        var hide = [_]bool{false} ** 16;
        drawMiniBoard4x4StateHidden(scene_x, bottom_y, tile_size, gap, &after_clear, &hide);

        const op_count = pool_stages.len - 1;
        const progress_total = std.math.clamp(
            (bt - blast_end) / (reduce_end - blast_end) * @as(f32, @floatFromInt(op_count)),
            0.0,
            @as(f32, @floatFromInt(op_count)) - 0.0001,
        );
        const op_idx = @as(usize, @intFromFloat(progress_total));
        const op_p = progress_total - @as(f32, @floatFromInt(op_idx));
        const pool_y = bottom_y + board_h + 8.0;
        drawBombPoolTransition(
            box,
            pool_y,
            pool_tile_size,
            pool_gap,
            pool_stages[op_idx],
            pool_stages[op_idx + 1],
            pool_bomb_idx_stages[op_idx],
            pool_bomb_idx_stages[op_idx + 1],
            op_p,
        );
    } else if (bt < fly_end) {
        const p = easeInOut01((bt - reduce_end) / (fly_end - reduce_end));
        var hide = [_]bool{false} ** 16;
        hide[bomb_to_idx] = true;
        drawMiniBoard4x4StateHidden(scene_x, bottom_y, tile_size, gap, &after_result, &hide);

        const pool_y = bottom_y + board_h + 8.0;
        const src_x = box.x + box.width / 2.0 - pool_tile_size / 2.0;
        const src_y = pool_y;
        const dst = miniGridTilePos(scene_x, bottom_y, 2, 1, tile_size, gap);
        drawMiniTileScaledAlpha(
            lerpF32(src_x, dst.x, p),
            lerpF32(src_y, dst.y, p),
            lerpF32(pool_tile_size, tile_size, p),
            1.0,
            1.0,
            64,
            miniTileColor(64),
            miniTileTextColor(64),
        );
    } else {
        var hide = [_]bool{false} ** 16;
        drawMiniBoard4x4StateHidden(scene_x, bottom_y, tile_size, gap, &after_result, &hide);
    }
}

fn drawShuffleIllustration(box: rl.Rectangle) void {
    const ink = rl.Color.init(119, 110, 101, 255);
    const tile_size: f32 = 28.0;
    const gap: f32 = 5.0;
    const board_w = tile_size * 4.0 + gap * 5.0;
    const board_x = box.x + (box.width - board_w) / 2.0;
    const board_y = box.y + 112.0;
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

    // Map each destination tile to a unique source tile with same value.
    var src_for_dst: [16]usize = undefined;
    var used_sources = [_]bool{false} ** 16;
    for (0..16) |dst| {
        const v = board_after[dst];
        var chosen: ?usize = null;

        if (!used_sources[dst] and board_before[dst] == v) {
            chosen = dst;
        } else {
            for (0..16) |src| {
                if (used_sources[src]) continue;
                if (board_before[src] != v) continue;
                chosen = src;
                break;
            }
        }

        const src_idx = chosen orelse dst;
        used_sources[src_idx] = true;
        src_for_dst[dst] = src_idx;
    }

    const period: f64 = 3;
    const t = @as(f32, @floatCast(pageLoopTime(period)));
    const move_start: f32 = 0.5;
    const move_end: f32 = 1.1;
    const p = if (t < move_start)
        0.0
    else if (t < move_end)
        easeInOut01((t - move_start) / (move_end - move_start))
    else
        1.0;

    drawMiniBoardBackdrop(board_x, board_y, 4, 4, tile_size, gap);

    for (0..16) |dst| {
        const src = src_for_dst[dst];
        const src_row = src / 4;
        const src_col = src % 4;
        const dst_row = dst / 4;
        const dst_col = dst % 4;
        const from = miniGridTilePos(board_x, board_y, src_col, src_row, tile_size, gap);
        const to = miniGridTilePos(board_x, board_y, dst_col, dst_row, tile_size, gap);
        const value = board_after[dst];
        const move_scale = if (t >= move_start and t < move_end) 1.0 + 0.04 * (1.0 - p) else 1.0;
        drawMiniTileScaled(
            lerpF32(from.x, to.x, p),
            lerpF32(from.y, to.y, p),
            tile_size,
            move_scale,
            value,
            miniTileColor(value),
            miniTileTextColor(value),
        );
    }

    rl.drawText(
        "Same tiles, new positions",
        centeredTextX(box, "Same tiles, new positions", 20),
        @as(i32, @intFromFloat(board_y + board_w + 10.0)),
        20,
        ink,
    );
}

fn drawScoringIllustration(box: rl.Rectangle) void {
    const ink = rl.Color.init(119, 110, 101, 255);
    const tile_size: f32 = 28.0;
    const gap: f32 = 5.0;
    const board_w = tile_size * 4.0 + gap * 5.0;
    const board_x = box.x + (box.width - board_w) / 2.0;
    const board_y = box.y + 120.0;

    const initial = [_]u32{
        8,  4, 8, 2,
        2,  4, 8, 2,
        16, 2, 4, 4,
        2,  4, 2, 2,
    };
    const after_swap = [_]u32{
        8,  4, 8, 2,
        2,  4, 8, 2,
        16, 4, 4, 4,
        2,  2, 2, 2,
    };
    const after_wave1_clear = [_]u32{
        8,  0,  8, 2,
        2,  0,  8, 2,
        16, 16, 0, 0,
        0,  8,  0, 0,
    };
    const after_fall1 = [_]u32{
        4,  4,  8, 4,
        8,  4,  4, 4,
        2,  16, 8, 2,
        16, 8,  8, 2,
    };
    const after_wave2_clear = [_]u32{
        4,  4,  8, 4,
        8,  0,  8, 0,
        2,  16, 8, 2,
        16, 8,  8, 2,
    };
    const after_fall2 = [_]u32{
        4,  4,  8, 4,
        8,  4,  8, 4,
        2,  16, 8, 2,
        16, 8,  8, 2,
    };
    const after_wave3_clear = [_]u32{
        4,  4,  0,  4,
        8,  4,  0,  4,
        2,  16, 32, 2,
        16, 8,  0,  2,
    };
    const after_fall3 = [_]u32{
        4,  4,  4,  4,
        8,  4,  16, 4,
        2,  16, 16, 2,
        16, 8,  32, 2,
    };
    const after_wave4_clear = [_]u32{
        0,  0,  16, 4,
        8,  4,  16, 4,
        2,  16, 16, 2,
        16, 8,  32, 2,
    };
    const after_fall4 = [_]u32{
        2,  4,  16, 4,
        8,  4,  16, 4,
        2,  16, 16, 2,
        16, 8,  32, 2,
    };
    const after_wave5_clear = [_]u32{
        2,  4,  0,  4,
        8,  4,  32, 4,
        2,  16, 0,  2,
        16, 8,  32, 2,
    };
    const after_fall5 = [_]u32{
        2,  4,  2,  4,
        8,  4,  8,  4,
        2,  16, 32, 2,
        16, 8,  32, 2,
    };

    const wave1_mask = [_]bool{
        false, true, false, false,
        false, true, false, false,
        false, true, true,  true,
        true,  true, true,  true,
    };
    const wave2_mask = [_]bool{
        false, false, false, false,
        false, true,  true,  true,
        false, false, false, false,
        false, false, false, false,
    };
    const wave3_mask = [_]bool{
        false, false, true, false,
        false, false, true, false,
        false, false, true, false,
        false, false, true, false,
    };
    const wave4_mask = [_]bool{
        true,  true,  true,  true,
        false, false, false, false,
        false, false, false, false,
        false, false, false, false,
    };
    const wave5_mask = [_]bool{
        false, false, true,  false,
        false, false, true,  false,
        false, false, true,  false,
        false, false, false, false,
    };

    const wave1_outcomes = [_]MiniOutcome{
        .{ .row = 2, .col = 1, .value = 16, .mult = 1 },
        .{ .row = 3, .col = 1, .value = 8, .mult = 1 },
    };
    const wave2_outcomes = [_]MiniOutcome{
        .{ .row = 1, .col = 2, .value = 8, .mult = 2 },
    };
    const wave3_outcomes = [_]MiniOutcome{
        .{ .row = 2, .col = 2, .value = 32, .mult = 2 },
    };
    const wave4_outcomes = [_]MiniOutcome{
        .{ .row = 0, .col = 2, .value = 16, .mult = 4 },
    };
    const wave5_outcomes = [_]MiniOutcome{
        .{ .row = 1, .col = 2, .value = 32, .mult = 4 },
    };

    const time_scale: f32 = 2.0;
    const match_dur: f32 = 0.13 * time_scale;
    const resolve_dur: f32 = 0.13 * time_scale;
    const fall_dur: f32 = 0.22 * time_scale;
    const score_pop_delay: f32 = 0.00;
    const score_pop_duration: f32 = 0.66;

    var phases: [20]MiniPhase = undefined;
    var phase_count: usize = 0;

    var swap_phase = initMiniPhase(.swap, 0.17 * time_scale, initial, "Swap");
    swap_phase.hide[idx4(2, 1)] = true;
    swap_phase.hide[idx4(3, 1)] = true;
    miniPhaseAddTrack(&swap_phase, initial[idx4(2, 1)], 2.0, 1.0, 3.0, 1.0);
    miniPhaseAddTrack(&swap_phase, initial[idx4(3, 1)], 3.0, 1.0, 2.0, 1.0);
    pushMiniPhase(phases[0..], &phase_count, swap_phase);

    pushMiniPhase(phases[0..], &phase_count, buildMiniMatchPhase(&after_swap, &wave1_mask, match_dur, "Wave 1: match"));
    pushMiniPhase(phases[0..], &phase_count, buildMiniResolvePhase(&after_swap, &wave1_mask, wave1_outcomes[0..], resolve_dur, "Wave 1: merge"));
    pushMiniPhase(phases[0..], &phase_count, buildMiniFallPhase(&after_wave1_clear, &after_fall1, fall_dur, "Wave 1: fall"));

    pushMiniPhase(phases[0..], &phase_count, buildMiniMatchPhase(&after_fall1, &wave2_mask, match_dur, "Wave 2: match"));
    pushMiniPhase(phases[0..], &phase_count, buildMiniResolvePhase(&after_fall1, &wave2_mask, wave2_outcomes[0..], resolve_dur, "Wave 2: merge"));
    pushMiniPhase(phases[0..], &phase_count, buildMiniFallPhase(&after_wave2_clear, &after_fall2, fall_dur, "Wave 2: fall"));

    pushMiniPhase(phases[0..], &phase_count, buildMiniMatchPhase(&after_fall2, &wave3_mask, match_dur, "Wave 3: match"));
    pushMiniPhase(phases[0..], &phase_count, buildMiniResolvePhase(&after_fall2, &wave3_mask, wave3_outcomes[0..], resolve_dur, "Wave 3: merge"));
    pushMiniPhase(phases[0..], &phase_count, buildMiniFallPhase(&after_wave3_clear, &after_fall3, fall_dur, "Wave 3: fall"));

    pushMiniPhase(phases[0..], &phase_count, buildMiniMatchPhase(&after_fall3, &wave4_mask, match_dur, "Wave 4: match"));
    pushMiniPhase(phases[0..], &phase_count, buildMiniResolvePhase(&after_fall3, &wave4_mask, wave4_outcomes[0..], resolve_dur, "Wave 4: merge"));
    pushMiniPhase(phases[0..], &phase_count, buildMiniFallPhase(&after_wave4_clear, &after_fall4, fall_dur, "Wave 4: fall"));

    pushMiniPhase(phases[0..], &phase_count, buildMiniMatchPhase(&after_fall4, &wave5_mask, match_dur, "Wave 5: match"));
    pushMiniPhase(phases[0..], &phase_count, buildMiniResolvePhase(&after_fall4, &wave5_mask, wave5_outcomes[0..], resolve_dur, "Wave 5: merge"));
    pushMiniPhase(phases[0..], &phase_count, buildMiniFallPhase(&after_wave5_clear, &after_fall5, fall_dur, "Wave 5: fall"));
    pushMiniPhase(phases[0..], &phase_count, initMiniPhase(.fall_spawn, 0.90 * time_scale, after_fall5, "Result + pause"));

    var period: f32 = 0.0;
    for (phases[0..phase_count]) |ph| period += ph.duration;
    const t = @as(f32, @floatCast(pageLoopTime(@as(f64, @floatCast(period)))));

    var active_idx: usize = phase_count - 1;
    var phase_start: f32 = 0.0;
    var cursor: f32 = 0.0;
    for (phases[0..phase_count], 0..) |ph, i| {
        const phase_end = cursor + ph.duration;
        if (t < phase_end) {
            active_idx = i;
            phase_start = cursor;
            break;
        }
        cursor = phase_end;
    }

    const active = phases[active_idx];
    const progress = if (active.duration > 0.0001)
        std.math.clamp((t - phase_start) / active.duration, 0.0, 1.0)
    else
        1.0;

    var shown_score: u64 = 0;
    for (phases[0..phase_count], 0..) |ph, i| {
        if (i >= active_idx) break;
        shown_score += miniPhaseScoreTotal(&ph);
    }
    const active_elapsed = t - phase_start;
    if (active.score_pop_count > 0 and active_elapsed >= score_pop_delay) {
        shown_score += miniPhaseScoreTotal(&active);
    }

    var score_buf: [48]u8 = undefined;
    const score_txt = std.fmt.bufPrintZ(&score_buf, "Score: {d}", .{shown_score}) catch "Scores: 0";
    const score_fs: i32 = 20;
    const score_x_nudge: i32 = 48;
    rl.drawText(
        score_txt,
        centeredTextX(box, score_txt, score_fs) + score_x_nudge,
        @as(i32, @intFromFloat(box.y + 80.0)),
        score_fs,
        ink,
    );

    drawMiniPhase(board_x, board_y, tile_size, gap, &active, progress);

    // Render score pops on an independent local timer parallel to tile phases.
    var score_cursor: f32 = 0.0;
    for (phases[0..phase_count]) |ph| {
        if (ph.score_pop_count == 0) {
            score_cursor += ph.duration;
            continue;
        }
        var elapsed = t - score_cursor;
        if (elapsed < 0.0) elapsed += period;
        if (elapsed >= score_pop_delay and elapsed <= score_pop_delay + score_pop_duration) {
            const pop_t = (elapsed - score_pop_delay) / score_pop_duration;
            drawMiniPhaseScorePops(board_x, board_y, tile_size, gap, &ph, pop_t);
        }
        score_cursor += ph.duration;
    }
}

fn miniPhaseScoreTotal(phase: *const MiniPhase) u64 {
    var out: u64 = 0;
    for (0..phase.score_pop_count) |i| {
        const pop = phase.score_pops[i];
        out += @as(u64, pop.value) * @as(u64, @max(pop.mult, 1));
    }
    return out;
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
    drawMiniBombAlpha(x, y, size, value, 1.0);
}

fn drawMiniBombAlpha(x: f32, y: f32, size: f32, value: u32, alpha: f32) void {
    const rect = rl.Rectangle{ .x = x, .y = y, .width = size, .height = size };
    rl.drawRectangleRec(rect, colorWithAlpha(rl.Color.init(142, 74, 74, 255), alpha));
    rl.drawRectangleLinesEx(rect, 1.0, colorWithAlpha(rl.Color.init(205, 193, 180, 255), alpha));
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
        colorWithAlpha(rl.Color.init(249, 246, 242, 255), alpha),
    );
}

fn drawMiniBombScaledAlpha(
    x: f32,
    y: f32,
    size: f32,
    scale: f32,
    alpha: f32,
    value: u32,
) void {
    const scaled = size * scale;
    const ox = (size - scaled) / 2.0;
    const oy = (size - scaled) / 2.0;
    drawMiniBombAlpha(x + ox, y + oy, scaled, value, alpha);
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

fn drawBombPoolStage(
    box: rl.Rectangle,
    y: f32,
    tile_size: f32,
    gap: f32,
    values: [9]u32,
    bomb_idx: isize,
) void {
    var compact: [9]u32 = undefined;
    const count = compactPoolValues(values, &compact);
    if (count == 0) return;

    const width = tile_size * @as(f32, @floatFromInt(count)) + gap * (@as(f32, @floatFromInt(count)) - 1.0);
    var x = box.x + (box.width - width) / 2.0;

    for (0..count) |i| {
        const v = compact[i];
        drawPoolTileMaybeBomb(x, y, tile_size, 1.0, 1.0, v, isPoolBombIndex(bomb_idx, i));
        x += tile_size + gap;
    }
}

fn drawBombPoolTransition(
    box: rl.Rectangle,
    y: f32,
    tile_size: f32,
    gap: f32,
    from_values: [9]u32,
    to_values: [9]u32,
    from_bomb_idx: isize,
    to_bomb_idx: isize,
    progress_01: f32,
) void {
    var from_compact: [9]u32 = undefined;
    var to_compact: [9]u32 = undefined;
    const from_count = compactPoolValues(from_values, &from_compact);
    const to_count = compactPoolValues(to_values, &to_compact);
    if (from_count == 0 or to_count == 0) return;

    var src_to_dst = [_]isize{-1} ** 9;
    var dst_src_a = [_]isize{-1} ** 9;
    var dst_src_b = [_]isize{-1} ** 9;
    const solved = solvePoolTransitionMapping(
        from_compact[0..from_count],
        to_compact[0..to_count],
        &src_to_dst,
        &dst_src_a,
        &dst_src_b,
    );
    if (!solved) {
        drawBombPoolStage(box, y, tile_size, gap, to_values, to_bomb_idx);
        return;
    }

    const from_w = tile_size * @as(f32, @floatFromInt(from_count)) + gap * (@as(f32, @floatFromInt(from_count)) - 1.0);
    const to_w = tile_size * @as(f32, @floatFromInt(to_count)) + gap * (@as(f32, @floatFromInt(to_count)) - 1.0);
    const start_x_from = box.x + (box.width - from_w) / 2.0;
    const start_x_to = box.x + (box.width - to_w) / 2.0;
    const step = tile_size + gap;
    const p = easeInOut01(progress_01);
    const merge_move = easeInOut01(std.math.clamp(p / 0.74, 0.0, 1.0));
    const merge_src_alpha = 1.0 - std.math.clamp((p - 0.42) / 0.34, 0.0, 1.0);
    const merge_out_alpha = std.math.clamp((p - 0.36) / 0.34, 0.0, 1.0);
    const merge_settle = easeInOut01(std.math.clamp((p - 0.68) / 0.32, 0.0, 1.0));

    for (0..from_count) |i| {
        const dst = src_to_dst[i];
        if (dst < 0) {
            const fade = std.math.clamp((p - 0.20) / 0.50, 0.0, 1.0);
            const x_from = start_x_from + @as(f32, @floatFromInt(i)) * step;
            const v = from_compact[i];
            drawPoolTileMaybeBomb(
                x_from,
                y - 5.0 * fade,
                tile_size,
                1.0 - 0.03 * fade,
                1.0 - fade,
                v,
                isPoolBombIndex(from_bomb_idx, i),
            );
            continue;
        }

        const dst_u = @as(usize, @intCast(dst));
        if (dst_src_b[dst_u] >= 0) continue;

        const x_from = start_x_from + @as(f32, @floatFromInt(i)) * step;
        const x_to = start_x_to + @as(f32, @floatFromInt(dst_u)) * step;
        const v = from_compact[i];
        drawPoolTileMaybeBomb(
            lerpF32(x_from, x_to, p),
            y,
            tile_size,
            1.0,
            1.0,
            v,
            (isPoolBombIndex(from_bomb_idx, i) or isPoolBombIndex(to_bomb_idx, dst_u)),
        );
    }

    for (0..to_count) |j| {
        const src_a = dst_src_a[j];
        const src_b = dst_src_b[j];
        if (src_a < 0 or src_b < 0) continue;

        const ia = @as(usize, @intCast(src_a));
        const ib = @as(usize, @intCast(src_b));
        const x_to = start_x_to + @as(f32, @floatFromInt(j)) * step;
        const x_a = lerpF32(start_x_from + @as(f32, @floatFromInt(ia)) * step, x_to, merge_move);
        const x_b = lerpF32(start_x_from + @as(f32, @floatFromInt(ib)) * step, x_to, merge_move);

        drawPoolTileMaybeBomb(
            x_a,
            y,
            tile_size,
            1.0,
            merge_src_alpha,
            from_compact[ia],
            isPoolBombIndex(from_bomb_idx, ia),
        );
        drawPoolTileMaybeBomb(
            x_b,
            y,
            tile_size,
            1.0,
            merge_src_alpha,
            from_compact[ib],
            isPoolBombIndex(from_bomb_idx, ib),
        );
        drawPoolTileMaybeBomb(
            x_to,
            y,
            tile_size,
            1.08 - 0.08 * merge_settle,
            merge_out_alpha,
            to_compact[j],
            isPoolBombIndex(to_bomb_idx, j),
        );
    }
}

fn compactPoolValues(values: [9]u32, out: *[9]u32) usize {
    var count: usize = 0;
    for (values) |v| {
        if (v == 0) continue;
        out[count] = v;
        count += 1;
    }
    return count;
}

fn solvePoolTransitionMapping(
    from: []const u32,
    to: []const u32,
    src_to_dst: *[9]isize,
    dst_src_a: *[9]isize,
    dst_src_b: *[9]isize,
) bool {
    src_to_dst.* = [_]isize{-1} ** 9;
    dst_src_a.* = [_]isize{-1} ** 9;
    dst_src_b.* = [_]isize{-1} ** 9;
    return solvePoolTransitionMappingRec(from, to, 0, 0, src_to_dst, dst_src_a, dst_src_b);
}

fn solvePoolTransitionMappingRec(
    from: []const u32,
    to: []const u32,
    i: usize,
    j: usize,
    src_to_dst: *[9]isize,
    dst_src_a: *[9]isize,
    dst_src_b: *[9]isize,
) bool {
    if (i == from.len and j == to.len) return true;
    if (j == to.len) {
        for (i..from.len) |k| src_to_dst[k] = -1;
        return true;
    }
    if (i >= from.len) return false;

    if (from[i] == to[j]) {
        const src_backup = src_to_dst.*;
        const dst_a_backup = dst_src_a.*;
        const dst_b_backup = dst_src_b.*;

        src_to_dst[i] = @as(isize, @intCast(j));
        dst_src_a[j] = @as(isize, @intCast(i));
        dst_src_b[j] = -1;
        if (solvePoolTransitionMappingRec(from, to, i + 1, j + 1, src_to_dst, dst_src_a, dst_src_b)) return true;

        src_to_dst.* = src_backup;
        dst_src_a.* = dst_a_backup;
        dst_src_b.* = dst_b_backup;
    }

    if (i + 1 < from.len and from[i] == from[i + 1] and from[i] *| 2 == to[j]) {
        const src_backup = src_to_dst.*;
        const dst_a_backup = dst_src_a.*;
        const dst_b_backup = dst_src_b.*;

        src_to_dst[i] = @as(isize, @intCast(j));
        src_to_dst[i + 1] = @as(isize, @intCast(j));
        dst_src_a[j] = @as(isize, @intCast(i));
        dst_src_b[j] = @as(isize, @intCast(i + 1));
        if (solvePoolTransitionMappingRec(from, to, i + 2, j + 1, src_to_dst, dst_src_a, dst_src_b)) return true;

        src_to_dst.* = src_backup;
        dst_src_a.* = dst_a_backup;
        dst_src_b.* = dst_b_backup;
    }

    {
        const src_backup = src_to_dst.*;
        const dst_a_backup = dst_src_a.*;
        const dst_b_backup = dst_src_b.*;

        src_to_dst[i] = -1;
        if (solvePoolTransitionMappingRec(from, to, i + 1, j, src_to_dst, dst_src_a, dst_src_b)) return true;

        src_to_dst.* = src_backup;
        dst_src_a.* = dst_a_backup;
        dst_src_b.* = dst_b_backup;
    }

    return false;
}

fn isPoolBombIndex(bomb_idx: isize, idx: usize) bool {
    return bomb_idx >= 0 and @as(usize, @intCast(bomb_idx)) == idx;
}

fn drawPoolTileMaybeBomb(
    x: f32,
    y: f32,
    tile_size: f32,
    scale: f32,
    alpha: f32,
    value: u32,
    bomb: bool,
) void {
    if (alpha <= 0.001) return;
    if (bomb and value == 16) {
        drawMiniBombScaledAlpha(x, y, tile_size, scale, alpha, value);
    } else {
        drawMiniTileScaledAlpha(x, y, tile_size, scale, alpha, value, miniTileColor(value), miniTileTextColor(value));
    }
}

fn drawMiniBoard4x4State(x: f32, y: f32, tile_size: f32, gap: f32, values: *const [16]u32) void {
    var hide = [_]bool{false} ** 16;
    drawMiniBoard4x4StateHidden(x, y, tile_size, gap, values, &hide);
}

fn drawMiniBoard4x4StateHidden(
    x: f32,
    y: f32,
    tile_size: f32,
    gap: f32,
    values: *const [16]u32,
    hide: *const [16]bool,
) void {
    drawMiniBoardBackdrop(x, y, 4, 4, tile_size, gap);
    for (0..4) |r| {
        for (0..4) |c| {
            const idx = idx4(r, c);
            if (hide[idx]) continue;
            const v = values[idx];
            if (v == 0) continue;
            const p = miniGridTilePos(x, y, c, r, tile_size, gap);
            drawMiniTile(p.x, p.y, tile_size, v, miniTileColor(v), miniTileTextColor(v));
        }
    }
}

fn drawWaveFlashRow(
    x: f32,
    y: f32,
    tile_size: f32,
    gap: f32,
    row: usize,
    col_start: usize,
    count: usize,
    value: u32,
    progress: f32,
) void {
    const scale = 1.0 + 0.22 * (1.0 - progress);
    const alpha = 1.0 - progress;
    for (0..count) |i| {
        const col = col_start + i;
        const p = miniGridTilePos(x, y, col, row, tile_size, gap);
        drawMiniTileScaledAlpha(
            p.x,
            p.y,
            tile_size,
            scale,
            alpha,
            value,
            miniTileColor(value),
            miniTileTextColor(value),
        );
    }
}

fn idx4(row: usize, col: usize) usize {
    return row * 4 + col;
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
