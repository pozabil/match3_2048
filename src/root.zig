pub const core = struct {
    pub const config = @import("core/config.zig");
    pub const types = @import("core/types.zig");
    pub const utils = @import("core/utils.zig");
    pub const board_init = @import("core/board_init.zig");
    pub const move_scan = @import("core/move_scan.zig");
    pub const player_move = @import("core/player_move.zig");
    pub const match_lines = @import("core/match_lines.zig");
    pub const match_groups = @import("core/match_groups.zig");
    pub const merge_rules = @import("core/merge_rules.zig");
    pub const bomb_rules = @import("core/bomb_rules.zig");
    pub const bomb_pool_reduce = @import("core/bomb_pool_reduce.zig");
    pub const bomb_explosion = @import("core/bomb_explosion.zig");
    pub const bomb_activation = @import("core/bomb_activation.zig");
    pub const resolve_loop = @import("core/resolve_loop.zig");
    pub const shuffle = @import("core/shuffle.zig");
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
};

pub const audio = struct {
    pub const synth = @import("audio/synth.zig");
};
