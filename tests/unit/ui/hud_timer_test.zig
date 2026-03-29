const std = @import("std");
const game = @import("match3_2048");

const hud = game.ui.hud;

test "elapsed clock floors fractional seconds" {
    const c = hud.elapsedClock(125.99);
    try std.testing.expectEqual(@as(u64, 0), c.hours);
    try std.testing.expectEqual(@as(u64, 2), c.minutes);
    try std.testing.expectEqual(@as(u64, 5), c.seconds);
}

test "elapsed clock clamps negative to zero" {
    const c = hud.elapsedClock(-10.0);
    try std.testing.expectEqual(@as(u64, 0), c.hours);
    try std.testing.expectEqual(@as(u64, 0), c.minutes);
    try std.testing.expectEqual(@as(u64, 0), c.seconds);
}

test "elapsed clock includes hours" {
    const c = hud.elapsedClock(3661.0);
    try std.testing.expectEqual(@as(u64, 1), c.hours);
    try std.testing.expectEqual(@as(u64, 1), c.minutes);
    try std.testing.expectEqual(@as(u64, 1), c.seconds);
}

test "shuffle button hit-test for explicit screen width" {
    const center_hit = hud.hitTestShuffleButtonForScreen(820.0, 28.0, 900);
    try std.testing.expect(center_hit);

    const miss = hud.hitTestShuffleButtonForScreen(600.0, 28.0, 900);
    try std.testing.expect(!miss);
}
