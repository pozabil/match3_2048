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

pub const WaveOutcome = struct {
    pos: types.Position,
    tile: types.Tile,
    grants_score: bool,
};

pub const WaveStep = struct {
    had_match: bool,
    max_line_len: usize,
    matched_mask: [types.BOARD_ROWS][types.BOARD_COLS]bool,
    outcomes: std.ArrayList(WaveOutcome),
    board_after_resolve: types.Board,

    pub fn init(board: types.Board) WaveStep {
        return .{
            .had_match = false,
            .max_line_len = 0,
            .matched_mask = falseMask(),
            .outcomes = .empty,
            .board_after_resolve = board,
        };
    }

    pub fn deinit(self: *WaveStep, allocator: std.mem.Allocator) void {
        self.outcomes.deinit(allocator);
    }
};

pub const BombResolvePreview = struct {
    board_after_resolve: types.Board,
    value: u32,
};

const Component = struct {
    value: u32,
    cells: [types.BOARD_ROWS * types.BOARD_COLS]types.Position,
    len: usize,
    intersections: [types.BOARD_ROWS * types.BOARD_COLS]types.Position,
    intersection_count: usize,
};

const SHUFFLE_FALLBACK_LIMIT: usize = 5;

const ShuffleBudget = struct {
    attempts: usize,
    max_groups: usize,
};

const SHUFFLE_BUDGETS = [_]ShuffleBudget{
    .{ .attempts = 32, .max_groups = 3 },
    .{ .attempts = 16, .max_groups = 4 },
    .{ .attempts = 16, .max_groups = 5 },
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
        state.shuffle_bonus_1024_awarded = false;
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
    state.shuffle_bonus_1024_awarded = false;
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

    var last_candidate = state.board;

    for (SHUFFLE_BUDGETS) |budget| {
        var attempt: usize = 0;
        while (attempt < budget.attempts) : (attempt += 1) {
            fisherYates(items.items, rng);
            placeItemsOnBoard(state, items.items);
            last_candidate = state.board;

            if (!hasValidMove(&state.board)) continue;
            const groups = try countLineMatchGroups(allocator, &state.board);
            if (groups <= budget.max_groups) return;
        }
    }

    state.board = last_candidate;
    try reduceReadyGroupsAfterShuffle(state, allocator);

    const groups_after = try countLineMatchGroups(allocator, &state.board);
    if (groups_after > SHUFFLE_FALLBACK_LIMIT or !hasValidMove(&state.board)) {
        forceOneValidMovePattern(state);
    }
}

fn fisherYates(items: []types.Tile, rng: std.Random) void {
    var i: usize = items.len;
    while (i > 1) {
        i -= 1;
        const j = rng.uintLessThan(usize, i + 1);
        const tmp = items[i];
        items[i] = items[j];
        items[j] = tmp;
    }
}

fn placeItemsOnBoard(state: *types.GameState, items: []const types.Tile) void {
    var idx: usize = 0;
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            state.board[r][c] = if (idx < items.len) items[idx] else null;
            idx += 1;
        }
    }
}

fn reduceReadyGroupsAfterShuffle(state: *types.GameState, allocator: std.mem.Allocator) !void {
    var guard: usize = 0;
    while (guard < 256) : (guard += 1) {
        var lines = try match_lines.findLineMatches(allocator, &state.board);
        defer lines.deinit(allocator);

        if (lines.items.len <= SHUFFLE_FALLBACK_LIMIT) return;

        const pick = selectLowestNominalGroup(lines.items);
        const p = lineAnchorPosition(lines.items[pick]);
        const cell = state.board[p.row][p.col] orelse continue;
        if (cell.kind != .number) continue;

        var updated = cell;
        updated.value = stepDownNominal(cell.value);
        state.board[p.row][p.col] = updated;
    }
}

fn selectLowestNominalGroup(lines: []const match_lines.LineMatch) usize {
    var best_idx: usize = 0;
    var best_value: u32 = lines[0].value;
    var best_anchor = lineAnchorPosition(lines[0]);

    for (lines[1..], 1..) |m, idx| {
        const anchor = lineAnchorPosition(m);
        if (m.value < best_value) {
            best_value = m.value;
            best_anchor = anchor;
            best_idx = idx;
            continue;
        }
        if (m.value == best_value) {
            if (anchor.row < best_anchor.row or (anchor.row == best_anchor.row and anchor.col < best_anchor.col)) {
                best_anchor = anchor;
                best_idx = idx;
            }
        }
    }

    return best_idx;
}

