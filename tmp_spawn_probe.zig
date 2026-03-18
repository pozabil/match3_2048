const std = @import("std");
const cfg = @import("src/core/config.zig");
const utils = @import("src/core/utils.zig");

fn runProbe(random: std.Random, conf: cfg.GameConfig, high_tier: bool, n: usize) void {
    var c2: usize = 0;
    var c4: usize = 0;
    var c8: usize = 0;

    var i: usize = 0;
    while (i < n) : (i += 1) {
        const t = utils.randomSpawnTileWithTier(random, conf, high_tier);
        switch (t.value) {
            2 => c2 += 1,
            4 => c4 += 1,
            8 => c8 += 1,
            else => {},
        }
    }

    const nf = @as(f64, @floatFromInt(n));
    std.debug.print(
        "high_tier={any} n={d} => 2:{d} ({d:.2}%), 4:{d} ({d:.2}%), 8:{d} ({d:.2}%)\n",
        .{
            high_tier,
            n,
            c2,
            @as(f64, @floatFromInt(c2)) * 100.0 / nf,
            c4,
            @as(f64, @floatFromInt(c4)) * 100.0 / nf,
            c8,
            @as(f64, @floatFromInt(c8)) * 100.0 / nf,
        },
    );
}

pub fn main() void {
    var prng = std.Random.DefaultPrng.init(1234567);
    const random = prng.random();
    const conf = cfg.defaultConfig();

    runProbe(random, conf, false, 100000);
    runProbe(random, conf, true, 100000);
}
