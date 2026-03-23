const std = @import("std");
const game = @import("match3_2048");

const cfg = game.core.config;
const types = game.core.types;
const engine = game.core.engine;
const turn_planner = game.game.turn_planner;
const animations = game.ui.animations;

fn fillBaselineNoLines(board: *types.Board) void {
    const pattern_a = [_]u32{ 2, 2, 4, 2, 4, 2, 4, 2 };
    const pattern_b = [_]u32{ 4, 4, 2, 4, 2, 4, 2, 4 };

    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            const v = if ((r % 2) == 0) pattern_a[c] else pattern_b[c];
            board[r][c] = types.Tile.number(v);
        }
    }
}

fn clear(board: *types.Board) void {
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            board[r][c] = null;
        }
    }
}

test "turn planner matches core final state for same seed" {
    var base = types.GameState.init(cfg.defaultConfig());
    fillBaselineNoLines(&base.board);

    // guaranteed valid swap: 2 2 4 2 -> swap 4 and 2
    base.board[0][0] = types.Tile.number(2);
    base.board[0][1] = types.Tile.number(2);
    base.board[0][2] = types.Tile.number(4);
    base.board[0][3] = types.Tile.number(2);

    var expected = base;
    var planned_base = base;

    var prng_a = std.Random.DefaultPrng.init(54321);
    var prng_b = std.Random.DefaultPrng.init(54321);

    try turn_planner.applyPlayerTurn(
        &expected,
        std.testing.allocator,
        prng_a.random(),
        .{ .row = 0, .col = 2 },
        .{ .row = 0, .col = 3 },
    );

    var anim: animations.AnimationState = .{};
    anim.reset();

    const planned = try turn_planner.planPlayerTurn(
        &planned_base,
        std.testing.allocator,
        prng_b.random(),
        .{ .row = 0, .col = 2 },
        .{ .row = 0, .col = 3 },
        &anim,
    );

    try std.testing.expect(anim.phase_count >= 2);
    try std.testing.expectEqualDeep(expected.board, planned.board);
    try std.testing.expectEqual(expected.score, planned.score);
    try std.testing.expectEqual(expected.max_tile, planned.max_tile);
    try std.testing.expectEqual(expected.shuffles_left, planned.shuffles_left);
    try std.testing.expectEqual(expected.status, planned.status);
    try std.testing.expectEqualDeep(expected.stats, planned.stats);
}

test "turn planner respects max_cascade_waves cap" {
    var custom_cfg = cfg.defaultConfig();
    custom_cfg.max_cascade_waves = 1;

    var base = types.GameState.init(custom_cfg);
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            base.board[r][c] = types.Tile.number(2);
        }
    }

    var prng = std.Random.DefaultPrng.init(91002);
    var anim: animations.AnimationState = .{};
    anim.reset();

    const planned = try turn_planner.planPlayerTurn(
        &base,
        std.testing.allocator,
        prng.random(),
        .{ .row = 0, .col = 0 },
        .{ .row = 0, .col = 1 },
        &anim,
    );

    try std.testing.expectEqual(@as(u32, 1), planned.stats.cascade_waves);
}

test "fall phase tracks never move upward" {
    var base = types.GameState.init(cfg.defaultConfig());
    fillBaselineNoLines(&base.board);

    // guaranteed valid swap: 2 2 4 2 -> swap 4 and 2
    base.board[0][0] = types.Tile.number(2);
    base.board[0][1] = types.Tile.number(2);
    base.board[0][2] = types.Tile.number(4);
    base.board[0][3] = types.Tile.number(2);

    var prng = std.Random.DefaultPrng.init(7001);
    var anim: animations.AnimationState = .{};
    anim.reset();

    _ = try turn_planner.planPlayerTurn(
        &base,
        std.testing.allocator,
        prng.random(),
        .{ .row = 0, .col = 2 },
        .{ .row = 0, .col = 3 },
        &anim,
    );

    var saw_fall_track = false;
    for (0..anim.phase_count) |i| {
        const phase = anim.phases[i];
        if (phase.kind != .fall_spawn) continue;
        for (0..phase.track_count) |j| {
            saw_fall_track = true;
            const tr = phase.tracks[j];
            try std.testing.expect(tr.from_row <= tr.to_row + 0.0001);
        }
    }
    try std.testing.expect(saw_fall_track);
}

test "bomb swap match phase is limited to single 3x3 area" {
    var base = types.GameState.init(cfg.defaultConfig());
    clear(&base.board);

    base.board[7][3] = types.Tile.bombWithValue(2);
    base.board[7][4] = types.Tile.number(2);
    base.board[6][3] = types.Tile.bombWithValue(2);

    // Outside primary 3x3 of origin (7,3), but would be in secondary 3x3 if chain were enabled.
    base.board[5][2] = types.Tile.number(64);

    var prng = std.Random.DefaultPrng.init(7002);
    var anim: animations.AnimationState = .{};
    anim.reset();

    _ = try turn_planner.planPlayerTurn(
        &base,
        std.testing.allocator,
        prng.random(),
        .{ .row = 7, .col = 3 },
        .{ .row = 7, .col = 4 },
        &anim,
    );

    var saw_match_phase = false;
    var covered_secondary_cell = true;
    for (0..anim.phase_count) |i| {
        const phase = anim.phases[i];
        if (phase.kind != .match_flash) continue;
        saw_match_phase = true;
        covered_secondary_cell = phase.hide_mask[5][2];
        break;
    }

    try std.testing.expect(saw_match_phase);
    try std.testing.expect(!covered_secondary_cell);
}

