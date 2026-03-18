const std = @import("std");
const types = @import("types.zig");
const config = @import("config.zig");

pub fn clearBoard(board: *types.Board) void {
    for (board, 0..) |*row, r| {
        _ = r;
        for (row, 0..) |*cell, c| {
            _ = c;
            cell.* = null;
        }
    }
}

pub fn cloneBoard(board: types.Board) types.Board {
    return board;
}

pub fn isAdjacent(a: types.Position, b: types.Position) bool {
    const dr = if (a.row > b.row) a.row - b.row else b.row - a.row;
    const dc = if (a.col > b.col) a.col - b.col else b.col - a.col;
    return (dr == 1 and dc == 0) or (dr == 0 and dc == 1);
}

pub fn swap(board: *types.Board, a: types.Position, b: types.Position) void {
    const t = board[a.row][a.col];
    board[a.row][a.col] = board[b.row][b.col];
    board[b.row][b.col] = t;
}

pub fn randomSpawnTile(rng: std.Random, cfg: config.GameConfig) types.Tile {
    return randomSpawnTileWithWeights(
        rng,
        cfg.spawn_two_weight,
        cfg.spawn_four_weight,
        cfg.spawn_eight_weight,
    );
}

pub fn randomSpawnTileWithTier(rng: std.Random, cfg: config.GameConfig, high_tier: bool) types.Tile {
    if (high_tier) {
        return randomSpawnTileWithWeights(
            rng,
            cfg.high_tier_spawn_two_weight,
            cfg.high_tier_spawn_four_weight,
            cfg.high_tier_spawn_eight_weight,
        );
    }
    return randomSpawnTile(rng, cfg);
}

pub fn randomStartTile(rng: std.Random, cfg: config.GameConfig) types.Tile {
    return randomSpawnTileWithWeights(rng, cfg.start_spawn_two_weight, cfg.start_spawn_four_weight, 0);
}

pub fn randomSpawnTileWithWeights(rng: std.Random, two_weight: u8, four_weight: u8, eight_weight: u8) types.Tile {
    const total: u16 = @as(u16, two_weight) + @as(u16, four_weight) + @as(u16, eight_weight);
    std.debug.assert(total > 0);
    const n: u16 = rng.uintLessThan(u16, total);
    if (n < two_weight) return types.Tile.number(2);
    if (n < @as(u16, two_weight) + @as(u16, four_weight)) return types.Tile.number(4);
    return types.Tile.number(8);
}

pub fn boardHasAnyBomb(board: *const types.Board) bool {
    for (board) |row| {
        for (row) |cell| {
            if (cell) |t| {
                if (t.kind == .bomb) return true;
            }
        }
    }
    return false;
}

pub fn setMaxTile(state: *types.GameState) void {
    var max_v: u32 = 0;
    for (state.board) |row| {
        for (row) |cell| {
            if (cell) |t| {
                if (t.kind == .number and t.value > max_v) {
                    max_v = t.value;
                }
            }
        }
    }
    state.max_tile = max_v;
}
