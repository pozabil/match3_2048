const std = @import("std");
const rl = @import("raylib");
const types = @import("../core/types.zig");
const animations = @import("animations.zig");

pub const tile_size: i32 = 68;
pub const tile_gap: i32 = 8;
pub const board_px: i32 = @as(i32, @intCast(types.BOARD_COLS)) * tile_size +
    (@as(i32, @intCast(types.BOARD_COLS)) + 1) * tile_gap;
pub const board_x: i32 = (900 - board_px) / 2;
pub const board_y: i32 = 132;

pub fn drawBoard(state: *const types.GameState, selected: ?types.Position, anim: *const animations.AnimationState) void {
    const shake = @as(i32, @intFromFloat(std.math.sin(anim.clock * 45.0) * 5.0 * anim.invalid_pulse));
    const panel_x = board_x + shake;

    rl.drawRectangle(panel_x, board_y, board_px, board_px, rl.Color.init(187, 173, 160, 255));

    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            const base_x = panel_x + tile_gap + @as(i32, @intCast(c)) * (tile_size + tile_gap);
            const base_y = board_y + tile_gap + @as(i32, @intCast(r)) * (tile_size + tile_gap);

            rl.drawRectangle(base_x, base_y, tile_size, tile_size, rl.Color.init(205, 193, 180, 255));

            if (state.board[r][c]) |tile| {
                const scale = anim.tileScale(r, c);
                const scaled = @as(i32, @intFromFloat(@as(f32, @floatFromInt(tile_size)) * scale));
                const ox = @divTrunc(tile_size - scaled, 2);
                const oy = @divTrunc(tile_size - scaled, 2);
                const x = base_x + ox;
                const y = base_y + oy;

                const fill = if (tile.kind == .bomb) bombColor() else tileColor(tile.value);
                rl.drawRectangle(x, y, scaled, scaled, fill);

                if (tile.kind == .bomb) {
                    rl.drawText("B", x + @divTrunc(scaled, 2) - 8, y + @divTrunc(scaled, 2) - 12, 24, rl.Color.init(249, 246, 242, 255));
                } else {
                    var txt: [24]u8 = undefined;
                    const s = std.fmt.bufPrintZ(&txt, "{d}", .{tile.value}) catch "?";
                    const fs = tileFontSize(tile.value);
                    const tw = rl.measureText(s, fs);
                    const tx = x + @divTrunc(scaled - tw, 2);
                    const ty = y + @divTrunc(scaled - fs, 2) - 1;
                    rl.drawText(s, tx, ty, fs, tileTextColor(tile.value));
                }
            }

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