test "bomb swap fall phase animates survivor tile as fall, not spawn" {
    var base = types.GameState.init(cfg.defaultConfig());
    clear(&base.board);

    // Bomb area is rows 6..7 and cols 2..4 for origin (7,3).
    base.board[7][3] = types.Tile.bombWithValue(2);
    base.board[7][4] = types.Tile.number(2);
    base.board[6][3] = types.Tile.bombWithValue(2);

    // This tile is outside blast and must fall down into cleared space.
    base.board[5][2] = types.Tile.number(64);

    var prng = std.Random.DefaultPrng.init(7003);
    var anim: animations.AnimationState = .{};
    anim.reset();

    _ = try turn_planner.planPlayerTurn(
        &base,
        std.testing.allocator,
        prng.random(),
        .{ .row = 7, .col = 3 },
        .{ .row = 7, .col = 4 },
        &anim,
    );

    var saw_fall_phase = false;
    var saw_64_fall_track = false;
    for (0..anim.phase_count) |i| {
        const phase = anim.phases[i];
        if (phase.kind != .fall_spawn) continue;
        saw_fall_phase = true;
        for (0..phase.track_count) |j| {
            const tr = phase.tracks[j];
            if (tr.tile.kind != .number or tr.tile.value != 64) continue;
            if (@abs(tr.from_col - 2.0) > 0.0001 or @abs(tr.to_col - 2.0) > 0.0001) continue;
            if (tr.to_row <= tr.from_row) continue;
            saw_64_fall_track = true;
            break;
        }
        if (saw_64_fall_track) break;
    }

    try std.testing.expect(saw_fall_phase);
    try std.testing.expect(saw_64_fall_track);
}

test "bomb swap has resolve phase before fall phase" {
    var base = types.GameState.init(cfg.defaultConfig());
    clear(&base.board);

    base.board[7][3] = types.Tile.bombWithValue(2);
    base.board[7][4] = types.Tile.number(2);
    base.board[6][3] = types.Tile.number(2);
    base.board[6][4] = types.Tile.number(4);
    base.board[6][5] = types.Tile.number(8);
    base.board[7][5] = types.Tile.number(16);

    var prng = std.Random.DefaultPrng.init(7004);
    var anim: animations.AnimationState = .{};
    anim.reset();

    _ = try turn_planner.planPlayerTurn(
        &base,
        std.testing.allocator,
        prng.random(),
        .{ .row = 7, .col = 3 },
        .{ .row = 7, .col = 4 },
        &anim,
    );

    var first_match_idx: ?usize = null;
    var resolve_idx: ?usize = null;
    var fall_idx: ?usize = null;

    for (0..anim.phase_count) |i| {
        const phase = anim.phases[i];
        if (phase.kind == .match_flash and first_match_idx == null) {
            first_match_idx = i;
            continue;
        }
        if (phase.kind != .fall_spawn) continue;

        var has_motion = false;
        var has_origin_anchor = false;
        for (0..phase.track_count) |j| {
            const tr = phase.tracks[j];
            if (@abs(tr.from_row - tr.to_row) > 0.0001 or @abs(tr.from_col - tr.to_col) > 0.0001) {
                has_motion = true;
            }
            if (@abs(tr.from_row - 7.0) < 0.0001 and @abs(tr.to_row - 7.0) < 0.0001 and
                @abs(tr.from_col - 3.0) < 0.0001 and @abs(tr.to_col - 3.0) < 0.0001)
            {
                has_origin_anchor = true;
            }
        }

        if (!has_motion and has_origin_anchor and resolve_idx == null) resolve_idx = i;
        if (has_motion and fall_idx == null) fall_idx = i;
    }

    try std.testing.expect(first_match_idx != null);
    try std.testing.expect(resolve_idx != null);
    try std.testing.expect(fall_idx != null);
    try std.testing.expect(first_match_idx.? < resolve_idx.?);
    try std.testing.expect(resolve_idx.? < fall_idx.?);
}