fn lineAnchorPosition(m: match_lines.LineMatch) types.Position {
    return m.positions[m.len / 2];
}

fn stepDownNominal(value: u32) u32 {
    if (value == 2) return 4;
    return value / 2;
}

pub fn countLineMatchGroups(allocator: std.mem.Allocator, board: *const types.Board) !usize {
    var lines = try match_lines.findLineMatches(allocator, board);
    defer lines.deinit(allocator);
    return lines.items.len;
}

fn forceOneValidMovePattern(state: *types.GameState) void {
    // Product-approved fallback may rewrite nominals.
    // This deterministic board has no ready line matches and at least one valid move.
    fillDeterministicFallback(state);
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

    const had_match = try resolveCascadeWithResult(state, allocator, rng, .{
        .source = .player,
        .player_from = from,
        .player_to = to,
    });
    if (!had_match) {
        utils.swap(&state.board, from, to);
        return error.InvalidMoveNoMatch;
    }

    state.stats.moves += 1;
    try enforcePostMoveState(state, allocator, rng);
}

pub fn enforcePostMoveState(state: *types.GameState, allocator: std.mem.Allocator, rng: std.Random) !void {
    if (state.status != .running) return;

    while (!hasValidMove(&state.board)) {
        if (state.shuffles_left == 0) {
            state.status = .lost;
            return;
        }

        state.shuffles_left -= 1;
        try shuffleBoard(state, allocator, rng);
        try settleShuffledBoard(state, allocator, rng);
        if (state.status != .running) return;
    }
}

pub fn settleShuffledBoard(state: *types.GameState, allocator: std.mem.Allocator, rng: std.Random) !void {
    if (state.status != .running) return;
    if (!match_lines.hasAnyLineMatch(&state.board)) return;

    try resolveCascade(state, allocator, rng, .{ .source = .auto });
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

fn chooseComponentOutcomePosition(
    source: ResolveSource,
    wave: usize,
    candidates: []const types.Position,
) types.Position {
    if (source.source == .player and wave == 0) {
        if (source.player_to) |player_to| {
            if (positionSliceContains(candidates, player_to)) return player_to;
        }
        if (source.player_from) |player_from| {
            if (positionSliceContains(candidates, player_from)) return player_from;
        }
    }
    return centerCandidate(candidates);
}

fn positionSliceContains(positions: []const types.Position, target: types.Position) bool {
    for (positions) |p| {
        if (p.row == target.row and p.col == target.col) return true;
    }
    return false;
}

fn singleLineMergedValue(base_value: u32, line_len: usize) u32 {
    std.debug.assert(line_len >= 3);
    var out = base_value;
    var i: usize = 0;
    while (i < line_len - 2) : (i += 1) {
        out *= 2;
    }
    return out;
}

fn applyGravityAndSpawn(state: *types.GameState, rng: std.Random) void {
    const high_tier_spawn = boardHasTileAtLeast(&state.board, state.cfg.high_tier_spawn_threshold);

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
            const spawn_value = utils.randomSpawnTileWithTier(rng, state.cfg, high_tier_spawn).value;
            state.board[wr][c] = makeNumberTile(state, spawn_value);
        }
    }
}

fn boardHasTileAtLeast(board: *const types.Board, threshold: u32) bool {
    for (board.*) |row| {
        for (row) |cell| {
            if (cell) |tile| {
                if (tile.value >= threshold) return true;
            }
        }
    }
    return false;
}

fn refreshMaxTileAndStatus(state: *types.GameState) void {
    utils.setMaxTile(state);
    if (state.max_tile >= 2048) {
        state.status = .won;
    }
}

const LineOrientation = enum {
    horizontal,
    vertical,
};

fn lineOrientation(m: match_lines.LineMatch) LineOrientation {
    if (m.len >= 2 and m.positions[0].row == m.positions[1].row) return .horizontal;
    return .vertical;
}

fn falseMask() [types.BOARD_ROWS][types.BOARD_COLS]bool {
    var out: [types.BOARD_ROWS][types.BOARD_COLS]bool = undefined;
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            out[r][c] = false;
        }
    }
    return out;
}

fn isBombIntersectionAt(
    row: usize,
    col: usize,
    horizontal_line_idx: *const [types.BOARD_ROWS][types.BOARD_COLS]isize,
    vertical_line_idx: *const [types.BOARD_ROWS][types.BOARD_COLS]isize,
    lines: []const match_lines.LineMatch,
) bool {
    const h_idx = horizontal_line_idx[row][col];
    const v_idx = vertical_line_idx[row][col];
    if (h_idx < 0 or v_idx < 0) return false;

    const h_line = lines[@as(usize, @intCast(h_idx))];
    const v_line = lines[@as(usize, @intCast(v_idx))];
    return h_line.len >= 4 and v_line.len >= 4;
}

