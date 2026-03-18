const std = @import("std");
const types = @import("types.zig");
const utils = @import("utils.zig");
const match_lines = @import("match_lines.zig");
const merge_rules = @import("merge_rules.zig");
const bomb_pool_reduce = @import("bomb_pool_reduce.zig");

pub const ResolveSource = struct {
    source: types.MatchSource,
    player_from: ?types.Position = null,
    player_to: ?types.Position = null,
};

const Outcome = struct {
    pos: types.Position,
    tile: types.Tile,
    grants_score: bool,
};

fn issueTileId(state: *types.GameState) u64 {
    const out = state.next_tile_id;
    state.next_tile_id +%= 1;
    if (state.next_tile_id == 0) state.next_tile_id = 1;
    return out;
}

fn makeNumberTile(state: *types.GameState, value: u32) types.Tile {
    return types.Tile.numberWithId(value, issueTileId(state));
}

fn makeBombTile(state: *types.GameState, value: u32) types.Tile {
    return types.Tile.bombWithId(value, issueTileId(state));
}

fn wouldCreateLine3(board: *const types.Board, row: usize, col: usize, value: u32) bool {
    if (col >= 2) {
        const l1 = board[row][col - 1];
        const l2 = board[row][col - 2];
        if (l1 != null and l2 != null and l1.?.kind == .number and l2.?.kind == .number and l1.?.value == value and l2.?.value == value) {
            return true;
        }
    }

    if (row >= 2) {
        const up_one = board[row - 1][col];
        const up_two = board[row - 2][col];
        if (up_one != null and up_two != null and up_one.?.kind == .number and up_two.?.kind == .number and up_one.?.value == value and up_two.?.value == value) {
            return true;
        }
    }

    return false;
}

fn fillBoardStartupNoLineMatches(state: *types.GameState, rng: std.Random) void {
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            state.board[r][c] = null;
        }
    }

    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            const primary = utils.randomStartTile(rng, state.cfg).value;
            const secondary: u32 = if (primary == 2) 4 else 2;

            if (!wouldCreateLine3(&state.board, r, c, primary)) {
                state.board[r][c] = makeNumberTile(state, primary);
            } else if (!wouldCreateLine3(&state.board, r, c, secondary)) {
                state.board[r][c] = makeNumberTile(state, secondary);
            } else {
                state.board[r][c] = makeNumberTile(state, primary);
            }
        }
    }
}

fn fillDeterministicFallback(state: *types.GameState) void {
    const pattern_a = [_]u32{ 2, 2, 4, 2, 4, 2, 4, 2 };
    const pattern_b = [_]u32{ 4, 4, 2, 4, 2, 4, 2, 4 };

    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            const v = if ((r % 2) == 0) pattern_a[c] else pattern_b[c];
            state.board[r][c] = makeNumberTile(state, v);
        }
    }
}

pub fn initializeBoard(state: *types.GameState, rng: std.Random) void {
    state.next_tile_id = 1;

    var attempts: usize = 0;
    while (attempts < 4096) : (attempts += 1) {
        fillBoardStartupNoLineMatches(state, rng);

        if (match_lines.hasAnyLineMatch(&state.board)) continue;
        if (!hasValidMove(&state.board)) continue;

        state.score = 0;
        state.max_tile = 0;
        state.shuffles_left = state.cfg.initial_shuffles;
        state.stats = .{};
        state.status = .running;
        state.input_locked = false;
        utils.setMaxTile(state);
        return;
    }

    // Deterministic fallback with no initial line matches and at least one valid move.
    fillDeterministicFallback(state);
    state.score = 0;
    state.max_tile = 0;
    state.shuffles_left = state.cfg.initial_shuffles;
    state.stats = .{};
    state.status = .running;
    state.input_locked = false;
    utils.setMaxTile(state);
}

pub fn hasValidMove(board: *const types.Board) bool {
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            const from = types.Position{ .row = r, .col = c };
            const neighbors = [_]types.Position{
                .{ .row = r, .col = if (c + 1 < types.BOARD_COLS) c + 1 else c },
                .{ .row = if (r + 1 < types.BOARD_ROWS) r + 1 else r, .col = c },
            };

            for (neighbors) |to| {
                if (to.row == from.row and to.col == from.col) continue;

                const a = board[from.row][from.col] orelse continue;
                const b = board[to.row][to.col] orelse continue;

                if (a.kind == .bomb or b.kind == .bomb) return true;

                var copy = board.*;
                utils.swap(&copy, from, to);
                if (match_lines.hasAnyLineMatch(&copy)) return true;
            }
        }
    }
    return false;
}

