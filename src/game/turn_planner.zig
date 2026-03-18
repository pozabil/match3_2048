const std = @import("std");
const types = @import("../core/types.zig");
const utils = @import("../core/utils.zig");
const match_lines = @import("../core/match_lines.zig");
const engine = @import("../core/engine.zig");
const animations = @import("../ui/animations.zig");

const SWAP_DURATION: f32 = 0.17;
const MATCH_DURATION: f32 = 0.13;
const RESOLVE_DURATION: f32 = 0.13;
const FALL_DURATION: f32 = 0.22;
const SHUFFLE_DURATION: f32 = 0.22;

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
        try appendMatchPhase(anim, &work.board, &blast_mask, .{
            .kind = .bomb,
            .phase_intensity = 1.25,
        });

        const before_explosion = work.board;
        const preview = try engine.previewBombResolve(allocator, &before_explosion, bomb_pos);
        const outcomes = [_]engine.WaveOutcome{
            .{
                .pos = bomb_pos,
                .tile = types.Tile.number(preview.value),
                .grants_score = false,
            },
        };
        try appendResolvePhase(anim, &before_explosion, &blast_mask, outcomes[0..]);

        try engine.explodeBombAt(&work, allocator, rng, bomb_pos);
        try appendFallPhase(anim, &preview.board_after_resolve, &work.board);

        work.stats.moves += 1;
        try appendCascadePhases(&work, allocator, rng, .{ .source = .auto }, anim);
        try appendPostMoveResolutionPhases(&work, allocator, rng, anim);
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
    try appendPostMoveResolutionPhases(&work, allocator, rng, anim);
    return work;
}

pub fn planManualShuffle(
    base_state: *const types.GameState,
    allocator: std.mem.Allocator,
    rng: std.Random,
    anim: *animations.AnimationState,
) !types.GameState {
    anim.clearPresentation();

    var work = base_state.*;
    if (work.status != .running) return error.GameAlreadyEnded;
    if (work.shuffles_left == 0) return error.NoShufflesLeft;

    work.shuffles_left -= 1;
    try appendSingleShuffleResolution(&work, allocator, rng, anim);
    try appendPostMoveResolutionPhases(&work, allocator, rng, anim);
    return work;
}

fn appendPostMoveResolutionPhases(
    work: *types.GameState,
    allocator: std.mem.Allocator,
    rng: std.Random,
    anim: *animations.AnimationState,
) !void {
    if (work.status != .running) return;

    while (!engine.hasValidMove(&work.board)) {
        if (work.shuffles_left == 0) {
            work.status = .lost;
            return;
        }

        work.shuffles_left -= 1;
        try appendSingleShuffleResolution(work, allocator, rng, anim);

        if (work.status != .running) return;
    }
}

fn appendSingleShuffleResolution(
    work: *types.GameState,
    allocator: std.mem.Allocator,
    rng: std.Random,
    anim: *animations.AnimationState,
) !void {
    const before_shuffle = work.board;
    try engine.shuffleBoard(work, allocator, rng);
    try appendShufflePhase(anim, &before_shuffle, &work.board);
    try appendCascadePhases(work, allocator, rng, .{ .source = .auto }, anim);
}

