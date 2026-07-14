const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("zcompress", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "zcompress",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zcompress", .module = mod },
            },
        }),
    });

    // Link compression libraries and add platform-specific paths
    addCompressionDeps(exe.root_module, target.result.os.tag);

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // --- Tests ---
    const lib_tests = b.addTest(.{ .root_module = mod });
    addCompressionDeps(lib_tests.root_module, target.result.os.tag);
    const run_lib_tests = b.addRunArtifact(lib_tests);

    const exe_tests = b.addTest(.{ .root_module = exe.root_module });
    addCompressionDeps(exe_tests.root_module, target.result.os.tag);
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const integration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/integration_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zcompress", .module = mod },
            },
        }),
    });
    const run_integration_tests = b.addRunArtifact(integration_tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_lib_tests.step);
    test_step.dependOn(&run_exe_tests.step);
    test_step.dependOn(&run_integration_tests.step);
}

/// Add platform-specific compression library paths.
fn addCompressionDeps(module: *std.Build.Module, os_tag: std.Target.Os.Tag) void {
    // Link libraries (optional — runtime error if not found)
    inline for (.{ "zstd", "brotlienc" }) |lib| {
        module.linkSystemLibrary(lib, .{});
    }

    switch (os_tag) {
        .macos, .ios, .tvos, .watchos, .visionos => {
            module.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
            module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
            module.addIncludePath(.{ .cwd_relative = "/usr/local/include" });
            module.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" });
        },
        .linux => {
            module.addIncludePath(.{ .cwd_relative = "/usr/include" });
            module.addLibraryPath(.{ .cwd_relative = "/usr/lib" });
            module.addIncludePath(.{ .cwd_relative = "/usr/local/include" });
            module.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" });
        },
        .windows => {
            // vcpkg / msys2 / chocolatey common paths
            module.addIncludePath(.{ .cwd_relative = "C:/vcpkg/installed/x64-windows/include" });
            module.addLibraryPath(.{ .cwd_relative = "C:/vcpkg/installed/x64-windows/lib" });
            module.addIncludePath(.{ .cwd_relative = "C:/msys64/mingw64/include" });
            module.addLibraryPath(.{ .cwd_relative = "C:/msys64/mingw64/lib" });
        },
        else => {},
    }
}
