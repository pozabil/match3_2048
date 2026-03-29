const std = @import("std");
const rl = @import("raylib");
const config = @import("../core/config.zig");
const types = @import("../core/types.zig");
const animations = @import("animations.zig");

pub const tile_size: i32 = 68;
pub const tile_gap: i32 = 8;
pub const board_px: i32 = @as(i32, @intCast(types.BOARD_COLS)) * tile_size +
    (@as(i32, @intCast(types.BOARD_COLS)) + 1) * tile_gap;
pub const board_x: i32 = (config.window_width - board_px) / 2;
pub const board_y: i32 = 92;

pub fn drawBoard(state: *const types.GameState, selected: ?types.Position, anim: *const animations.AnimationState) void {
    const shake = @as(i32, @intFromFloat(std.math.sin(anim.clock * 45.0) * 5.0 * anim.invalid_pulse));
    const panel_x = board_x + shake;
    const phase = anim.currentPhase();
    const board_ref: *const types.Board = if (phase) |p| &p.base_board else &state.board;

    rl.drawRectangle(panel_x, board_y, board_px, board_px, rl.Color.init(187, 173, 160, 255));

    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            const base_x = panel_x + tile_gap + @as(i32, @intCast(c)) * (tile_size + tile_gap);
            const base_y = board_y + tile_gap + @as(i32, @intCast(r)) * (tile_size + tile_gap);

            rl.drawRectangle(base_x, base_y, tile_size, tile_size, rl.Color.init(205, 193, 180, 255));

            if (phase != null and phase.?.hide_mask[r][c]) {
                // Animated track will render this tile.
            } else if (board_ref.*[r][c]) |tile| {
                const scale = anim.tileScale(r, c);
                drawTileAtCell(panel_x, @as(f32, @floatFromInt(r)), @as(f32, @floatFromInt(c)), tile, scale, 1.0);
            }

            if (!anim.isPresenting()) {
                if (selected) |p| {
                    if (p.row == r and p.col == c) {
                        rl.drawRectangleLinesEx(
                            .{
                                .x = @as(f32, @floatFromInt(base_x - 1)),
                                .y = @as(f32, @floatFromInt(base_y - 1)),
                                .width = @as(f32, @floatFromInt(tile_size + 2)),
                                .height = @as(f32, @floatFromInt(tile_size + 2)),
                            },
                            3.0,
                            rl.Color.init(249, 246, 242, 255),
                        );
                    }
                }
            }
        }
    }

    if (phase) |p| {
        const progress = easeInOut(anim.phaseProgress());
        for (0..p.track_count) |i| {
            const track = p.tracks[i];

            var row = lerp(track.from_row, track.to_row, progress);
            var col = lerp(track.from_col, track.to_col, progress);
            var scale: f32 = 1.0;
            var alpha: f32 = 1.0;

            switch (p.kind) {
                .swap => {
                    scale = 1.0 + 0.05 * (1.0 - progress);
                },
                .match_flash => {
                    row = track.to_row;
                    col = track.to_col;
                    scale = 1.0 + 0.22 * (1.0 - progress);
                    alpha = 1.0 - progress;
                },
                .fall_spawn => {
                    scale = 1.0;
                },
            }

            drawTileAtCell(panel_x, row, col, track.tile, scale, alpha);
        }
    }
}

pub fn mouseToCell(mouse_x: i32, mouse_y: i32) ?types.Position {
    if (mouse_x < board_x + tile_gap or mouse_y < board_y + tile_gap) return null;

    const rel_x = mouse_x - (board_x + tile_gap);
    const rel_y = mouse_y - (board_y + tile_gap);
    if (rel_x < 0 or rel_y < 0) return null;

    const step = tile_size + tile_gap;
    const col_i = @divFloor(rel_x, step);
    const row_i = @divFloor(rel_y, step);

    if (col_i < 0 or row_i < 0) return null;
    if (col_i >= @as(i32, @intCast(types.BOARD_COLS)) or row_i >= @as(i32, @intCast(types.BOARD_ROWS))) return null;

    const in_cell_x = @mod(rel_x, step);
    const in_cell_y = @mod(rel_y, step);
    if (in_cell_x >= tile_size or in_cell_y >= tile_size) return null;

    return .{
        .row = @as(usize, @intCast(row_i)),
        .col = @as(usize, @intCast(col_i)),
    };
}

