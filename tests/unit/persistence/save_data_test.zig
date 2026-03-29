const std = @import("std");
const game = @import("match3_2048");

const types = game.core.types;
const config = game.core.config;
const save_data = game.persistence.save_data;

test "autosave round-trips board, score, and PRNG state" {
    var state = types.GameState.init(config.defaultConfig());
    state.board[0][0] = types.Tile.numberWithId(4, 7);
    state.board[2][3] = types.Tile.bombWithId(8, 42);
    state.score = 1234;
    state.max_tile = 128;
    state.shuffles_left = 2;
    state.shuffle_bonus_1024_awarded = true;
    state.stats = .{ .moves = 10, .cascade_waves = 3, .bomb_activations = 1 };
    state.status = .running;
    state.next_tile_id = 99;

    const prng_s: [4]u64 = .{ 1, 2, 3, 4 };
    const elapsed: f64 = 72.5;

    // Serialize
    const auto = save_data.serializeToAutosave(&state, elapsed, prng_s);
    const save_file = save_data.SaveFile{
        .autosave = auto,
        .settings = .{ .sound_enabled = false },
    };

    const allocator = std.testing.allocator;
    const json = try save_data.writeToJson(allocator, save_file);
    defer allocator.free(json);

    // Deserialize
    const parsed = try save_data.readFromJson(allocator, json);
    defer parsed.deinit();

    const restored_auto = parsed.value.autosave.?;
    try std.testing.expect(parsed.value.settings != null);
    try std.testing.expect(!parsed.value.settings.?.sound_enabled);
    var out_state = types.GameState.init(config.defaultConfig());
    var out_elapsed: f64 = 0.0;
    var out_prng: [4]u64 = .{ 0, 0, 0, 0 };

    save_data.deserializeAutosave(restored_auto, &out_state, &out_elapsed, &out_prng);

    try std.testing.expectEqual(state.score, out_state.score);
    try std.testing.expectEqual(state.max_tile, out_state.max_tile);
    try std.testing.expectEqual(state.shuffles_left, out_state.shuffles_left);
    try std.testing.expectEqual(state.shuffle_bonus_1024_awarded, out_state.shuffle_bonus_1024_awarded);
    try std.testing.expectEqual(state.stats.moves, out_state.stats.moves);
    try std.testing.expectEqual(state.stats.cascade_waves, out_state.stats.cascade_waves);
    try std.testing.expectEqual(state.stats.bomb_activations, out_state.stats.bomb_activations);
    try std.testing.expectEqual(state.status, out_state.status);
    try std.testing.expectEqual(state.next_tile_id, out_state.next_tile_id);
    try std.testing.expectApproxEqAbs(elapsed, out_elapsed, 0.001);
    try std.testing.expectEqualSlices(u64, &prng_s, &out_prng);

    // Spot-check two board cells
    const t00 = out_state.board[0][0].?;
    try std.testing.expectEqual(types.TileKind.number, t00.kind);
    try std.testing.expectEqual(@as(u32, 4), t00.value);
    try std.testing.expectEqual(@as(u64, 7), t00.id);

    const t23 = out_state.board[2][3].?;
    try std.testing.expectEqual(types.TileKind.bomb, t23.kind);
    try std.testing.expectEqual(@as(u32, 8), t23.value);
    try std.testing.expectEqual(@as(u64, 42), t23.id);

    // All other cells should be null
    try std.testing.expect(out_state.board[0][1] == null);
}

test "isBetterRecord: new beats old by score" {
    const old = save_data.RecordJson{
        .score = 1000,
        .max_tile = 64,
        .moves = 50,
        .cascade_waves = 5,
        .bomb_activations = 0,
        .elapsed_seconds = 120.0,
        .status = .won,
    };
    const better = save_data.RecordJson{
        .score = 2000,
        .max_tile = 128,
        .moves = 80,
        .cascade_waves = 10,
        .bomb_activations = 1,
        .elapsed_seconds = 200.0,
        .status = .won,
    };
    const worse = save_data.RecordJson{
        .score = 500,
        .max_tile = 32,
        .moves = 30,
        .cascade_waves = 2,
        .bomb_activations = 0,
        .elapsed_seconds = 60.0,
        .status = .lost,
    };

    try std.testing.expect(save_data.isBetterRecord(better, old));
    try std.testing.expect(!save_data.isBetterRecord(worse, old));
    try std.testing.expect(save_data.isBetterRecord(worse, null)); // null → always better
}

test "validateAutosave: valid data passes" {
    var state = types.GameState.init(config.defaultConfig());
    state.next_tile_id = 1;
    const auto = save_data.serializeToAutosave(&state, 10.0, .{ 1, 2, 3, 4 });
    try std.testing.expect(save_data.validateAutosave(auto));
}

test "validateAutosave: NaN elapsed_seconds rejected" {
    var state = types.GameState.init(config.defaultConfig());
    state.next_tile_id = 1;
    var auto = save_data.serializeToAutosave(&state, 0.0, .{ 1, 2, 3, 4 });
    auto.elapsed_seconds = std.math.nan(f64);
    try std.testing.expect(!save_data.validateAutosave(auto));
}

test "validateAutosave: negative elapsed_seconds rejected" {
    var state = types.GameState.init(config.defaultConfig());
    state.next_tile_id = 1;
    var auto = save_data.serializeToAutosave(&state, 0.0, .{ 1, 2, 3, 4 });
    auto.elapsed_seconds = -1.0;
    try std.testing.expect(!save_data.validateAutosave(auto));
}

test "validateAutosave: all-zero prng_state rejected" {
    var state = types.GameState.init(config.defaultConfig());
    state.next_tile_id = 1;
    const auto = save_data.serializeToAutosave(&state, 0.0, .{ 0, 0, 0, 0 });
    try std.testing.expect(!save_data.validateAutosave(auto));
}

test "validateAutosave: next_tile_id 0 rejected" {
    var state = types.GameState.init(config.defaultConfig());
    state.next_tile_id = 0;
    const auto = save_data.serializeToAutosave(&state, 0.0, .{ 1, 2, 3, 4 });
    try std.testing.expect(!save_data.validateAutosave(auto));
}

test "validateAutosave: tile with value 0 rejected" {
    var state = types.GameState.init(config.defaultConfig());
    state.next_tile_id = 1;
    var auto = save_data.serializeToAutosave(&state, 0.0, .{ 1, 2, 3, 4 });
    auto.board[0] = save_data.TileJson{ .kind = .number, .value = 0, .id = 1 };
    try std.testing.expect(!save_data.validateAutosave(auto));
}

test "forward compatibility: unknown JSON fields are ignored" {
    const json =
        \\{"record":null,"autosave":null,"future_field":"ignored","another":42}
    ;
    const allocator = std.testing.allocator;
    const parsed = try save_data.readFromJson(allocator, json);
    defer parsed.deinit();
    try std.testing.expect(parsed.value.record == null);
    try std.testing.expect(parsed.value.autosave == null);
    try std.testing.expect(parsed.value.settings == null);
}
