const builtin = @import("builtin");
const rl = @import("raylib");
const IS_WEB = builtin.target.os.tag == .emscripten;

pub fn pointInRect(x: f32, y: f32, rect: rl.Rectangle) bool {
    return x >= rect.x and x <= rect.x + rect.width and y >= rect.y and y <= rect.y + rect.height;
}

pub fn logicalPointerPosition(raw: rl.Vector2) rl.Vector2 {
    if (!IS_WEB) return raw;

    const screen_w = @as(f32, @floatFromInt(@max(rl.getScreenWidth(), 1)));
    const screen_h = @as(f32, @floatFromInt(@max(rl.getScreenHeight(), 1)));
    const render_w = @as(f32, @floatFromInt(@max(rl.getRenderWidth(), 1)));
    const render_h = @as(f32, @floatFromInt(@max(rl.getRenderHeight(), 1)));
    return .{
        .x = raw.x * (screen_w / render_w),
        .y = raw.y * (screen_h / render_h),
    };
}
