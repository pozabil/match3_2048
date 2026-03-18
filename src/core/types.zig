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

    pub fn number(value: u32) Tile {
        return .{ .kind = .number, .value = value };
    }

    pub fn bomb() Tile {
        return .{ .kind = .bomb, .value = 0 };
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
    stats: Stats,
    status: GameStatus,
    input_locked: bool,

    pub fn init(cfg: config.GameConfig) GameState {
        return .{
            .cfg = cfg,
            .board = undefined,
            .score = 0,
            .max_tile = 0,
            .shuffles_left = cfg.initial_shuffles,
            .stats = .{},
            .status = .running,
            .input_locked = false,
        };
    }
};
