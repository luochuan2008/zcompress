const std = @import("std");

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

    // Link compression libraries (optional — error at runtime if not found)
    inline for (.{ "zstd", "brotlienc" }) |lib| {
        exe.root_module.linkSystemLibrary(lib, .{});
    }
    exe.root_module.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    exe.root_module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
    exe.root_module.addIncludePath(.{ .cwd_relative = "/usr/local/include" });
    exe.root_module.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" });

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
    inline for (.{ "zstd", "brotlienc" }) |lib| {
        lib_tests.root_module.linkSystemLibrary(lib, .{});
    }
    lib_tests.root_module.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    lib_tests.root_module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
    const run_lib_tests = b.addRunArtifact(lib_tests);

    const exe_tests = b.addTest(.{ .root_module = exe.root_module });
    inline for (.{ "zstd", "brotlienc" }) |lib| {
        exe_tests.root_module.linkSystemLibrary(lib, .{});
    }
    exe_tests.root_module.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    exe_tests.root_module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
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