test "manual shuffle planner matches core final state and keeps phase pipeline" {
    var base = types.GameState.init(cfg.defaultConfig());
    fillBaselineNoLines(&base.board);

    var expected = base;
    var planned_base = base;

    var prng_a = std.Random.DefaultPrng.init(4242);
    var prng_b = std.Random.DefaultPrng.init(4242);

    expected.shuffles_left -= 1;
    try engine.shuffleBoard(&expected, std.testing.allocator, prng_a.random());
    try engine.settleShuffledBoard(&expected, std.testing.allocator, prng_a.random());
    try turn_planner.enforcePostMoveState(&expected, std.testing.allocator, prng_a.random());

    var anim: animations.AnimationState = .{};
    anim.reset();

    const planned = try turn_planner.planManualShuffle(
        &planned_base,
        std.testing.allocator,
        prng_b.random(),
        &anim,
    );

    try std.testing.expect(anim.phase_count > 0);
    try std.testing.expectEqualDeep(expected.board, planned.board);
    try std.testing.expectEqual(expected.score, planned.score);
    try std.testing.expectEqual(expected.max_tile, planned.max_tile);
    try std.testing.expectEqual(expected.shuffles_left, planned.shuffles_left);
    try std.testing.expectEqual(expected.status, planned.status);
    try std.testing.expectEqualDeep(expected.stats, planned.stats);
}

test "intersection bomb is shown in anchor phase before first fall phase" {
    var base = types.GameState.init(cfg.defaultConfig());
    fillBaselineNoLines(&base.board);

    // Force ready 4x4 intersection of 4s.
    base.board[3][2] = types.Tile.number(4);
    base.board[3][3] = types.Tile.number(4);
    base.board[3][4] = types.Tile.number(4);
    base.board[3][5] = types.Tile.number(4);
    base.board[1][4] = types.Tile.number(4);
    base.board[2][4] = types.Tile.number(4);
    base.board[4][4] = types.Tile.number(4);

    // Adjacent non-bomb swap, board already contains line matches.
    base.board[0][0] = types.Tile.number(8);
    base.board[0][1] = types.Tile.number(16);

    var prng = std.Random.DefaultPrng.init(4243);
    var anim: animations.AnimationState = .{};
    anim.reset();

    _ = try turn_planner.planPlayerTurn(
        &base,
        std.testing.allocator,
        prng.random(),
        .{ .row = 0, .col = 0 },
        .{ .row = 0, .col = 1 },
        &anim,
    );

    var first_anchor_idx: ?usize = null;
    var first_fall_idx: ?usize = null;

    for (0..anim.phase_count) |i| {
        const phase = anim.phases[i];
        if (phase.kind == .fall_spawn and first_fall_idx == null) {
            var has_motion = false;
            var has_bomb_anchor = false;
            for (0..phase.track_count) |j| {
                const tr = phase.tracks[j];
                if (tr.tile.kind == .bomb and
                    @abs(tr.from_row - tr.to_row) < 0.0001 and
                    @abs(tr.from_col - tr.to_col) < 0.0001)
                {
                    has_bomb_anchor = true;
                }
                if (@abs(tr.from_row - tr.to_row) > 0.0001 or @abs(tr.from_col - tr.to_col) > 0.0001) {
                    has_motion = true;
                }
            }
            if (has_bomb_anchor and first_anchor_idx == null) first_anchor_idx = i;
            if (has_motion and first_fall_idx == null) first_fall_idx = i;
        }
    }

    try std.testing.expect(first_anchor_idx != null);
    try std.testing.expect(first_fall_idx != null);
    try std.testing.expect(first_anchor_idx.? < first_fall_idx.?);
}

test "regular merge has resolve phase before fall motion phase" {
    var base = types.GameState.init(cfg.defaultConfig());
    fillBaselineNoLines(&base.board);

    // guaranteed valid swap: 2 2 4 2 -> swap 4 and 2
    base.board[0][0] = types.Tile.number(2);
    base.board[0][1] = types.Tile.number(2);
    base.board[0][2] = types.Tile.number(4);
    base.board[0][3] = types.Tile.number(2);

    var prng = std.Random.DefaultPrng.init(4244);
    var anim: animations.AnimationState = .{};
    anim.reset();

    _ = try turn_planner.planPlayerTurn(
        &base,
        std.testing.allocator,
        prng.random(),
        .{ .row = 0, .col = 2 },
        .{ .row = 0, .col = 3 },
        &anim,
    );

    var match_idx: ?usize = null;
    var resolve_idx: ?usize = null;
    var fall_idx: ?usize = null;

    for (0..anim.phase_count) |i| {
        const phase = anim.phases[i];
        if (phase.kind == .match_flash and match_idx == null) {
            match_idx = i;
            continue;
        }
        if (phase.kind != .fall_spawn) continue;

        var has_motion = false;
        for (0..phase.track_count) |j| {
            const tr = phase.tracks[j];
            if (@abs(tr.from_row - tr.to_row) > 0.0001 or @abs(tr.from_col - tr.to_col) > 0.0001) {
                has_motion = true;
                break;
            }
        }

        if (!has_motion and resolve_idx == null) resolve_idx = i;
        if (has_motion and fall_idx == null) fall_idx = i;
    }

    try std.testing.expect(match_idx != null);
    try std.testing.expect(resolve_idx != null);
    try std.testing.expect(fall_idx != null);
    try std.testing.expect(match_idx.? < resolve_idx.?);
    try std.testing.expect(resolve_idx.? < fall_idx.?);
}
