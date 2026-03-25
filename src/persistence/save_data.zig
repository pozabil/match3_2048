const std = @import("std");
const types = @import("../core/types.zig");
const config = @import("../core/config.zig");

const BOARD_SIZE = types.BOARD_ROWS * types.BOARD_COLS;

// ── JSON-friendly structs ─────────────────────────────────────────────────────

pub const TileJson = struct {
    kind: types.TileKind,
    value: u32,
    id: u64,
};

/// Single best-result record. All fields must be present when stored.
pub const RecordJson = struct {
    score: u64,
    max_tile: u32,
    moves: u32,
    cascade_waves: u32,
    bomb_activations: u32,
    elapsed_seconds: f64,
    status: types.GameStatus,
};

/// Full game state snapshot for mid-session restore.
pub const AutosaveJson = struct {
    /// Flat row-major board: [row * BOARD_COLS + col].
    board: [BOARD_SIZE]?TileJson,
    score: u64,
    max_tile: u32,
    shuffles_left: u8,
    shuffle_bonus_1024_awarded: bool,
    stats: types.Stats,
    status: types.GameStatus,
    next_tile_id: u64,
    elapsed_seconds: f64,
    /// Xoshiro256 PRNG state words (runtime.prng.s).
    prng_state: [4]u64,
};

/// Top-level save document. Both fields are optional for forward compatibility.
pub const SaveFile = struct {
    record: ?RecordJson = null,
    autosave: ?AutosaveJson = null,
};

// ── Serialize ─────────────────────────────────────────────────────────────────

pub fn serializeToAutosave(
    state: *const types.GameState,
    elapsed: f64,
    prng_s: [4]u64,
) AutosaveJson {
    var board: [BOARD_SIZE]?TileJson = undefined;
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            const idx = r * types.BOARD_COLS + c;
            board[idx] = if (state.board[r][c]) |t|
                TileJson{ .kind = t.kind, .value = t.value, .id = t.id }
            else
                null;
        }
    }
    return .{
        .board = board,
        .score = state.score,
        .max_tile = state.max_tile,
        .shuffles_left = state.shuffles_left,
        .shuffle_bonus_1024_awarded = state.shuffle_bonus_1024_awarded,
        .stats = state.stats,
        .status = state.status,
        .next_tile_id = state.next_tile_id,
        .elapsed_seconds = elapsed,
        .prng_state = prng_s,
    };
}

pub fn gameStateToRecord(state: *const types.GameState, elapsed: f64) RecordJson {
    return .{
        .score = state.score,
        .max_tile = state.max_tile,
        .moves = state.stats.moves,
        .cascade_waves = state.stats.cascade_waves,
        .bomb_activations = state.stats.bomb_activations,
        .elapsed_seconds = elapsed,
        .status = state.status,
    };
}

// ── Deserialize ───────────────────────────────────────────────────────────────

pub fn deserializeAutosave(
    json: AutosaveJson,
    state: *types.GameState,
    elapsed: *f64,
    prng_s: *[4]u64,
) void {
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            const idx = r * types.BOARD_COLS + c;
            state.board[r][c] = if (json.board[idx]) |t|
                types.Tile{ .kind = t.kind, .value = t.value, .id = t.id }
            else
                null;
        }
    }
    state.score = json.score;
    state.max_tile = json.max_tile;
    state.shuffles_left = json.shuffles_left;
    state.shuffle_bonus_1024_awarded = json.shuffle_bonus_1024_awarded;
    state.stats = json.stats;
    state.status = json.status;
    state.next_tile_id = json.next_tile_id;
    elapsed.* = json.elapsed_seconds;
    prng_s.* = json.prng_state;
}

// ── Validation ────────────────────────────────────────────────────────────────

/// Returns true when the autosave is semantically valid and safe to apply.
/// Rejects NaN/Inf timers, degenerate PRNG state, zero tile IDs, and zero tile values.
pub fn validateAutosave(auto: AutosaveJson) bool {
    if (!std.math.isFinite(auto.elapsed_seconds) or auto.elapsed_seconds < 0.0) return false;
    if (auto.next_tile_id == 0) return false;
    // All-zero xoshiro256 state is degenerate — produces a constant sequence.
    var all_zero = true;
    for (auto.prng_state) |w| {
        if (w != 0) {
            all_zero = false;
            break;
        }
    }
    if (all_zero) return false;
    for (auto.board) |cell| {
        if (cell) |t| {
            if (t.value == 0) return false;
        }
    }
    return true;
}

// ── Comparison ────────────────────────────────────────────────────────────────

/// Returns true when `new` is a better result than `old` (or old is absent).
pub fn isBetterRecord(new: RecordJson, old: ?RecordJson) bool {
    const prev = old orelse return true;
    return new.score > prev.score;
}

// ── JSON I/O ──────────────────────────────────────────────────────────────────

/// Serialize a SaveFile to a heap-allocated JSON string. Caller owns the slice.
pub fn writeToJson(allocator: std.mem.Allocator, save_file: SaveFile) ![]u8 {
    return std.json.Stringify.valueAlloc(allocator, save_file, .{});
}

/// Parse a SaveFile from a JSON slice. Caller must call result.deinit().
pub fn readFromJson(
    allocator: std.mem.Allocator,
    json: []const u8,
) !std.json.Parsed(SaveFile) {
    return std.json.parseFromSlice(SaveFile, allocator, json, .{
        .ignore_unknown_fields = true,
    });
}