fn appendUniquePosition(
    list: *[types.BOARD_ROWS * types.BOARD_COLS]types.Position,
    count: *usize,
    p: types.Position,
) void {
    var i: usize = 0;
    while (i < count.*) : (i += 1) {
        if (list[i].row == p.row and list[i].col == p.col) return;
    }
    list[count.*] = p;
    count.* += 1;
}

fn isSingleLine(cells: []const types.Position) bool {
    if (cells.len < 3) return false;

    var same_row = true;
    var same_col = true;
    const row0 = cells[0].row;
    const col0 = cells[0].col;

    for (cells[1..]) |p| {
        if (p.row != row0) same_row = false;
        if (p.col != col0) same_col = false;
    }

    return same_row or same_col;
}

fn cellPoolValue(value: u32, count: usize) u32 {
    std.debug.assert(count > 0);

    // For a uniform pool (all entries == value), pool-reduce collapses into:
    // value * highestPowerOfTwoLessOrEqual(count)
    var out = value;
    var n = count;
    while (n >= 2) : (n >>= 1) {
        out *= 2;
    }
    return out;
}

pub fn resolveOneWave(
    state: *types.GameState,
    allocator: std.mem.Allocator,
    rng: std.Random,
    source: ResolveSource,
    wave: usize,
) !WaveStep {
    var step = WaveStep.init(state.board);
    errdefer step.deinit(allocator);

    var lines = try match_lines.findLineMatches(allocator, &state.board);
    defer lines.deinit(allocator);
    if (lines.items.len == 0) {
        return step;
    }

    step.had_match = true;
    state.stats.cascade_waves += 1;
    for (lines.items) |m| {
        if (m.len > step.max_line_len) step.max_line_len = m.len;
    }
    try step.outcomes.ensureTotalCapacity(allocator, lines.items.len);

    var matched = falseMask();
    for (lines.items) |m| {
        for (0..m.len) |i| {
            const p = m.positions[i];
            matched[p.row][p.col] = true;
        }
    }
    step.matched_mask = matched;

    var horizontal_line_idx: [types.BOARD_ROWS][types.BOARD_COLS]isize = undefined;
    var vertical_line_idx: [types.BOARD_ROWS][types.BOARD_COLS]isize = undefined;
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            horizontal_line_idx[r][c] = -1;
            vertical_line_idx[r][c] = -1;
        }
    }

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

    var visited = falseMask();
    var queue: [types.BOARD_ROWS * types.BOARD_COLS]types.Position = undefined;

    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            if (!matched[r][c] or visited[r][c]) continue;

            const first_tile = state.board[r][c] orelse continue;
            if (first_tile.kind != .number) continue;

            var component = Component{
                .value = first_tile.value,
                .cells = undefined,
                .len = 0,
                .intersections = undefined,
                .intersection_count = 0,
            };

            var q_head: usize = 0;
            var q_tail: usize = 0;
            visited[r][c] = true;
            queue[q_tail] = .{ .row = r, .col = c };
            q_tail += 1;

            while (q_head < q_tail) {
                const p = queue[q_head];
                q_head += 1;

                component.cells[component.len] = p;
                component.len += 1;

                if (isBombIntersectionAt(p.row, p.col, &horizontal_line_idx, &vertical_line_idx, lines.items)) {
                    appendUniquePosition(&component.intersections, &component.intersection_count, p);
                }

                const neighbors = [_]types.Position{
                    .{ .row = if (p.row == 0) p.row else p.row - 1, .col = p.col },
                    .{ .row = if (p.row + 1 >= types.BOARD_ROWS) p.row else p.row + 1, .col = p.col },
                    .{ .row = p.row, .col = if (p.col == 0) p.col else p.col - 1 },
                    .{ .row = p.row, .col = if (p.col + 1 >= types.BOARD_COLS) p.col else p.col + 1 },
                };

                for (neighbors) |n| {
                    if (n.row == p.row and n.col == p.col) continue;
                    if (visited[n.row][n.col]) continue;
                    if (!matched[n.row][n.col]) continue;

                    const n_tile = state.board[n.row][n.col] orelse continue;
                    if (n_tile.kind != .number or n_tile.value != component.value) continue;

                    visited[n.row][n.col] = true;
                    queue[q_tail] = n;
                    q_tail += 1;
                }
            }

            const cells = component.cells[0..component.len];
            const pool_result = cellPoolValue(component.value, component.len);
            const has_bomb = component.intersection_count > 0;

            if (has_bomb) {
                const candidates = component.intersections[0..component.intersection_count];
                const pos = chooseComponentOutcomePosition(source, wave, candidates);
                const bomb_value = @max(@as(u32, 1), pool_result / 2);
                try step.outcomes.append(allocator, .{
                    .pos = pos,
                    .tile = makeBombTile(state, bomb_value),
                    .grants_score = false,
                });
            } else {
                const pos = chooseComponentOutcomePosition(source, wave, cells);
                const merged_value = if (isSingleLine(cells)) singleLineMergedValue(component.value, component.len) else pool_result;
                try step.outcomes.append(allocator, .{
                    .pos = pos,
                    .tile = makeNumberTile(state, merged_value),
                    .grants_score = true,
                });
            }
        }
    }

    // Clear all matched cells.
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            if (matched[r][c]) {
                state.board[r][c] = null;
            }
        }
    }

    // Place one outcome per component.
    for (step.outcomes.items) |o| {
        state.board[o.pos.row][o.pos.col] = o.tile;
        if (o.grants_score and o.tile.kind == .number) {
            merge_rules.applyScoreForMerge(state, o.tile.value);
        }
    }

    step.board_after_resolve = state.board;

    applyGravityAndSpawn(state, rng);
    refreshMaxTileAndStatus(state);

    return step;
}

