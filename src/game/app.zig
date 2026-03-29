const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");
const runtime_mod = @import("runtime.zig");
const board_renderer = @import("../ui/board_renderer.zig");
const hud = @import("../ui/hud.zig");
const overlay = @import("../ui/overlay.zig");
const restart_confirm = @import("../ui/restart_confirm.zig");
const menu_ui = @import("../ui/menu.zig");
const how_to_play = @import("../ui/how_to_play.zig");
const audio_synth = @import("../audio/synth.zig");
extern fn emscripten_set_main_loop_arg(
    func: *const fn (?*anyopaque) callconv(.c) void,
    arg: ?*anyopaque,
    fps: c_int,
    simulate_infinite_loop: c_int,
) void;

// Always initialized via initWithAudioOptions() before emscripten_set_main_loop_arg.
// deinit() is intentionally never called on the web path: page lifetime equals
// game lifetime, and Emscripten unloads the heap on page close anyway.
var web_runtime_storage: runtime_mod.Runtime = undefined;

fn frame(runtime: *runtime_mod.Runtime) void {
    runtime.tick();

    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(rl.Color.init(250, 248, 239, 255));
    board_renderer.drawBoard(&runtime.state, runtime.selected, &runtime.anim);
    hud.drawHUD(&runtime.state, runtime.elapsed_seconds);
    overlay.drawEndOverlay(&runtime.state, runtime.elapsed_seconds);
    restart_confirm.draw(runtime.confirm_action, runtime.confirm_open, runtime.state.shuffles_left);
    menu_ui.draw(runtime.menu_open, runtime.best_record, runtime.sound_enabled);
    how_to_play.draw(runtime.how_to_play_open, runtime.how_to_play_page);
}

fn webFrame(ctx: ?*anyopaque) callconv(.c) void {
    const runtime_ptr: *runtime_mod.Runtime = @ptrCast(@alignCast(ctx.?));
    frame(runtime_ptr);
}

pub fn run(allocator: std.mem.Allocator) !void {
    const is_web = builtin.target.os.tag == .emscripten;

    rl.initWindow(900, 720, "match3_2048");
    defer if (!is_web) rl.closeWindow();
    rl.setExitKey(.null);
    if (!is_web) {
        rl.setTargetFPS(60);
    }

    rl.setAudioStreamBufferSizeDefault(@as(i32, @intCast(audio_synth.BUFFER_FRAMES)));
    rl.initAudioDevice();
    defer {
        if (rl.isAudioDeviceReady()) {
            rl.closeAudioDevice();
        }
    }

    if (is_web) {
        web_runtime_storage = runtime_mod.Runtime.initWithAudioOptions(
            allocator,
            @as(u64, @intCast(std.time.milliTimestamp())),
            .{},
        );

        emscripten_set_main_loop_arg(webFrame, &web_runtime_storage, 0, 1);
        unreachable;
    } else {
        var runtime = runtime_mod.Runtime.init(allocator, @as(u64, @intCast(std.time.milliTimestamp())));
        defer runtime.deinit();

        while (!rl.windowShouldClose()) {
            frame(&runtime);
        }

        // Desktop autosave: persist on clean exit.
        runtime.saveToStorage();
    }
}
