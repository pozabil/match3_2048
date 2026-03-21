const std = @import("std");
const config = @import("config.zig");

pub const BOARD_ROWS: usize = 8;
pub const BOARD_COLS: usize = 8;

pub const TileKind = enum {
    number,
    bomb,
};

pub const Tile = struct {
    kind: TileKind,
    value: u32,
    id: u64,

    pub fn number(value: u32) Tile {
        return .{ .kind = .number, .value = value, .id = 0 };
    }

    pub fn numberWithId(value: u32, id: u64) Tile {
        return .{ .kind = .number, .value = value, .id = id };
    }

    pub fn bombWithValue(value: u32) Tile {
        std.debug.assert(value > 0);
        return .{ .kind = .bomb, .value = value, .id = 0 };
    }

    pub fn bombWithId(value: u32, id: u64) Tile {
        std.debug.assert(value > 0);
        return .{ .kind = .bomb, .value = value, .id = id };
    }
};

pub const Position = struct {
    row: usize,
    col: usize,
};

pub const Board = [BOARD_ROWS][BOARD_COLS]?Tile;

pub const MatchSource = enum {
    player,
    auto,
};

pub const GameStatus = enum {
    running,
    won,
    lost,
};

pub const Stats = struct {
    moves: u32 = 0,
    cascade_waves: u32 = 0,
    bomb_activations: u32 = 0,
};

pub const GameState = struct {
    cfg: config.GameConfig,
    board: Board,
    score: u64,
    max_tile: u32,
    shuffles_left: u8,
    shuffle_bonus_1024_awarded: bool,
    stats: Stats,
    status: GameStatus,
    input_locked: bool,
    next_tile_id: u64,

    pub fn init(cfg: config.GameConfig) GameState {
        return .{
            .cfg = cfg,
            .board = undefined,
            .score = 0,
            .max_tile = 0,
            .shuffles_left = cfg.initial_shuffles,
            .shuffle_bonus_1024_awarded = false,
            .stats = .{},
            .status = .running,
            .input_locked = false,
            .next_tile_id = 1,
        };
    }
};