pub fn resolveCascade(
    state: *types.GameState,
    allocator: std.mem.Allocator,
    rng: std.Random,
    source_init: ResolveSource,
) !void {
    _ = try resolveCascadeWithResult(state, allocator, rng, source_init);
}

pub fn resolveCascadeWithResult(
    state: *types.GameState,
    allocator: std.mem.Allocator,
    rng: std.Random,
    source_init: ResolveSource,
) !bool {
    var source = source_init;
    var wave: usize = 0;
    var had_any_match = false;

    while (wave < state.cfg.max_cascade_waves) : (wave += 1) {
        var step = try resolveOneWave(state, allocator, rng, source, wave);
        defer step.deinit(allocator);
        if (!step.had_match) break;
        had_any_match = true;
        if (state.status == .won) return had_any_match;
        source = .{ .source = .auto };
    }
    return had_any_match;
}

pub fn explodeBombAt(
    state: *types.GameState,
    allocator: std.mem.Allocator,
    rng: std.Random,
    origin: types.Position,
) !void {
    state.stats.bomb_activations += 1;

    const preview = try previewBombResolve(allocator, &state.board, origin);
    state.board = preview.board_after_resolve;
    state.board[origin.row][origin.col] = makeNumberTile(state, preview.value);
    merge_rules.applyScoreForMerge(state, preview.value);

    applyGravityAndSpawn(state, rng);
    refreshMaxTileAndStatus(state);
}

pub fn previewBombResolve(
    allocator: std.mem.Allocator,
    board: *const types.Board,
    origin: types.Position,
) !BombResolvePreview {
    var board_after_resolve = board.*;
    var pool = std.ArrayList(u32).empty;
    defer pool.deinit(allocator);

    const row_start = if (origin.row == 0) 0 else origin.row - 1;
    const row_end = if (origin.row + 1 >= types.BOARD_ROWS) types.BOARD_ROWS - 1 else origin.row + 1;
    const col_start = if (origin.col == 0) 0 else origin.col - 1;
    const col_end = if (origin.col + 1 >= types.BOARD_COLS) types.BOARD_COLS - 1 else origin.col + 1;

    for (row_start..row_end + 1) |r| {
        for (col_start..col_end + 1) |c| {
            if (board_after_resolve[r][c]) |tile| {
                if (tile.kind == .number) {
                    try pool.append(allocator, tile.value);
                } else if (tile.kind == .bomb) {
                    std.debug.assert(tile.value > 0);
                    try pool.append(allocator, tile.value);
                }
                board_after_resolve[r][c] = null;
            }
        }
    }

    if (pool.items.len == 0) return error.EmptyPool;
    const value = try bomb_pool_reduce.reducePoolToSingleValue(allocator, pool.items);
    board_after_resolve[origin.row][origin.col] = types.Tile.number(value);
    return .{
        .board_after_resolve = board_after_resolve,
        .value = value,
    };
}
