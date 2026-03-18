const std = @import("std");
const game = @import("match3_2048");

const types = game.core.types;
const anim_mod = game.ui.animations;

test "animation presentation advances and clears" {
    var anim: anim_mod.AnimationState = .{};
    anim.reset();

    var board: types.Board = undefined;
    for (0..types.BOARD_ROWS) |r| {
        for (0..types.BOARD_COLS) |c| {
            board[r][c] = null;
        }
    }

    const p1 = anim_mod.Phase.init(.swap, 0.1, board);
    const p2 = anim_mod.Phase.init(.fall_spawn, 0.1, board);
    try anim.appendPhase(p1);
    try anim.appendPhase(p2);

    try std.testing.expect(anim.isPresenting());

    anim.tick(0.05);
    try std.testing.expect(anim.isPresenting());
    try std.testing.expect(anim.phaseProgress() > 0.0);

    anim.tick(0.07);
    try std.testing.expect(anim.isPresenting());

    anim.tick(0.20);
    try std.testing.expect(!anim.isPresenting());
    try std.testing.expectEqual(@as(usize, 0), anim.phase_count);
}