fn appendCascadePhases(
    work: *types.GameState,
    allocator: std.mem.Allocator,
    rng: std.Random,
    first_source: engine.ResolveSource,
    anim: *animations.AnimationState,
) !void {
    var source = first_source;
    var wave: usize = 0;

    while (true) {
        const before = work.board;

        var one = work.*;
        var step = try engine.resolveOneWave(&one, allocator, rng, source, wave);
        defer step.deinit(allocator);
        if (!step.had_match) break;

        const k_wave = @as(u8, @intCast(@min(@max(step.max_line_len, 3), 255)));
        const cascade_wave = @as(u8, @intCast(@min(wave, 255)));
        try appendMatchPhase(anim, &before, &step.matched_mask, .{
            .kind = .match,
            .k_wave = k_wave,
            .cascade_wave = cascade_wave,
        });
        try appendResolvePhase(anim, &before, &step.matched_mask, step.outcomes.items);
        try appendFallPhase(anim, &step.board_after_resolve, &one.board);

        work.* = one;
        source = .{ .source = .auto };
        wave += 1;

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
    phase.audio_event = .{ .kind = .swap };
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

fn appendMatchPhase(
    anim: *animations.AnimationState,
    board: *const types.Board,
    mask: *const [types.BOARD_ROWS][types.BOARD_COLS]bool,
    audio_event: animations.AudioEvent,
) !void {
    var phase = animations.Phase.init(.match_flash, MATCH_DURATION, board.*);
    phase.audio_event = audio_event;

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

fn appendResolvePhase(
    anim: *animations.AnimationState,
    board: *const types.Board,
    matched_mask: *const [types.BOARD_ROWS][types.BOARD_COLS]bool,
    outcomes: []const engine.WaveOutcome,
) !void {
    var phase = animations.Phase.init(.fall_spawn, RESOLVE_DURATION, board.*);

    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            if (matched_mask[r][c]) phase.hide_mask[r][c] = true;
        }
    }

    for (outcomes) |outcome| {
        phase.hide_mask[outcome.pos.row][outcome.pos.col] = true;
        try phase.addTrack(.{
            .tile = outcome.tile,
            .from_row = @as(f32, @floatFromInt(outcome.pos.row)),
            .from_col = @as(f32, @floatFromInt(outcome.pos.col)),
            .to_row = @as(f32, @floatFromInt(outcome.pos.row)),
            .to_col = @as(f32, @floatFromInt(outcome.pos.col)),
        });
    }

    try anim.appendPhase(phase);
}

fn appendShufflePhase(
    anim: *animations.AnimationState,
    before: *const types.Board,
    after: *const types.Board,
) !void {
    var phase = animations.Phase.init(.fall_spawn, SHUFFLE_DURATION, before.*);
    phase.audio_event = .{ .kind = .shuffle };

    var used_sources: [types.BOARD_ROWS][types.BOARD_COLS]bool = undefined;
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            used_sources[r][c] = false;
            const before_cell = before[r][c];
            const after_cell = after[r][c];
            if (!sameCell(before_cell, after_cell)) {
                phase.hide_mask[r][c] = true;
            }
        }
    }

    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            const dst_tile = after[r][c] orelse continue;
            if (sameCell(before[r][c], after[r][c])) {
                if (before[r][c] != null) {
                    used_sources[r][c] = true;
                }
                continue;
            }

            if (findSourcePosition(before, dst_tile, &used_sources)) |src| {
                if (src.row == r and src.col == c) continue;

                try phase.addTrack(.{
                    .tile = dst_tile,
                    .from_row = @as(f32, @floatFromInt(src.row)),
                    .from_col = @as(f32, @floatFromInt(src.col)),
                    .to_row = @as(f32, @floatFromInt(r)),
                    .to_col = @as(f32, @floatFromInt(c)),
                });
            } else {
                try phase.addTrack(.{
                    .tile = dst_tile,
                    .from_row = -1.2,
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

fn findSourcePosition(
    before: *const types.Board,
    dst_tile: types.Tile,
    used_sources: *[types.BOARD_ROWS][types.BOARD_COLS]bool,
) ?types.Position {
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            if (used_sources[r][c]) continue;
            const src_tile = before[r][c] orelse continue;
            if (!sameTile(src_tile, dst_tile)) continue;
            used_sources[r][c] = true;
            return .{ .row = r, .col = c };
        }
    }
    return null;
}

fn appendFallPhase(
    anim: *animations.AnimationState,
    before: *const types.Board,
    after: *const types.Board,
) !void {
    var phase = animations.Phase.init(.fall_spawn, FALL_DURATION, after.*);

    for (0..types.BOARD_COLS) |c| {
        var used_src: [types.BOARD_ROWS]bool = undefined;
        for (0..types.BOARD_ROWS) |r| used_src[r] = false;

        var rr: isize = @as(isize, @intCast(types.BOARD_ROWS - 1));
        while (rr >= 0) : (rr -= 1) {
            const r: usize = @intCast(rr);
            const dst_tile = after[r][c] orelse continue;

            if (findSourceRow(before, c, r, dst_tile, &used_src)) |src_row| {
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
                phase.hide_mask[r][c] = true;
                try phase.addTrack(.{
                    .tile = dst_tile,
                    .from_row = -1.2,
                    .from_col = @as(f32, @floatFromInt(c)),
                    .to_row = @as(f32, @floatFromInt(r)),
                    .to_col = @as(f32, @floatFromInt(c)),
                });
            }
        }
    }

    if (phase.track_count > 0) {
        phase.audio_event = .{
            .kind = .fall_spawn,
            .phase_intensity = fallPhaseIntensity(phase.track_count),
        };
    }
    try anim.appendPhase(phase);
}

fn fallPhaseIntensity(track_count: usize) f32 {
    if (track_count == 0) return 0.0;
    const x = @as(f32, @floatFromInt(track_count)) / 14.0;
    return std.math.clamp(x, 0.35, 1.8);
}

fn findSourceRow(
    before: *const types.Board,
    col: usize,
    dst_row: usize,
    dst_tile: types.Tile,
    used_src: *[types.BOARD_ROWS]bool,
) ?usize {
    var rr: isize = @as(isize, @intCast(types.BOARD_ROWS - 1));
    while (rr >= 0) : (rr -= 1) {
        const r: usize = @intCast(rr);
        if (used_src[r]) continue;
        const src_tile = before[r][col] orelse continue;
        if (!sameTile(src_tile, dst_tile)) continue;
        if (r <= dst_row) return r;
    }

    return null;
}

fn sameCell(a: ?types.Tile, b: ?types.Tile) bool {
    if (a == null and b == null) return true;
    if (a == null or b == null) return false;
    return sameTile(a.?, b.?);
}

fn sameTile(a: types.Tile, b: types.Tile) bool {
    if (a.id != 0 and b.id != 0) {
        return a.id == b.id;
    }
    return a.kind == b.kind and a.value == b.value;
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
