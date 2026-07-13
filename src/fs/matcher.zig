//! File extension matcher.
//!
//! Determines which files should be compressed based on their extension.
//! Provides sensible defaults for web assets and allows customization.

const std = @import("std");

/// Default file extensions to compress — common web assets that benefit from compression.
pub const DEFAULT_EXTENSIONS = [_][]const u8{
    ".js",    ".mjs",  ".cjs",
    ".css",   ".html", ".htm",
    ".json",  ".svg",  ".png",
    ".jpg",   ".jpeg", ".gif",
    ".ico",   ".ttf",  ".woff",
    ".woff2", ".xml",  ".csv",
    ".wasm",
};

/// Check if a filename matches the default set of compressible extensions.
pub fn matchesDefault(filename: []const u8) bool {
    return matchesAny(filename, &DEFAULT_EXTENSIONS);
}

/// Check if a filename matches any extension in the provided list.
pub fn matchesAny(filename: []const u8, extensions: []const []const u8) bool {
    for (extensions) |ext| {
        if (std.ascii.endsWithIgnoreCase(filename, ext)) return true;
    }
    return false;
}

/// Check if a filename matches any extension in the exclusion list.
pub fn matchesExclude(filename: []const u8, exclude_exts: []const []const u8) bool {
    return matchesAny(filename, exclude_exts);
}

/// Filter a list of file paths, keeping only those that should be compressed.
/// include_exts: custom extensions (empty means use defaults)
/// exclude_exts: extensions to exclude
pub fn filterFiles(
    allocator: std.mem.Allocator,
    files: []const []const u8,
    include_exts: []const []const u8,
    exclude_exts: []const []const u8,
) ![]const []const u8 {
    const extensions: []const []const u8 = if (include_exts.len > 0) include_exts else &DEFAULT_EXTENSIONS;

    var filtered: std.ArrayListUnmanaged([]const u8) = .{ .items = &.{}, .capacity = 0 };

    for (files) |f| {
        const basename = std.fs.path.basename(f);
        if (matchesAny(basename, extensions) and !matchesExclude(basename, exclude_exts)) {
            try filtered.append(allocator, f);
        }
    }

    return filtered.toOwnedSlice(allocator);
}

test "matchesDefault for common extensions" {
    try std.testing.expect(matchesDefault("app.js"));
    try std.testing.expect(matchesDefault("style.css"));
    try std.testing.expect(matchesDefault("index.html"));
    try std.testing.expect(matchesDefault("data.json"));
    try std.testing.expect(matchesDefault("logo.svg"));
    try std.testing.expect(matchesDefault("image.png"));
    try std.testing.expect(matchesDefault("photo.jpg"));
}

test "matchesDefault rejects unsupported" {
    try std.testing.expect(!matchesDefault("readme.md"));
    try std.testing.expect(!matchesDefault("main.ts"));
    try std.testing.expect(!matchesDefault("program.exe"));
    try std.testing.expect(!matchesDefault("data.zip"));
}

test "matchesAny custom extensions" {
    const custom = [_][]const u8{ ".ts", ".tsx", ".md" };
    try std.testing.expect(matchesAny("app.ts", &custom));
    try std.testing.expect(matchesAny("component.tsx", &custom));
    try std.testing.expect(matchesAny("README.md", &custom));
    try std.testing.expect(!matchesAny("app.js", &custom));
}

test "filterFiles with defaults" {
    const gpa = std.testing.allocator;
    const files = [_][]const u8{ "app.js", "style.css", "readme.md", "data.json", "main.rs" };
    const filtered = try filterFiles(gpa, &files, &.{}, &.{});
    defer gpa.free(filtered);

    try std.testing.expectEqual(@as(usize, 3), filtered.len);
}

test "filterFiles with exclusion" {
    const gpa = std.testing.allocator;
    const files = [_][]const u8{ "app.js", "big.js", "style.css" };
    const exclude = [_][]const u8{".js"};
    const filtered = try filterFiles(gpa, &files, &.{}, &exclude);
    defer gpa.free(filtered);

    try std.testing.expectEqual(@as(usize, 1), filtered.len);
}
