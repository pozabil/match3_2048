const std = @import("std");
const rl = @import("raylib");
const types = @import("../core/types.zig");
const hud = @import("hud.zig");

pub fn drawEndOverlay(state: *const types.GameState, elapsed_seconds: f64) void {
    if (state.status == .running) return;

    const scr_w = rl.getScreenWidth();
    const scr_h = rl.getScreenHeight();
    const ink = rl.Color.init(119, 110, 101, 255);
    const panel = rl.Color.init(238, 228, 218, 235);

    rl.drawRectangle(0, 0, scr_w, scr_h, panel);

    const title = if (state.status == .won) "You Win!" else "Game Over";
    rl.drawText(title, 310, 170, 64, ink);

    var buf: [128]u8 = undefined;

    const score = std.fmt.bufPrintZ(&buf, "Final score: {d}", .{state.score}) catch "score";
    rl.drawText(score, 300, 270, 30, ink);

    const moves = std.fmt.bufPrintZ(&buf, "Moves: {d}", .{state.stats.moves}) catch "moves";
    rl.drawText(moves, 300, 312, 26, ink);

    const clock = hud.elapsedClock(elapsed_seconds);
    const timer = if (clock.hours > 0)
        std.fmt.bufPrintZ(
            &buf,
            "Time: {d:0>2}:{d:0>2}:{d:0>2}",
            .{ clock.hours, clock.minutes, clock.seconds },
        ) catch "time"
    else
        std.fmt.bufPrintZ(
            &buf,
            "Time: {d:0>2}:{d:0>2}",
            .{ clock.minutes, clock.seconds },
        ) catch "time";
    rl.drawText(timer, 300, 348, 26, ink);

    const max_tile = std.fmt.bufPrintZ(&buf, "Max tile: {d}", .{state.max_tile}) catch "max";
    rl.drawText(max_tile, 300, 384, 26, ink);

    const waves = std.fmt.bufPrintZ(&buf, "Cascade waves: {d}", .{state.stats.cascade_waves}) catch "waves";
    rl.drawText(waves, 300, 420, 26, ink);

    const bombs = std.fmt.bufPrintZ(&buf, "Bomb activations: {d}", .{state.stats.bomb_activations}) catch "bombs";
    rl.drawText(bombs, 300, 456, 26, ink);

    rl.drawText("Use Menu to start a new game", 300, 526, 24, ink);
}
