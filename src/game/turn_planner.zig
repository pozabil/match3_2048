const std = @import("std");
const types = @import("../core/types.zig");
const utils = @import("../core/utils.zig");
const match_lines = @import("../core/match_lines.zig");
const engine = @import("../core/engine.zig");
const animations = @import("../ui/animations.zig");

const SWAP_DURATION: f32 = 0.17;
const MATCH_DURATION: f32 = 0.13;
const FALL_DURATION: f32 = 0.22;

pub fn planPlayerTurn(
    base_state: *const types.GameState,
    allocator: std.mem.Allocator,
    rng: std.Random,
    from: types.Position,
    to: types.Position,
    anim: *animations.AnimationState,
) !types.GameState {
    anim.clearPresentation();

    var work = base_state.*;

    if (work.status != .running) return error.GameAlreadyEnded;
    if (!utils.isAdjacent(from, to)) return error.NotAdjacent;

    const from_tile = work.board[from.row][from.col] orelse return error.EmptySource;
    const to_tile = work.board[to.row][to.col] orelse return error.EmptyTarget;

    try appendSwapPhase(anim, &work.board, from, to, from_tile, to_tile);
    utils.swap(&work.board, from, to);

    if (from_tile.kind == .bomb or to_tile.kind == .bomb) {
        const bomb_pos = if ((work.board[to.row][to.col] orelse types.Tile.number(0)).kind == .bomb) to else from;

        var blast_mask = emptyMask();
        markBombArea(&blast_mask, bomb_pos);
        try appendMatchPhase(anim, &work.board, &blast_mask);

        const before_explosion = work.board;
        try engine.explodeBombAt(&work, allocator, rng, bomb_pos);
        try appendFallPhase(anim, &before_explosion, &work.board, &blast_mask);

        work.stats.moves += 1;
        try appendCascadePhases(&work, allocator, rng, .{ .source = .auto }, anim);
        try engine.enforcePostMoveState(&work, allocator, rng);
        return work;
    }

    if (!match_lines.hasAnyLineMatch(&work.board)) {
        anim.clearPresentation();
        return error.InvalidMoveNoMatch;
    }

    work.stats.moves += 1;
    try appendCascadePhases(&work, allocator, rng, .{
        .source = .player,
        .player_from = from,
        .player_to = to,
    }, anim);
    try engine.enforcePostMoveState(&work, allocator, rng);
    return work;
}

fn appendCascadePhases(
    work: *types.GameState,
    allocator: std.mem.Allocator,
    rng: std.Random,
    first_source: engine.ResolveSource,
    anim: *animations.AnimationState,
) !void {
    var source = first_source;

    while (match_lines.hasAnyLineMatch(&work.board)) {
        const before = work.board;

        var mask = try lineMask(allocator, &before);
        _ = &mask;
        try appendMatchPhase(anim, &before, &mask);

        var one = work.*;
        const cap = one.cfg.max_cascade_waves;
        one.cfg.max_cascade_waves = 1;
        try engine.resolveCascade(&one, allocator, rng, source);
        one.cfg.max_cascade_waves = cap;

        try appendFallPhase(anim, &before, &one.board, &mask);

        work.* = one;
        source = .{ .source = .auto };

        if (work.status != .running) break;
    }
}

fn appendSwapPhase(
    anim: *animations.AnimationState,
    board: *const types.Board,
    from: types.Position,
    to: types.Position,
    from_tile: types.Tile,
    to_tile: types.Tile,
) !void {
    var phase = animations.Phase.init(.swap, SWAP_DURATION, board.*);
    phase.hide_mask[from.row][from.col] = true;
    phase.hide_mask[to.row][to.col] = true;

    try phase.addTrack(.{
        .tile = from_tile,
        .from_row = @as(f32, @floatFromInt(from.row)),
        .from_col = @as(f32, @floatFromInt(from.col)),
        .to_row = @as(f32, @floatFromInt(to.row)),
        .to_col = @as(f32, @floatFromInt(to.col)),
    });
    try phase.addTrack(.{
        .tile = to_tile,
        .from_row = @as(f32, @floatFromInt(to.row)),
        .from_col = @as(f32, @floatFromInt(to.col)),
        .to_row = @as(f32, @floatFromInt(from.row)),
        .to_col = @as(f32, @floatFromInt(from.col)),
    });

    try anim.appendPhase(phase);
}

fn appendMatchPhase(anim: *animations.AnimationState, board: *const types.Board, mask: *const [types.BOARD_ROWS][types.BOARD_COLS]bool) !void {
    var phase = animations.Phase.init(.match_flash, MATCH_DURATION, board.*);

    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            if (!mask[r][c]) continue;
            const tile = board[r][c] orelse continue;

            phase.hide_mask[r][c] = true;
            try phase.addTrack(.{
                .tile = tile,
                .from_row = @as(f32, @floatFromInt(r)),
                .from_col = @as(f32, @floatFromInt(c)),
                .to_row = @as(f32, @floatFromInt(r)),
                .to_col = @as(f32, @floatFromInt(c)),
            });
        }
    }

    if (phase.track_count > 0) {
        try anim.appendPhase(phase);
    }
}

