const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });
    const raylib = raylib_dep.module("raylib");
    const raylib_artifact = raylib_dep.artifact("raylib");

    const core_mod = b.addModule("match3_2048", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "raylib", .module = raylib },
        },
    });

    const exe = b.addExecutable(.{
        .name = "match3_2048",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "match3_2048", .module = core_mod },
                .{ .name = "raylib", .module = raylib },
            },
        }),
    });
    exe.root_module.linkLibrary(raylib_artifact);

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the game");
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/unit/all.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "match3_2048", .module = core_mod },
            },
        }),
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const unit_step = b.step("test-unit", "Run unit tests");
    unit_step.dependOn(&run_unit_tests.step);

    const integration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/integration/all.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "match3_2048", .module = core_mod },
            },
        }),
    });
    const run_integration_tests = b.addRunArtifact(integration_tests);
    const integration_step = b.step("test-integration", "Run integration tests");
    integration_step.dependOn(&run_integration_tests.step);

    const perf_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/perf/all.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "match3_2048", .module = core_mod },
            },
        }),
    });
    const run_perf_tests = b.addRunArtifact(perf_tests);
    const perf_step = b.step("test-perf", "Run perf-oriented tests");
    perf_step.dependOn(&run_perf_tests.step);

    const all_tests = b.step("test", "Run all tests");
    all_tests.dependOn(unit_step);
    all_tests.dependOn(integration_step);
    all_tests.dependOn(perf_step);
}
