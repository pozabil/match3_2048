const rl = @import("raylib");

pub fn pointInRect(x: f32, y: f32, rect: rl.Rectangle) bool {
    return x >= rect.x and x <= rect.x + rect.width and y >= rect.y and y <= rect.y + rect.height;
}