pub fn shuffleBoard(state: *types.GameState, allocator: std.mem.Allocator, rng: std.Random) !void {
    var items = std.ArrayList(types.Tile).empty;
    defer items.deinit(allocator);

    for (state.board) |row| {
        for (row) |cell| {
            if (cell) |t| try items.append(allocator, t);
        }
    }

    var i: usize = items.items.len;
    while (i > 1) {
        i -= 1;
        const j = rng.uintLessThan(usize, i + 1);
        const tmp = items.items[i];
        items.items[i] = items.items[j];
        items.items[j] = tmp;
    }

    var idx: usize = 0;
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            state.board[r][c] = if (idx < items.items.len) items.items[idx] else null;
            idx += 1;
        }
    }

    var attempts: usize = 0;
    while (!hasValidMove(&state.board) and attempts < 32) : (attempts += 1) {
        // retry with simple reshuffle
        i = items.items.len;
        while (i > 1) {
            i -= 1;
            const j = rng.uintLessThan(usize, i + 1);
            const tmp = items.items[i];
            items.items[i] = items.items[j];
            items.items[j] = tmp;
        }

        idx = 0;
        for (0..types.BOARD_ROWS) |r| {
            for (0..types.BOARD_COLS) |c| {
                state.board[r][c] = if (idx < items.items.len) items.items[idx] else null;
                idx += 1;
            }
        }
    }

    if (!hasValidMove(&state.board)) {
        forceOneValidMovePattern(state);
    }
}

fn forceOneValidMovePattern(state: *types.GameState) void {
    if (types.BOARD_ROWS == 0 or types.BOARD_COLS < 4) return;

    // Guarantees one legal move: swapping col 2 <-> 3 makes a 3-in-line.
    state.board[0][0] = makeNumberTile(state, 2);
    state.board[0][1] = makeNumberTile(state, 2);
    state.board[0][2] = makeNumberTile(state, 4);
    state.board[0][3] = makeNumberTile(state, 2);
}

pub fn applyPlayerAction(
    state: *types.GameState,
    allocator: std.mem.Allocator,
    rng: std.Random,
    from: types.Position,
    to: types.Position,
) !void {
    if (state.status != .running) return error.GameAlreadyEnded;
    if (!utils.isAdjacent(from, to)) return error.NotAdjacent;

    const from_tile = state.board[from.row][from.col] orelse return error.EmptySource;
    const to_tile = state.board[to.row][to.col] orelse return error.EmptyTarget;

    state.input_locked = true;
    defer state.input_locked = false;

    utils.swap(&state.board, from, to);

    if (from_tile.kind == .bomb or to_tile.kind == .bomb) {
        // Bomb always activates on player swap.
        const bomb_pos = if ((state.board[to.row][to.col] orelse types.Tile.number(0)).kind == .bomb) to else from;
        try explodeBombAt(state, allocator, rng, bomb_pos);
        state.stats.moves += 1;
        try resolveCascade(state, allocator, rng, .{ .source = .auto });
        try enforcePostMoveState(state, allocator, rng);
        return;
    }

    if (!match_lines.hasAnyLineMatch(&state.board)) {
        utils.swap(&state.board, from, to);
        return error.InvalidMoveNoMatch;
    }

    state.stats.moves += 1;
    try resolveCascade(state, allocator, rng, .{
        .source = .player,
        .player_from = from,
        .player_to = to,
    });
    try enforcePostMoveState(state, allocator, rng);
}

pub fn enforcePostMoveState(state: *types.GameState, allocator: std.mem.Allocator, rng: std.Random) !void {
    if (state.status != .running) return;

    if (!hasValidMove(&state.board)) {
        if (state.shuffles_left > 0) {
            state.shuffles_left -= 1;
            try shuffleBoard(state, allocator, rng);
        } else {
            state.status = .lost;
        }
    }
}

fn centerCandidate(positions: []const types.Position) types.Position {
    var row_sum: f64 = 0;
    var col_sum: f64 = 0;
    for (positions) |p| {
        row_sum += @as(f64, @floatFromInt(p.row));
        col_sum += @as(f64, @floatFromInt(p.col));
    }
    const count = @as(f64, @floatFromInt(positions.len));
    const center_row = row_sum / count;
    const center_col = col_sum / count;

    var best = positions[0];
    var best_dist = distanceSq(best, center_row, center_col);

    for (positions[1..]) |p| {
        const d = distanceSq(p, center_row, center_col);
        if (d < best_dist) {
            best = p;
            best_dist = d;
            continue;
        }
        if (d == best_dist) {
            if (p.row > best.row or (p.row == best.row and p.col > best.col)) {
                best = p;
            }
        }
    }

    return best;
}

