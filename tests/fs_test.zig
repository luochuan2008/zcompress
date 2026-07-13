//! Integration tests for filesystem utilities.
//! Tests walker and matcher together with real directory structures.

const std = @import("std");
const zcompress = @import("zcompress");

test "full walk + filter pipeline" {
    const gpa = std.testing.allocator;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    // Create a realistic project structure
    try tmp_dir.dir.writeFile(.{ .sub_path = "index.html", .data = "<html>" });
    try tmp_dir.dir.writeFile(.{ .sub_path = "style.css", .data = "body{}" });
    try tmp_dir.dir.writeFile(.{ .sub_path = "app.js", .data = "console.log(1)" });
    try tmp_dir.dir.writeFile(.{ .sub_path = "readme.md", .data = "# README" });
    try tmp_dir.dir.writeFile(.{ .sub_path = "data.json", .data = "{}" });
    try tmp_dir.dir.writeFile(.{ .sub_path = "image.png", .data = "PNG" });
    try tmp_dir.dir.writeFile(.{ .sub_path = "assets/logo.svg", .data = "<svg>" });
    try tmp_dir.dir.writeFile(.{ .sub_path = "assets/font.woff2", .data = "FONT" });
    try tmp_dir.dir.writeFile(.{ .sub_path = "assets/ignore.txt", .data = "ignored" });
    try tmp_dir.dir.writeFile(.{ .sub_path = "src/main.ts", .data = "const x = 1" });

    const tmp_path = tmp_dir.sub_path[0..tmp_dir.sub_path.len];

    // Walk
    const all_files = try zcompress.fs.walker.walkDirectory(gpa, tmp_path);
    defer zcompress.fs.walker.freeFileList(gpa, all_files);

    try std.testing.expectEqual(@as(usize, 10), all_files.len);

    // Filter with defaults
    const filtered = try zcompress.fs.matcher.filterFiles(gpa, all_files, &.{}, &.{});
    defer gpa.free(filtered);

    // Expected: .html, .css, .js, .json, .png, .svg, .woff2 = 7 files
    // Excluded: .md, .txt, .ts are not in defaults
    try std.testing.expectEqual(@as(usize, 7), filtered.len);

    // Verify specific files are included
    var found_css = false;
    var found_js = false;
    var found_md = false;
    for (filtered) |f| {
        if (std.mem.endsWith(u8, f, "style.css")) found_css = true;
        if (std.mem.endsWith(u8, f, "app.js")) found_js = true;
        if (std.mem.endsWith(u8, f, "readme.md")) found_md = true;
    }
    try std.testing.expect(found_css);
    try std.testing.expect(found_js);
    try std.testing.expect(!found_md);
}

test "filter with custom includes" {
    const gpa = std.testing.allocator;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    try tmp_dir.dir.writeFile(.{ .sub_path = "app.ts", .data = "code" });
    try tmp_dir.dir.writeFile(.{ .sub_path = "app.js", .data = "code" });
    try tmp_dir.dir.writeFile(.{ .sub_path = "app.tsx", .data = "code" });

    const tmp_path = tmp_dir.sub_path[0..tmp_dir.sub_path.len];

    const all_files = try zcompress.fs.walker.walkDirectory(gpa, tmp_path);
    defer zcompress.fs.walker.freeFileList(gpa, all_files);

    const custom_include = [_][]const u8{ ".ts", ".tsx" };
    const filtered = try zcompress.fs.matcher.filterFiles(gpa, all_files, &custom_include, &.{});
    defer gpa.free(filtered);

    // Only .ts and .tsx should be included; .js excluded
    try std.testing.expectEqual(@as(usize, 2), filtered.len);
}
