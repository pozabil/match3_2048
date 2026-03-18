const std = @import("std");
const rl = @import("raylib");
const runtime_mod = @import("runtime.zig");
const board_renderer = @import("../ui/board_renderer.zig");
const hud = @import("../ui/hud.zig");
const overlay = @import("../ui/overlay.zig");
const restart_confirm = @import("../ui/restart_confirm.zig");
const audio_synth = @import("../audio/synth.zig");

pub fn run(allocator: std.mem.Allocator) !void {
    rl.initWindow(900, 720, "match3_2048");
    defer rl.closeWindow();
    rl.setExitKey(.null);
    rl.setTargetFPS(60);

    rl.setAudioStreamBufferSizeDefault(@as(i32, @intCast(audio_synth.BUFFER_FRAMES)));
    rl.initAudioDevice();
    defer {
        if (rl.isAudioDeviceReady()) {
            rl.closeAudioDevice();
        }
    }

    var runtime = runtime_mod.Runtime.init(allocator, @as(u64, @intCast(std.time.milliTimestamp())));
    defer runtime.deinit();

    while (!rl.windowShouldClose()) {
        runtime.tick();

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.init(250, 248, 239, 255));
        board_renderer.drawBoard(&runtime.state, runtime.selected, &runtime.anim);
        hud.drawHUD(&runtime.state);
        overlay.drawEndOverlay(&runtime.state);
        restart_confirm.draw(runtime.confirm_action, runtime.confirm_open, runtime.state.shuffles_left);
    }
}
