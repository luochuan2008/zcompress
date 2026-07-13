//! File hash computation for incremental caching.
//!
//! Computes MD5 hashes of file contents to detect changes.
//! Used to skip re-compression of unchanged files.

const std = @import("std");

/// Compute a simple hash of a file's contents.
/// Returns null if the file cannot be read.
pub fn fileHash(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, path: []const u8) !?[16]u8 {
    const data = dir.readFileAlloc(io, path, allocator, std.Io.Limit.limited(10 * 1024 * 1024)) catch return null;
    defer allocator.free(data);

    var hash_val: [16]u8 = undefined;
    std.crypto.hash.Md5.hash(data, &hash_val, .{});
    return hash_val;
}

/// Check if a file has changed since it was last cached.
pub fn hasChanged(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, path: []const u8, old_hash: [16]u8) !bool {
    const new_hash = try fileHash(allocator, io, dir, path);
    if (new_hash) |h| {
        return !std.mem.eql(u8, &h, &old_hash);
    }
    return true;
}

test "fileHash computes hash" {
    const gpa = std.testing.allocator;
    const tio = std.testing.io;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(tio, .{ .sub_path = "hash_test.txt", .data = "hello world" });

    const h1 = try fileHash(gpa, tio, tmp.dir, "hash_test.txt");
    try std.testing.expect(h1 != null);

    const h2 = try fileHash(gpa, tio, tmp.dir, "hash_test.txt");
    try std.testing.expect(std.mem.eql(u8, &h1.?, &h2.?));
}

test "hash detects changes" {
    const gpa = std.testing.allocator;
    const tio = std.testing.io;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(tio, .{ .sub_path = "change_test.txt", .data = "hello" });

    const h1 = (try fileHash(gpa, tio, tmp.dir, "change_test.txt")).?;

    try tmp.dir.writeFile(tio, .{ .sub_path = "change_test.txt", .data = "world" });
    const h2 = (try fileHash(gpa, tio, tmp.dir, "change_test.txt")).?;

    try std.testing.expect(!std.mem.eql(u8, &h1, &h2));
}
