const std = @import("std");
const game = @import("match3_2048");

const runtime_mod = game.game.runtime;
const restart_confirm = game.ui.restart_confirm;
const menu = game.ui.menu;
const how_to_play = game.ui.how_to_play;

fn makeRuntime(seed: u64) runtime_mod.Runtime {
    return runtime_mod.Runtime.initWithAudioOptions(
        std.testing.allocator,
        seed,
        .{ .testing_enabled_without_device = true },
    );
}

test "disabled shuffle request triggers invalid feedback without confirm" {
    var runtime = makeRuntime(1211);
    defer runtime.deinit();

    runtime.state.shuffles_left = 0;
    runtime.debugHandleManualShuffleRequest();

    try std.testing.expect(!runtime.confirm_open);
    try std.testing.expectEqual(@as(u32, 1), runtime.audioTriggerCount(.invalid));
}

test "enabled shuffle request opens shuffle confirm" {
    var runtime = makeRuntime(1212);
    defer runtime.deinit();

    runtime.state.shuffles_left = 1;
    runtime.debugHandleManualShuffleRequest();

    try std.testing.expect(runtime.confirm_open);
    try std.testing.expectEqual(restart_confirm.Action.shuffle, runtime.confirm_action);
}

test "menu sound toggle updates runtime and synth mute state" {
    var runtime = makeRuntime(1213);
    defer runtime.deinit();

    try std.testing.expect(runtime.sound_enabled);
    try std.testing.expect(!runtime.synth.isMuted());

    runtime.debugApplyMenuChoice(menu.Choice.toggle_sound);
    try std.testing.expect(!runtime.sound_enabled);
    try std.testing.expect(runtime.synth.isMuted());

    runtime.debugApplyMenuChoice(menu.Choice.toggle_sound);
    try std.testing.expect(runtime.sound_enabled);
    try std.testing.expect(!runtime.synth.isMuted());
}

test "how to play opens from menu action and supports page actions" {
    var runtime = makeRuntime(1214);
    defer runtime.deinit();

    runtime.menu_open = true;
    runtime.debugApplyMenuChoice(menu.Choice.how_to_play);
    try std.testing.expect(runtime.menu_open);
    try std.testing.expect(runtime.how_to_play_open);

    runtime.debugApplyHowToPlayAction(how_to_play.Action.next);
    try std.testing.expectEqual(@as(u8, 1), runtime.how_to_play_page);

    runtime.debugApplyHowToPlayAction(how_to_play.Action.back);
    try std.testing.expect(!runtime.how_to_play_open);
    try std.testing.expect(runtime.menu_open);
}

test "help shortcut from board closes back to board" {
    var runtime = makeRuntime(1215);
    defer runtime.deinit();

    runtime.menu_open = false;
    runtime.how_to_play_open = false;

    runtime.debugOpenHowToPlay();
    try std.testing.expect(runtime.how_to_play_open);
    try std.testing.expect(!runtime.menu_open);

    runtime.debugDismissHowToPlay();
    try std.testing.expect(!runtime.how_to_play_open);
    try std.testing.expect(!runtime.menu_open);
}

test "help shortcut from menu closes back to menu" {
    var runtime = makeRuntime(1216);
    defer runtime.deinit();

    runtime.menu_open = true;
    runtime.how_to_play_open = false;

    runtime.debugOpenHowToPlay();
    try std.testing.expect(runtime.how_to_play_open);
    try std.testing.expect(runtime.menu_open);

    runtime.debugDismissHowToPlay();
    try std.testing.expect(!runtime.how_to_play_open);
    try std.testing.expect(runtime.menu_open);
}

test "new game request opens restart confirm" {
    var runtime = makeRuntime(1217);
    defer runtime.deinit();

    runtime.menu_open = true;
    runtime.how_to_play_open = true;
    runtime.debugHandleNewGameRequest();

    try std.testing.expect(runtime.confirm_open);
    try std.testing.expectEqual(restart_confirm.Action.restart, runtime.confirm_action);
    try std.testing.expect(!runtime.menu_open);
    try std.testing.expect(!runtime.how_to_play_open);
}
