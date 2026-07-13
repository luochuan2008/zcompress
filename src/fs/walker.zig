//! Recursive directory walker.
//!
//! Walks a directory tree and returns a list of all file paths.
//! Paths are relative to the input directory.

const std = @import("std");

/// Recursively walk a directory and collect all file paths.
/// Returns a slice of paths (allocated with the provided allocator).
/// The caller owns the returned slice and each path string.
pub fn walkDirectory(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir) ![]const []const u8 {
    var file_list: std.ArrayListUnmanaged([]const u8) = .{ .items = &.{}, .capacity = 0 };
    errdefer {
        for (file_list.items) |f| allocator.free(f);
        file_list.deinit(allocator);
    }

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next(io)) |entry| {
        // Skip directories - we only want files
        if (entry.kind == .directory) continue;

        // Allocate and store the full relative path
        const full_path = try allocator.dupe(u8, entry.path);
        errdefer allocator.free(full_path);
        try file_list.append(allocator, full_path);
    }

    return file_list.toOwnedSlice(allocator);
}

/// Free the list returned by walkDirectory.
pub fn freeFileList(allocator: std.mem.Allocator, files: []const []const u8) void {
    for (files) |f| allocator.free(f);
    allocator.free(files);
}

test "walkDirectory on test fixtures" {
    const gpa = std.testing.allocator;
    const tio = std.testing.io;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const tmp_dir = tmp.dir;

    // Create some test files
    try tmp_dir.writeFile(tio, .{ .sub_path = "a.txt", .data = "hello" });
    try tmp_dir.writeFile(tio, .{ .sub_path = "b.txt", .data = "world" });
    try tmp_dir.writeFile(tio, .{ .sub_path = "sub/c.txt", .data = "zig" });

    // Walk the tmp dir directly
    const files = try walkDirectory(gpa, tio, tmp_dir);
    defer freeFileList(gpa, files);

    try std.testing.expect(files.len >= 3);

    var found_a = false;
    var found_b = false;
    var found_c = false;
    for (files) |f| {
        if (std.mem.eql(u8, f, "a.txt")) found_a = true;
        if (std.mem.eql(u8, f, "b.txt")) found_b = true;
        if (std.mem.endsWith(u8, f, "c.txt")) found_c = true;
    }
    try std.testing.expect(found_a);
    try std.testing.expect(found_b);
    try std.testing.expect(found_c);
}
