//! Brotli compression via libbrotli C interop.

const std = @import("std");
const brotli_c = @import("brotli_c.zig");
const gzip = @import("gzip.zig");

pub fn compressFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    cwd: std.Io.Dir,
    src_dir: std.Io.Dir,
    src_path: []const u8,
    dest_dir: []const u8,
    level: u4,
) !gzip.CompressResult {
    if (!brotli_c.available) return error.BrotliNotAvailable;

    const src_data = try src_dir.readFileAlloc(io, src_path, allocator, .unlimited);
    defer allocator.free(src_data);

    const stat = try src_dir.statFile(io, src_path, .{});
    const src_size = stat.size;

    const src_basename = std.fs.path.basename(src_path);
    const dest_name = try std.fmt.allocPrint(allocator, "{s}.br", .{src_basename});
    defer allocator.free(dest_name);

    const dest_path = try std.fs.path.join(allocator, &.{ dest_dir, dest_name });
    defer allocator.free(dest_path);

    if (std.fs.path.dirname(dest_path)) |parent| {
        cwd.createDirPath(io, parent) catch {};
    }

    const max_dest = brotli_c.maxCompressedSize(src_data.len);
    const dest_data = try allocator.alloc(u8, max_dest);
    defer allocator.free(dest_data);

    const quality = brotliLevel(level);
    const compressed_size = try brotli_c.compress(dest_data, src_data, quality, 22);

    const dest_file = try cwd.createFile(io, dest_path, .{});
    defer dest_file.close(io);

    var wbuf: [8192]u8 = undefined;
    var writer = dest_file.writer(io, &wbuf);
    try writer.interface.writeAll(dest_data[0..compressed_size]);
    try writer.interface.flush();

    const dest_stat = try dest_file.stat(io);

    return gzip.CompressResult{
        .src_path = src_path,
        .dest_path = dest_path,
        .src_size = src_size,
        .dest_size = dest_stat.size,
    };
}

fn brotliLevel(level: u4) u8 {
    return switch (level) {
        1 => 1,
        2 => 3,
        3 => 5,
        4 => 7,
        5 => 9,
        else => 11,
    };
}

test "brotli compress and verify" {
    if (!brotli_c.available) return error.SkipZigTest;

    const gpa = std.testing.allocator;
    const tio = std.testing.io;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const test_data = "Hello, Zig! Brotli compression test.";
    try tmp.dir.writeFile(tio, .{ .sub_path = "test.txt", .data = test_data });
    try tmp.dir.createDirPath(tio, "out");

    const result = try compressFile(gpa, tio, tmp.dir, tmp.dir, "test.txt", "out", 5);
    defer gpa.free(result.dest_path);

    try std.testing.expect(result.src_size > 0);
    try std.testing.expect(result.dest_size > 0);
    try std.testing.expect(result.dest_size < result.src_size);
}