fn distanceSq(p: types.Position, center_row: f64, center_col: f64) f64 {
    const dr = @as(f64, @floatFromInt(p.row)) - center_row;
    const dc = @as(f64, @floatFromInt(p.col)) - center_col;
    return dr * dr + dc * dc;
}

const LineOrientation = enum {
    horizontal,
    vertical,
};

fn lineOrientation(m: match_lines.LineMatch) LineOrientation {
    if (m.len >= 2 and m.positions[0].row == m.positions[1].row) return .horizontal;
    return .vertical;
}

fn lineContainsPosition(m: match_lines.LineMatch, p: types.Position) bool {
    for (0..m.len) |i| {
        const pos = m.positions[i];
        if (pos.row == p.row and pos.col == p.col) return true;
    }
    return false;
}

fn chooseLineOutcomePosition(
    source: ResolveSource,
    wave: usize,
    line_match: match_lines.LineMatch,
    positions: []const types.Position,
) types.Position {
    if (source.source == .player and wave == 0) {
        if (source.player_to) |player_to| {
            if (lineContainsPosition(line_match, player_to)) return player_to;
        }
        if (source.player_from) |player_from| {
            if (lineContainsPosition(line_match, player_from)) return player_from;
        }
    }
    return centerCandidate(positions);
}

fn mergedValueForLine(base_value: u32, line_len: usize) u32 {
    return switch (line_len) {
        3 => base_value * 2,
        4 => base_value * 4,
        else => base_value * 8,
    };
}

fn applyGravityAndSpawn(state: *types.GameState, rng: std.Random) void {
    for (0..types.BOARD_COLS) |c| {
        var write_row: isize = @as(isize, @intCast(types.BOARD_ROWS - 1));
        var r: isize = @as(isize, @intCast(types.BOARD_ROWS - 1));
        while (r >= 0) : (r -= 1) {
            const rr: usize = @intCast(r);
            if (state.board[rr][c]) |tile| {
                const wr: usize = @intCast(write_row);
                state.board[wr][c] = tile;
                if (wr != rr) state.board[rr][c] = null;
                write_row -= 1;
            }
        }

        while (write_row >= 0) : (write_row -= 1) {
            const wr: usize = @intCast(write_row);
            const spawn_value = utils.randomSpawnTile(rng, state.cfg).value;
            state.board[wr][c] = makeNumberTile(state, spawn_value);
        }
    }
}

