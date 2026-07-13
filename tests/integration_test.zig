//! End-to-end integration tests for the zcompress pipeline.
//! Tests: scan → filter → compress coordination.

const std = @import("std");
const zcompress = @import("zcompress");

test "walk and filter pipeline" {
    const gpa = std.testing.allocator;
    const tio = std.testing.io;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(tio, .{ .sub_path = "index.html", .data = "<html>" });
    try tmp.dir.writeFile(tio, .{ .sub_path = "style.css", .data = "body{}" });
    try tmp.dir.writeFile(tio, .{ .sub_path = "app.js", .data = "console.log(1)" });
    try tmp.dir.writeFile(tio, .{ .sub_path = "readme.md", .data = "# README" });
    try tmp.dir.writeFile(tio, .{ .sub_path = "data.json", .data = "{}" });

    // Walk
    const files = try zcompress.fs.walker.walkDirectory(gpa, tio, tmp.dir);
    defer zcompress.fs.walker.freeFileList(gpa, files);
    try std.testing.expectEqual(@as(usize, 5), files.len);

    // Filter — .md should be excluded by default
    const filtered = try zcompress.fs.matcher.filterFiles(gpa, files, &.{}, &.{});
    defer gpa.free(filtered);
    try std.testing.expectEqual(@as(usize, 4), filtered.len);

    // Verify readme.md is NOT in the filtered list
    for (filtered) |f| {
        try std.testing.expect(!std.mem.endsWith(u8, f, ".md"));
    }
}

test "filter with custom includes" {
    const gpa = std.testing.allocator;
    const tio = std.testing.io;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(tio, .{ .sub_path = "app.ts", .data = "code" });
    try tmp.dir.writeFile(tio, .{ .sub_path = "app.js", .data = "code" });
    try tmp.dir.writeFile(tio, .{ .sub_path = "app.tsx", .data = "code" });

    const files = try zcompress.fs.walker.walkDirectory(gpa, tio, tmp.dir);
    defer zcompress.fs.walker.freeFileList(gpa, files);

    const custom = [_][]const u8{ ".ts", ".tsx" };
    const filtered = try zcompress.fs.matcher.filterFiles(gpa, files, &custom, &.{});
    defer gpa.free(filtered);

    try std.testing.expectEqual(@as(usize, 2), filtered.len);
}

test "cli parse full command" {
    const gpa = std.testing.allocator;
    var opts = try zcompress.cli.parse(
        gpa,
        &[_][]const u8{ "zcompress", "-i", "./dist", "-o", "./out", "-a", "gzip", "-l", "9", "-t", "4", "-c", "-v" },
    );
    defer opts.deinit(gpa);

    try std.testing.expectEqualStrings("./dist", opts.input.?);
    try std.testing.expectEqualStrings("./out", opts.output.?);
    try std.testing.expectEqual(zcompress.cli.Algorithm.gzip, opts.algo);
    try std.testing.expectEqual(@as(u4, 9), opts.level);
    try std.testing.expectEqual(@as(u16, 4), opts.threads);
    try std.testing.expect(opts.cache);
    try std.testing.expect(opts.verbose);
}

test "cli defaults" {
    const gpa = std.testing.allocator;
    var opts = try zcompress.cli.parse(gpa, &[_][]const u8{"zcompress"});
    defer opts.deinit(gpa);

    try std.testing.expectEqual(@as(?[]const u8, null), opts.input);
    try std.testing.expectEqual(@as(?[]const u8, null), opts.output);
    try std.testing.expectEqual(zcompress.cli.Algorithm.gzip, opts.algo);
    try std.testing.expectEqual(@as(u4, 6), opts.level);
    try std.testing.expectEqual(@as(u16, 0), opts.threads);
    try std.testing.expect(!opts.cache);
    try std.testing.expect(!opts.verbose);
}
