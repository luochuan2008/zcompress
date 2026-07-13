//! Integration tests for compression module.
//! Tests gzip compression and decompression round-trip.

const std = @import("std");
const zcompress = @import("zcompress");

test "gzip round trip" {
    const gpa = std.testing.allocator;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const original_data = "This is test data for gzip round-trip verification. " ** 10;

    // Write original file
    try tmp_dir.dir.writeFile(.{ .sub_path = "roundtrip.txt", .data = original_data });

    var cwd = try tmp_dir.dir.openDir(".", .{});
    defer cwd.close();

    try cwd.makePath("out");

    // Compress
    const result = try zcompress.compress.gzip.compressFile(gpa, "roundtrip.txt", "out", 6);
    defer gpa.free(result.dest_path);

    // Decompress to verify
    const gz_file = try cwd.openFile(result.dest_path, .{});
    defer gz_file.close();

    var decompressed = std.ArrayList(u8).init(gpa);
    defer decompressed.deinit();

    try std.compress.gzip.decompress(gz_file.reader(), decompressed.writer());

    try std.testing.expectEqualStrings(original_data, decompressed.items);
}

test "compress empty file" {
    const gpa = std.testing.allocator;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    try tmp_dir.dir.writeFile(.{ .sub_path = "empty.txt", .data = "" });

    var cwd = try tmp_dir.dir.openDir(".", .{});
    defer cwd.close();

    try cwd.makePath("out");

    const result = try zcompress.compress.gzip.compressFile(gpa, "empty.txt", "out", 6);
    defer gpa.free(result.dest_path);

    try std.testing.expect(result.src_size == 0);

    // Verify gzip can decompress it
    const gz_file = try cwd.openFile(result.dest_path, .{});
    defer gz_file.close();

    var decompressed = std.ArrayList(u8).init(gpa);
    defer decompressed.deinit();

    try std.compress.gzip.decompress(gz_file.reader(), decompressed.writer());
    try std.testing.expectEqual(@as(usize, 0), decompressed.items.len);
}

test "compress binary file" {
    const gpa = std.testing.allocator;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    // Create a "binary" file with byte values 0-255
    var data: [256]u8 = undefined;
    for (0..256) |i| {
        data[i] = @intCast(i);
    }

    try tmp_dir.dir.writeFile(.{ .sub_path = "binary.bin", .data = &data });

    var cwd = try tmp_dir.dir.openDir(".", .{});
    defer cwd.close();

    try cwd.makePath("out");

    const result = try zcompress.compress.gzip.compressFile(gpa, "binary.bin", "out", 6);
    defer gpa.free(result.dest_path);

    try std.testing.expect(result.src_size == 256);

    // Round trip
    const gz_file = try cwd.openFile(result.dest_path, .{});
    defer gz_file.close();

    var decompressed = std.ArrayList(u8).init(gpa);
    defer decompressed.deinit();

    try std.compress.gzip.decompress(gz_file.reader(), decompressed.writer());
    try std.testing.expectEqualSlices(u8, &data, decompressed.items);
}
