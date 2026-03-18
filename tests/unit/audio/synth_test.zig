const std = @import("std");
const game = @import("match3_2048");

const synth_mod = game.audio.synth;

test "match event gets brighter for larger k and cascade" {
    var low: synth_mod.Synth = .{};
    low.initForTesting(9001);
    defer low.deinit();
    low.trigger(.{ .kind = .match, .k_wave = 3, .cascade_wave = 0 });

    var high: synth_mod.Synth = .{};
    high.initForTesting(9001);
    defer high.deinit();
    high.trigger(.{ .kind = .match, .k_wave = 6, .cascade_wave = 4 });

    try std.testing.expect(high.debugActiveMaxFreqHz() > low.debugActiveMaxFreqHz());
    try std.testing.expect(high.debugActiveGainSum() > low.debugActiveGainSum());
}

test "cooldown blocks duplicate immediate trigger" {
    var synth: synth_mod.Synth = .{};
    synth.initForTesting(1234);
    defer synth.deinit();

    synth.trigger(.{ .kind = .swap });
    const first_count = synth.triggerCount(.swap);
    const first_voices = synth.activeVoiceCount();

    synth.trigger(.{ .kind = .swap });
    try std.testing.expectEqual(first_count, synth.triggerCount(.swap));
    try std.testing.expectEqual(first_voices, synth.activeVoiceCount());

    synth.tick(0.05);
    synth.trigger(.{ .kind = .swap });
    try std.testing.expectEqual(first_count + 1, synth.triggerCount(.swap));
    try std.testing.expect(synth.activeVoiceCount() > first_voices);
}

test "voice pool stays capped at MAX_VOICES under overflow" {
    var synth: synth_mod.Synth = .{};
    synth.initForTesting(42);
    defer synth.deinit();

    var i: usize = 0;
    while (i < synth_mod.MAX_VOICES + 6) : (i += 1) {
        synth.trigger(.{ .kind = .invalid });
        synth.tick(0.09);
    }

    try std.testing.expectEqual(@as(usize, synth_mod.MAX_VOICES), synth.activeVoiceCount());
    try std.testing.expectEqual(@as(u32, @intCast(synth_mod.MAX_VOICES + 6)), synth.triggerCount(.invalid));
}
