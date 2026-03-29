pub const core = struct {
    pub const config = @import("core/config.zig");
    pub const types = @import("core/types.zig");
    pub const utils = @import("core/utils.zig");
    pub const match_lines = @import("core/match_lines.zig");
    pub const match_groups = @import("core/match_groups.zig");
    pub const merge_rules = @import("core/merge_rules.zig");
    pub const bomb_pool_reduce = @import("core/bomb_pool_reduce.zig");
    pub const engine = @import("core/engine.zig");
};

pub const game = struct {
    pub const runtime = @import("game/runtime.zig");
    pub const app = @import("game/app.zig");
    pub const turn_planner = @import("game/turn_planner.zig");
};

pub const ui = struct {
    pub const board_renderer = @import("ui/board_renderer.zig");
    pub const hud = @import("ui/hud.zig");
    pub const overlay = @import("ui/overlay.zig");
    pub const animations = @import("ui/animations.zig");
    pub const restart_confirm = @import("ui/restart_confirm.zig");
    pub const menu = @import("ui/menu.zig");
    pub const how_to_play = @import("ui/how_to_play.zig");
    pub const ui_util = @import("ui/ui_util.zig");
};

pub const audio = struct {
    pub const synth = @import("audio/synth.zig");
};

pub const persistence = struct {
    pub const save_data = @import("persistence/save_data.zig");
    // storage is intentionally internal — use save_data for serialization
};