fn appendFallPhase(
    anim: *animations.AnimationState,
    before: *const types.Board,
    after: *const types.Board,
    consumed_mask: *const [types.BOARD_ROWS][types.BOARD_COLS]bool,
) !void {
    var phase = animations.Phase.init(.fall_spawn, FALL_DURATION, after.*);

    for (0..types.BOARD_COLS) |c| {
        var used_src: [types.BOARD_ROWS]bool = undefined;
        for (0..types.BOARD_ROWS) |r| used_src[r] = false;

        var rr: isize = @as(isize, @intCast(types.BOARD_ROWS - 1));
        while (rr >= 0) : (rr -= 1) {
            const r: usize = @intCast(rr);
            const dst_tile = after[r][c] orelse continue;

            if (findSourceRow(before, c, r, dst_tile, &used_src, consumed_mask)) |src_row| {
                used_src[src_row] = true;
                if (src_row != r) {
                    phase.hide_mask[r][c] = true;
                    try phase.addTrack(.{
                        .tile = dst_tile,
                        .from_row = @as(f32, @floatFromInt(src_row)),
                        .from_col = @as(f32, @floatFromInt(c)),
                        .to_row = @as(f32, @floatFromInt(r)),
                        .to_col = @as(f32, @floatFromInt(c)),
                    });
                }
            } else {
                const from_row = if (findAnchorRow(before, consumed_mask, c, r)) |anchor_row|
                    @as(f32, @floatFromInt(anchor_row))
                else
                    -1.2;
                phase.hide_mask[r][c] = true;
                try phase.addTrack(.{
                    .tile = dst_tile,
                    .from_row = from_row,
                    .from_col = @as(f32, @floatFromInt(c)),
                    .to_row = @as(f32, @floatFromInt(r)),
                    .to_col = @as(f32, @floatFromInt(c)),
                });
            }
        }
    }

    if (phase.track_count > 0) {
        try anim.appendPhase(phase);
    }
}

fn findSourceRow(
    before: *const types.Board,
    col: usize,
    dst_row: usize,
    dst_tile: types.Tile,
    used_src: *[types.BOARD_ROWS]bool,
    consumed_mask: *const [types.BOARD_ROWS][types.BOARD_COLS]bool,
) ?usize {
    var rr: isize = @as(isize, @intCast(types.BOARD_ROWS - 1));
    while (rr >= 0) : (rr -= 1) {
        const r: usize = @intCast(rr);
        if (used_src[r]) continue;
        if (consumed_mask[r][col]) continue;
        const src_tile = before[r][col] orelse continue;
        if (!sameTile(src_tile, dst_tile)) continue;
        if (r <= dst_row) return r;
    }

    return null;
}

fn findAnchorRow(
    before: *const types.Board,
    consumed_mask: *const [types.BOARD_ROWS][types.BOARD_COLS]bool,
    col: usize,
    dst_row: usize,
) ?usize {
    var rr: isize = @as(isize, @intCast(dst_row));
    while (rr >= 0) : (rr -= 1) {
        const r: usize = @intCast(rr);
        if (!consumed_mask[r][col]) continue;
        if (before[r][col] == null) continue;
        return r;
    }
    return null;
}

fn sameTile(a: types.Tile, b: types.Tile) bool {
    if (a.id != 0 and b.id != 0) {
        return a.id == b.id;
    }
    return a.kind == b.kind and a.value == b.value;
}

fn lineMask(allocator: std.mem.Allocator, board: *const types.Board) ![types.BOARD_ROWS][types.BOARD_COLS]bool {
    var out = emptyMask();

    var lines = try match_lines.findLineMatches(allocator, board);
    defer lines.deinit(allocator);

    for (lines.items) |m| {
        for (0..m.len) |i| {
            const p = m.positions[i];
            out[p.row][p.col] = true;
        }
    }

    return out;
}

fn markBombArea(mask: *[types.BOARD_ROWS][types.BOARD_COLS]bool, origin: types.Position) void {
    const row_start = if (origin.row == 0) 0 else origin.row - 1;
    const row_end = if (origin.row + 1 >= types.BOARD_ROWS) types.BOARD_ROWS - 1 else origin.row + 1;
    const col_start = if (origin.col == 0) 0 else origin.col - 1;
    const col_end = if (origin.col + 1 >= types.BOARD_COLS) types.BOARD_COLS - 1 else origin.col + 1;

    for (row_start..row_end + 1) |r| {
        for (col_start..col_end + 1) |c| {
            mask[r][c] = true;
        }
    }
}

fn emptyMask() [types.BOARD_ROWS][types.BOARD_COLS]bool {
    var out: [types.BOARD_ROWS][types.BOARD_COLS]bool = undefined;
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            out[r][c] = false;
        }
    }
    return out;
}
