const std = @import("std");
const game = @import("match3_2048");

const config = game.core.config;
const how_to_play = game.ui.how_to_play;

test "clampPage keeps index within bounds" {
    try std.testing.expectEqual(@as(u8, 0), how_to_play.clampPage(0));
    try std.testing.expectEqual(@as(u8, 4), how_to_play.clampPage(4));
    try std.testing.expectEqual(@as(u8, 4), how_to_play.clampPage(12));
}

test "hitTestForScreen detects back button" {
    const back = how_to_play.backButtonRectForScreen(config.window_width, config.window_height);
    const hit = .{ .x = back.x + back.width / 2.0, .y = back.y + back.height / 2.0 };

    const action = how_to_play.hitTestForScreen(hit.x, hit.y, 2, config.window_width, config.window_height);
    try std.testing.expectEqual(how_to_play.Action.back, action.?);
}

test "hitTestForScreen disables prev on first page and next on last page" {
    const prev = how_to_play.prevButtonRectForScreen(config.window_width, config.window_height);
    const next = how_to_play.nextButtonRectForScreen(config.window_width, config.window_height);
    const prev_hit = .{ .x = prev.x + prev.width / 2.0, .y = prev.y + prev.height / 2.0 };
    const next_hit = .{ .x = next.x + next.width / 2.0, .y = next.y + next.height / 2.0 };

    try std.testing.expect(how_to_play.hitTestForScreen(prev_hit.x, prev_hit.y, 0, config.window_width, config.window_height) == null);
    try std.testing.expect(how_to_play.hitTestForScreen(next_hit.x, next_hit.y, how_to_play.PAGE_COUNT - 1, config.window_width, config.window_height) == null);
}

test "hitTestForScreen allows prev and next on middle page" {
    const prev = how_to_play.prevButtonRectForScreen(config.window_width, config.window_height);
    const next = how_to_play.nextButtonRectForScreen(config.window_width, config.window_height);
    const prev_hit = .{ .x = prev.x + prev.width / 2.0, .y = prev.y + prev.height / 2.0 };
    const next_hit = .{ .x = next.x + next.width / 2.0, .y = next.y + next.height / 2.0 };

    const prev_action = how_to_play.hitTestForScreen(prev_hit.x, prev_hit.y, 2, config.window_width, config.window_height);
    const next_action = how_to_play.hitTestForScreen(next_hit.x, next_hit.y, 2, config.window_width, config.window_height);

    try std.testing.expectEqual(how_to_play.Action.prev, prev_action.?);
    try std.testing.expectEqual(how_to_play.Action.next, next_action.?);
}

test "hitTestForScreen clamps out-of-range page index" {
    const prev = how_to_play.prevButtonRectForScreen(config.window_width, config.window_height);
    const next = how_to_play.nextButtonRectForScreen(config.window_width, config.window_height);
    const prev_hit = .{ .x = prev.x + prev.width / 2.0, .y = prev.y + prev.height / 2.0 };
    const next_hit = .{ .x = next.x + next.width / 2.0, .y = next.y + next.height / 2.0 };

    // Out-of-range index clamps to last page, where next is disabled and prev is enabled.
    try std.testing.expectEqual(how_to_play.Action.prev, how_to_play.hitTestForScreen(prev_hit.x, prev_hit.y, 250, config.window_width, config.window_height).?);
    try std.testing.expect(how_to_play.hitTestForScreen(next_hit.x, next_hit.y, 250, config.window_width, config.window_height) == null);
}
