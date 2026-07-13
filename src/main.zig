//! zcompress CLI — High-performance asset compressor.
//!
//! Usage:
//!   zcompress -i ./dist -o ./dist-compressed -a gzip -l 6 -t 8

const std = @import("std");
const zcompress = @import("zcompress");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();

    // Parse arguments
    const args = try init.minimal.args.toSlice(arena);
    const opts = try zcompress.cli.parse(arena, args);

    if (opts.help or args.len <= 1) {
        zcompress.cli.printHelp();
        return;
    }

    // Resolve input/output paths with defaults
    const input_dir = opts.input orelse "./dist";
    const output_dir = opts.output orelse "./dist-compressed";

    const cwd = std.Io.Dir.cwd();

    // Verify input directory exists
    cwd.access(io, input_dir, .{}) catch {
        std.debug.print("❌ Input directory not found: {s}\n", .{input_dir});
        return error.InputDirectoryNotFound;
    };

    if (opts.verbose) {
        std.debug.print("📂 Input:  {s}\n", .{input_dir});
        std.debug.print("📂 Output: {s}\n", .{output_dir});
        std.debug.print("🔧 Algo:   {s}\n", .{@tagName(opts.algo)});
        std.debug.print("🔧 Level:  {d}\n", .{opts.level});
        if (opts.threads > 0) {
            std.debug.print("🧵 Threads: {d}\n", .{opts.threads});
        }
        if (opts.cache) std.debug.print("💾 Cache:  enabled\n", .{});
    }

    // Step 1: Walk directory
    const input_dir_handle = try cwd.openDir(io, input_dir, .{});
    const files = try zcompress.fs.walker.walkDirectory(arena, io, input_dir_handle);

    if (opts.verbose) {
        std.debug.print("📁 Scanning ./{s} ... found {d} files\n", .{ input_dir, files.len });
    }

    // Step 2: Filter files by extension
    const filtered = try zcompress.fs.matcher.filterFiles(
        arena,
        files,
        opts.include.items,
        opts.exclude.items,
    );

    if (opts.verbose or filtered.len != files.len) {
        std.debug.print("🔍 Filtered: {d} files match compressible extensions (skipped {d})\n", .{ filtered.len, files.len - filtered.len });
    }

    if (filtered.len == 0) {
        std.debug.print("📊 No files to compress. Done.\n", .{});
        return;
    }

    // Step 3: Run compression pipeline
    const stats = try zcompress.compress.pipeline.runPipeline(
        arena,
        io,
        cwd,
        input_dir_handle,
        filtered,
        output_dir,
        opts.algo,
        opts.level,
        opts.threads,
        opts.verbose,
        opts.cache,
    );

    // Step 4: Print stats
    zcompress.compress.pipeline.printStats(io, stats);
}