fn tileColor(value: u32) rl.Color {
    return switch (value) {
        2 => rl.Color.init(238, 228, 218, 255),
        4 => rl.Color.init(237, 224, 200, 255),
        8 => rl.Color.init(242, 177, 121, 255),
        16 => rl.Color.init(245, 149, 99, 255),
        32 => rl.Color.init(246, 124, 95, 255),
        64 => rl.Color.init(246, 94, 59, 255),
        128 => rl.Color.init(237, 207, 114, 255),
        256 => rl.Color.init(237, 204, 97, 255),
        512 => rl.Color.init(237, 200, 80, 255),
        1024 => rl.Color.init(237, 197, 63, 255),
        2048 => rl.Color.init(237, 194, 46, 255),
        else => rl.Color.init(161, 136, 127, 255),
    };
}

fn drawTileAtCell(panel_x: i32, row: f32, col: f32, tile: types.Tile, scale: f32, alpha: f32) void {
    const step = @as(f32, @floatFromInt(tile_size + tile_gap));
    const cell_x = @as(f32, @floatFromInt(panel_x + tile_gap)) + col * step;
    const cell_y = @as(f32, @floatFromInt(board_y + tile_gap)) + row * step;

    const scaled = @as(i32, @intFromFloat(@as(f32, @floatFromInt(tile_size)) * scale));
    const ox = @divTrunc(tile_size - scaled, 2);
    const oy = @divTrunc(tile_size - scaled, 2);
    const x = @as(i32, @intFromFloat(cell_x)) + ox;
    const y = @as(i32, @intFromFloat(cell_y)) + oy;

    const fill_base = if (tile.kind == .bomb) bombColor() else tileColor(tile.value);
    const fill = colorWithAlpha(fill_base, alpha);
    rl.drawRectangle(x, y, scaled, scaled, fill);

    if (tile.kind == .bomb) {
        var bomb_txt: [32]u8 = undefined;
        const s = std.fmt.bufPrintZ(&bomb_txt, "B{d}", .{tile.value}) catch "B?";
        const fs = bombFontSize(tile.value);
        const tw = rl.measureText(s, fs);
        const tx = x + @divTrunc(scaled - tw, 2);
        const ty = y + @divTrunc(scaled - fs, 2) - 1;
        rl.drawText(s, tx, ty, fs, colorWithAlpha(rl.Color.init(249, 246, 242, 255), alpha));
        return;
    }

    var txt: [24]u8 = undefined;
    const s = std.fmt.bufPrintZ(&txt, "{d}", .{tile.value}) catch "?";
    const fs = tileFontSize(tile.value);
    const tw = rl.measureText(s, fs);
    const tx = x + @divTrunc(scaled - tw, 2);
    const ty = y + @divTrunc(scaled - fs, 2) - 1;
    rl.drawText(s, tx, ty, fs, colorWithAlpha(tileTextColor(tile.value), alpha));
}

fn colorWithAlpha(color: rl.Color, alpha: f32) rl.Color {
    const a = @as(i32, @intFromFloat(@as(f32, @floatFromInt(color.a)) * std.math.clamp(alpha, 0.0, 1.0)));
    return rl.Color.init(color.r, color.g, color.b, @as(u8, @intCast(std.math.clamp(a, 0, 255))));
}

fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

fn easeInOut(t: f32) f32 {
    const clamped = std.math.clamp(t, 0.0, 1.0);
    return clamped * clamped * (3.0 - 2.0 * clamped);
}

fn tileTextColor(value: u32) rl.Color {
    return if (value <= 4) rl.Color.init(119, 110, 101, 255) else rl.Color.init(249, 246, 242, 255);
}

fn tileFontSize(value: u32) i32 {
    if (value < 100) return 28;
    if (value < 1000) return 24;
    if (value < 10000) return 20;
    return 16;
}

fn bombColor() rl.Color {
    return rl.Color.init(142, 74, 74, 255);
}

fn bombFontSize(value: u32) i32 {
    if (value < 100) return 22;
    if (value < 1000) return 18;
    return 16;
}
