const std = @import("std");
const game = @import("match3_2048");

const types = game.core.types;
const runtime_mod = game.game.runtime;
const overlay = game.ui.overlay;

fn makeRuntime(seed: u64) runtime_mod.Runtime {
    return runtime_mod.Runtime.initWithAudioOptions(
        std.testing.allocator,
        seed,
        .{ .force_init_fail = true },
    );
}

test "end overlay mouse click on New Game resets ended run" {
    var runtime = makeRuntime(991);
    defer runtime.deinit();

    runtime.state.status = .lost;
    runtime.elapsed_seconds = 123.0;

    const btn = overlay.newGameButtonRectForScreen(900);
    const hit = .{
        .x = btn.x + (btn.width / 2.0),
        .y = btn.y + (btn.height / 2.0),
    };

    runtime.debugHandleEndOverlayMouseClick(hit);

    try std.testing.expectEqual(types.GameStatus.running, runtime.state.status);
    try std.testing.expectEqual(@as(f64, 0.0), runtime.elapsed_seconds);
}

test "end overlay mouse click outside New Game does not reset" {
    var runtime = makeRuntime(992);
    defer runtime.deinit();

    runtime.state.status = .lost;
    runtime.elapsed_seconds = 77.0;

    const btn = overlay.newGameButtonRectForScreen(900);
    const miss = .{ .x = btn.x - 10.0, .y = btn.y - 10.0 };

    runtime.debugHandleEndOverlayMouseClick(miss);

    try std.testing.expectEqual(types.GameStatus.lost, runtime.state.status);
    try std.testing.expectEqual(@as(f64, 77.0), runtime.elapsed_seconds);
}

test "end overlay touch resets only on release over New Game" {
    var runtime = makeRuntime(993);
    defer runtime.deinit();

    runtime.state.status = .lost;
    runtime.elapsed_seconds = 45.0;

    const btn = overlay.newGameButtonRectForScreen(900);
    const hit = .{
        .x = btn.x + (btn.width / 2.0),
        .y = btn.y + (btn.height / 2.0),
    };

    const consumed_press = runtime.debugHandleEndOverlayTouch(true, hit, 10.0);
    try std.testing.expect(!consumed_press);
    try std.testing.expectEqual(types.GameStatus.lost, runtime.state.status);

    const consumed_release = runtime.debugHandleEndOverlayTouch(false, hit, 10.1);
    try std.testing.expect(consumed_release);
    try std.testing.expectEqual(types.GameStatus.running, runtime.state.status);
}

test "end overlay touch release outside New Game does not reset" {
    var runtime = makeRuntime(994);
    defer runtime.deinit();

    runtime.state.status = .lost;
    runtime.elapsed_seconds = 66.0;

    const btn = overlay.newGameButtonRectForScreen(900);
    const start_inside = .{
        .x = btn.x + (btn.width / 2.0),
        .y = btn.y + (btn.height / 2.0),
    };
    const release_outside = .{
        .x = btn.x - 5.0,
        .y = btn.y - 5.0,
    };

    const consumed_press = runtime.debugHandleEndOverlayTouch(true, start_inside, 20.0);
    try std.testing.expect(!consumed_press);
    try std.testing.expectEqual(types.GameStatus.lost, runtime.state.status);

    const consumed_release = runtime.debugHandleEndOverlayTouch(false, release_outside, 20.1);
    try std.testing.expect(consumed_release);
    try std.testing.expectEqual(types.GameStatus.lost, runtime.state.status);
    try std.testing.expectEqual(@as(f64, 66.0), runtime.elapsed_seconds);
}

test "overlay New Game hit-test for explicit screen width" {
    const btn = overlay.newGameButtonRectForScreen(900);
    const inside = .{
        .x = btn.x + 1.0,
        .y = btn.y + 1.0,
    };
    const outside = .{
        .x = btn.x - 1.0,
        .y = btn.y - 1.0,
    };

    try std.testing.expect(overlay.hitTestNewGameButtonForScreen(inside.x, inside.y, 900));
    try std.testing.expect(!overlay.hitTestNewGameButtonForScreen(outside.x, outside.y, 900));
}