pub fn resolveCascade(
    state: *types.GameState,
    allocator: std.mem.Allocator,
    rng: std.Random,
    source: ResolveSource,
) !void {
    var wave: usize = 0;

    while (wave < state.cfg.max_cascade_waves) : (wave += 1) {
        var lines = try match_lines.findLineMatches(allocator, &state.board);
        defer lines.deinit(allocator);
        if (lines.items.len == 0) break;

        state.stats.cascade_waves += 1;

        var matched: [types.BOARD_ROWS][types.BOARD_COLS]bool = undefined;
        for (0..types.BOARD_ROWS) |r| {
            for (0..types.BOARD_COLS) |c| {
                matched[r][c] = false;
            }
        }

        for (lines.items) |m| {
            for (0..m.len) |i| {
                const p = m.positions[i];
                matched[p.row][p.col] = true;
            }
        }

        var outcomes = std.ArrayList(Outcome).empty;
        defer outcomes.deinit(allocator);

        var horizontal_line_idx: [types.BOARD_ROWS][types.BOARD_COLS]isize = undefined;
        var vertical_line_idx: [types.BOARD_ROWS][types.BOARD_COLS]isize = undefined;
        for (0..types.BOARD_ROWS) |r| {
            for (0..types.BOARD_COLS) |c| {
                horizontal_line_idx[r][c] = -1;
                vertical_line_idx[r][c] = -1;
            }
        }

        var line_consumed = std.ArrayList(bool).empty;
        defer line_consumed.deinit(allocator);
        try line_consumed.resize(allocator, lines.items.len);
        for (line_consumed.items) |*consumed| consumed.* = false;

        for (lines.items, 0..) |m, line_idx| {
            const orientation = lineOrientation(m);
            for (0..m.len) |i| {
                const p = m.positions[i];
                switch (orientation) {
                    .horizontal => horizontal_line_idx[p.row][p.col] = @as(isize, @intCast(line_idx)),
                    .vertical => vertical_line_idx[p.row][p.col] = @as(isize, @intCast(line_idx)),
                }
            }
        }

        // Intersections are resolved per crossing cell:
        // - if both lines are length >= 4 => bomb 4V in crossing cell;
        // - otherwise numeric outcome:
        //   Oh = line outcome of horizontal, Ov = line outcome of vertical;
        //   equal -> 2*Oh, different -> max(Oh, Ov).
        for (0..types.BOARD_ROWS) |r| {
            for (0..types.BOARD_COLS) |c| {
                const h_idx = horizontal_line_idx[r][c];
                const v_idx = vertical_line_idx[r][c];
                if (h_idx < 0 or v_idx < 0) continue;

                const cell = state.board[r][c] orelse continue;
                if (cell.kind != .number) continue;

                const h_line_idx: usize = @intCast(h_idx);
                const v_line_idx: usize = @intCast(v_idx);
                const h_line = lines.items[h_line_idx];
                const v_line = lines.items[v_line_idx];

                line_consumed.items[h_line_idx] = true;
                line_consumed.items[v_line_idx] = true;

                if (h_line.len >= 4 and v_line.len >= 4) {
                    try outcomes.append(allocator, .{
                        .pos = .{ .row = r, .col = c },
                        .tile = makeBombTile(state, cell.value * 4),
                        .grants_score = false,
                    });
                } else {
                    const out_h = mergedValueForLine(h_line.value, h_line.len);
                    const out_v = mergedValueForLine(v_line.value, v_line.len);
                    const merged_value: u32 = if (out_h == out_v) out_h * 2 else @max(out_h, out_v);
                    try outcomes.append(allocator, .{
                        .pos = .{ .row = r, .col = c },
                        .tile = makeNumberTile(state, merged_value),
                        .grants_score = true,
                    });
                }
            }
        }

        // Normal line merges apply only to lines not consumed by intersections.
        for (lines.items, 0..) |m, line_idx| {
            if (m.len < 3) continue;
            if (line_consumed.items[line_idx]) continue;

            var temp = std.ArrayList(types.Position).empty;
            defer temp.deinit(allocator);
            try temp.ensureTotalCapacity(allocator, m.len);
            for (0..m.len) |i| {
                try temp.append(allocator, m.positions[i]);
            }

            const place = chooseLineOutcomePosition(source, wave, m, temp.items);
            const merged_value = mergedValueForLine(m.value, m.len);
            try outcomes.append(allocator, .{
                .pos = place,
                .tile = makeNumberTile(state, merged_value),
                .grants_score = true,
            });
        }

        // Clear all matched cells.
        for (0..types.BOARD_ROWS) |r| {
            for (0..types.BOARD_COLS) |c| {
                if (matched[r][c]) {
                    state.board[r][c] = null;
                }
            }
        }

        // Place outcomes.
        for (outcomes.items) |o| {
            state.board[o.pos.row][o.pos.col] = o.tile;
            if (o.grants_score and o.tile.kind == .number) {
                merge_rules.applyScoreForMerge(state, o.tile.value);
            }
        }

        applyGravityAndSpawn(state, rng);
        utils.setMaxTile(state);
        if (state.max_tile >= 2048) {
            state.status = .won;
            return;
        }
    }
}

pub fn explodeBombAt(
    state: *types.GameState,
    allocator: std.mem.Allocator,
    rng: std.Random,
    origin: types.Position,
) !void {
    var pool = std.ArrayList(u32).empty;
    defer pool.deinit(allocator);

    state.stats.bomb_activations += 1;

    const row_start = if (origin.row == 0) 0 else origin.row - 1;
    const row_end = if (origin.row + 1 >= types.BOARD_ROWS) types.BOARD_ROWS - 1 else origin.row + 1;
    const col_start = if (origin.col == 0) 0 else origin.col - 1;
    const col_end = if (origin.col + 1 >= types.BOARD_COLS) types.BOARD_COLS - 1 else origin.col + 1;

    for (row_start..row_end + 1) |r| {
        for (col_start..col_end + 1) |c| {
            if (state.board[r][c]) |tile| {
                if (tile.kind == .number) {
                    try pool.append(allocator, tile.value);
                } else if (tile.kind == .bomb) {
                    std.debug.assert(tile.value > 0);
                    try pool.append(allocator, tile.value);
                }
                state.board[r][c] = null;
            }
        }
    }

    if (pool.items.len == 0) return error.EmptyPool;
    const value = try bomb_pool_reduce.reducePoolToSingleValue(allocator, pool.items);
    state.board[origin.row][origin.col] = makeNumberTile(state, value);
    merge_rules.applyScoreForMerge(state, value);

    applyGravityAndSpawn(state, rng);
    utils.setMaxTile(state);
}
