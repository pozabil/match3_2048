const std = @import("std");
const zemscripten = @import("zemscripten");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = if (target.result.os.tag == .emscripten)
        b.dependency("raylib_zig", .{
            .target = target,
            .optimize = optimize,
            .opengl_version = .gles_2,
        })
    else
        b.dependency("raylib_zig", .{
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

    if (target.result.os.tag != .emscripten) {
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
        if (target.result.os.tag == .windows) {
            exe.subsystem = .Windows;
        }
        exe.root_module.linkLibrary(raylib_artifact);
        b.installArtifact(exe);

        const run_step = b.step("run", "Run the game");
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| run_cmd.addArgs(args);
        run_step.dependOn(&run_cmd.step);
    } else {
        const run_step = b.step("run", "Run the game");
        run_step.dependOn(&b.addFail("Use `zig build web -Dtarget=wasm32-emscripten` for browser build").step);
    }

    const web_step = b.step("web", "Build browser version (html/wasm) via Emscripten");
    const web_release_step = b.step("web-release", "Build optimized browser release (html/wasm)");
    if (target.result.os.tag == .emscripten) {
        const wasm = b.addLibrary(.{
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
        wasm.root_module.linkLibrary(raylib_artifact);
        wasm.addCSourceFile(.{ .file = b.path("src/platform/web_storage.c"), .flags = &.{} });

        const install_dir: std.Build.InstallDir = .{ .custom = "web" };
        const emcc_fsanitize = switch (optimize) {
            .Debug, .ReleaseSafe => true,
            .ReleaseFast, .ReleaseSmall => false,
        };
        const emcc_flags = zemscripten.emccDefaultFlags(b.allocator, .{
            .optimize = optimize,
            .fsanitize = emcc_fsanitize,
        });

        var emcc_settings = zemscripten.emccDefaultSettings(b.allocator, .{
            .optimize = optimize,
            .emsdk_allocator = .emmalloc,
        });
        emcc_settings.put("FULL_ES3", "0") catch unreachable;
        emcc_settings.put("USE_GLFW", "3") catch unreachable;
        emcc_settings.put("MAX_WEBGL_VERSION", "1") catch unreachable;
        emcc_settings.put("MIN_WEBGL_VERSION", "1") catch unreachable;
        emcc_settings.put("ENVIRONMENT", "web") catch unreachable;
        emcc_settings.put("FILESYSTEM", "0") catch unreachable;
        emcc_settings.put("ALLOW_MEMORY_GROWTH", "0") catch unreachable;
        emcc_settings.put("INITIAL_MEMORY", "201326592") catch unreachable; // 192 MB
        emcc_settings.put("STACK_SIZE", "2097152") catch unreachable; // 2 MB

        const activate_emsdk_step = zemscripten.activateEmsdkStep(b);
        const emsdk_dep = b.dependency("emsdk", .{});
        raylib_artifact.root_module.addIncludePath(emsdk_dep.path("upstream/emscripten/cache/sysroot/include"));
        wasm.root_module.addIncludePath(emsdk_dep.path("upstream/emscripten/cache/sysroot/include"));

        const emcc_step = zemscripten.emccStep(b, wasm, .{
            .optimize = optimize,
            .flags = emcc_flags,
            .settings = emcc_settings,
            .shell_file_path = b.path("web/shell_minimal.html"),
            .install_dir = install_dir,
        });
        emcc_step.dependOn(activate_emsdk_step);
        web_step.dependOn(emcc_step);

        const release_optimize: std.builtin.OptimizeMode = .ReleaseSmall;
        const wasm_release = b.addLibrary(.{
            .name = "match3_2048",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = release_optimize,
                .imports = &.{
                    .{ .name = "match3_2048", .module = core_mod },
                    .{ .name = "raylib", .module = raylib },
                },
            }),
        });
        wasm_release.root_module.linkLibrary(raylib_artifact);
        wasm_release.addCSourceFile(.{ .file = b.path("src/platform/web_storage.c"), .flags = &.{} });
        wasm_release.root_module.addIncludePath(emsdk_dep.path("upstream/emscripten/cache/sysroot/include"));

        const release_install_dir: std.Build.InstallDir = .{ .custom = "web-release" };
        const release_flags = zemscripten.emccDefaultFlags(b.allocator, .{
            .optimize = release_optimize,
            .fsanitize = false,
        });
        var release_settings = zemscripten.emccDefaultSettings(b.allocator, .{
            .optimize = release_optimize,
            .emsdk_allocator = .emmalloc,
        });
        release_settings.put("FULL_ES3", "0") catch unreachable;
        release_settings.put("USE_GLFW", "3") catch unreachable;
        release_settings.put("MAX_WEBGL_VERSION", "1") catch unreachable;
        release_settings.put("MIN_WEBGL_VERSION", "1") catch unreachable;
        release_settings.put("ENVIRONMENT", "web") catch unreachable;
        release_settings.put("FILESYSTEM", "0") catch unreachable;
        release_settings.put("ALLOW_MEMORY_GROWTH", "0") catch unreachable;
        release_settings.put("INITIAL_MEMORY", "201326592") catch unreachable; // 192 MB
        release_settings.put("STACK_SIZE", "2097152") catch unreachable; // 2 MB

        const emcc_release_step = zemscripten.emccStep(b, wasm_release, .{
            .optimize = release_optimize,
            .flags = release_flags,
            .settings = release_settings,
            .shell_file_path = b.path("web/shell_minimal.html"),
            .install_dir = release_install_dir,
        });
        emcc_release_step.dependOn(activate_emsdk_step);
        web_release_step.dependOn(emcc_release_step);

        const web_run_step = b.step("web-run", "Build and run browser version via emrun");
        const emrun_step = zemscripten.emrunStep(
            b,
            b.getInstallPath(install_dir, "match3_2048.html"),
            &.{},
        );
        emrun_step.dependOn(emcc_step);
        web_run_step.dependOn(emrun_step);
    } else {
        web_step.dependOn(&b.addFail("`web` step requires `-Dtarget=wasm32-emscripten`").step);
        web_release_step.dependOn(&b.addFail("`web-release` step requires `-Dtarget=wasm32-emscripten`").step);
    }

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
