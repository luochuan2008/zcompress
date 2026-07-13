//! CLI argument parsing for zcompress.
//!
//! Parses command-line arguments into a structured Options type.
//! Supports short (-i) and long (--input) flags.

const std = @import("std");

pub const Algorithm = enum {
    gzip,
    zstd,
    brotli,

    pub fn fromString(s: []const u8) ?Algorithm {
        if (std.mem.eql(u8, s, "gzip")) return .gzip;
        if (std.mem.eql(u8, s, "zstd")) return .zstd;
        if (std.mem.eql(u8, s, "brotli")) return .brotli;
        return null;
    }
};

pub const Options = struct {
    input: ?[]const u8 = null,
    output: ?[]const u8 = null,
    threads: u16 = 0,
    algo: Algorithm = .gzip,
    level: u4 = 6,
    cache: bool = false,
    verbose: bool = false,
    help: bool = false,
    /// Custom file extensions to include (if empty, use defaults)
    include: std.ArrayListUnmanaged([]const u8) = .{ .items = &.{}, .capacity = 0 },
    /// File extensions to exclude
    exclude: std.ArrayListUnmanaged([]const u8) = .{ .items = &.{}, .capacity = 0 },

    pub fn deinit(self: *Options, allocator: std.mem.Allocator) void {
        self.include.deinit(allocator);
        self.exclude.deinit(allocator);
    }
};

pub fn printHelp() void {
    const help_text =
        \\🚀 zcompress — High-performance asset compressor written in Zig
        \\
        \\USAGE:
        \\  zcompress [OPTIONS]
        \\
        \\OPTIONS:
        \\  -i, --input <dir>     Input directory (default: ./dist)
        \\  -o, --output <dir>    Output directory (default: ./dist-compressed)
        \\  -t, --threads <n>     Number of threads (default: CPU core count)
        \\  -a, --algo <name>     Compression algorithm: gzip | zstd | brotli (default: gzip)
        \\  -l, --level <1-9>     Compression level: 1-9 (default: 6)
        \\  -c, --cache           Enable incremental cache (skip unchanged files)
        \\  -v, --verbose         Verbose output
        \\  -h, --help            Show this help message
        \\
        \\EXAMPLES:
        \\  zcompress -i ./dist -o ./dist-gz
        \\  zcompress -i ./dist -o ./dist-zstd -a zstd -l 3 -t 8
        \\  zcompress -i ./dist -o ./dist-gz -c --verbose
        \\
    ;
    std.debug.print("{s}", .{help_text});
}

/// Parse command-line arguments into Options.
/// Returns an error if required arguments are missing or invalid.
pub fn parse(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    var opts = Options{};
    errdefer opts.deinit(allocator);

    var i: usize = 1; // skip program name
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            opts.help = true;
            return opts;
        } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            opts.verbose = true;
        } else if (std.mem.eql(u8, arg, "-c") or std.mem.eql(u8, arg, "--cache")) {
            opts.cache = true;
        } else if (std.mem.eql(u8, arg, "-i") or std.mem.eql(u8, arg, "--input")) {
            i += 1;
            if (i >= args.len) return error.MissingInputPath;
            opts.input = args[i];
        } else if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
            i += 1;
            if (i >= args.len) return error.MissingOutputPath;
            opts.output = args[i];
        } else if (std.mem.eql(u8, arg, "-t") or std.mem.eql(u8, arg, "--threads")) {
            i += 1;
            if (i >= args.len) return error.MissingThreadCount;
            opts.threads = try std.fmt.parseInt(u16, args[i], 10);
        } else if (std.mem.eql(u8, arg, "-a") or std.mem.eql(u8, arg, "--algo")) {
            i += 1;
            if (i >= args.len) return error.MissingAlgorithm;
            opts.algo = Algorithm.fromString(args[i]) orelse return error.InvalidAlgorithm;
        } else if (std.mem.eql(u8, arg, "-l") or std.mem.eql(u8, arg, "--level")) {
            i += 1;
            if (i >= args.len) return error.MissingCompressionLevel;
            const level = try std.fmt.parseInt(u4, args[i], 10);
            if (level < 1 or level > 9) return error.InvalidCompressionLevel;
            opts.level = level;
        } else if (std.mem.startsWith(u8, arg, "--include=")) {
            const ext = arg["--include=".len..];
            if (ext.len > 0) try opts.include.append(allocator, ext);
        } else if (std.mem.startsWith(u8, arg, "--exclude=")) {
            const ext = arg["--exclude=".len..];
            if (ext.len > 0) try opts.exclude.append(allocator, ext);
        } else if (std.mem.startsWith(u8, arg, "-")) {
            std.debug.print("⚠ Unknown flag: {s}\n", .{arg});
            return error.UnknownFlag;
        } else {
            // positional argument: treat as input directory
            if (opts.input == null) {
                opts.input = arg;
            } else {
                std.debug.print("⚠ Unexpected positional argument: {s}\n", .{arg});
                return error.UnexpectedArgument;
            }
        }
    }

    return opts;
}

test "parse help flag" {
    const gpa = std.testing.allocator;
    var opts = try parse(gpa, &[_][]const u8{ "zcompress", "--help" });
    defer opts.deinit(gpa);
    try std.testing.expect(opts.help);
}

test "parse input and output" {
    const gpa = std.testing.allocator;
    var opts = try parse(gpa, &[_][]const u8{ "zcompress", "-i", "./dist", "-o", "./out" });
    defer opts.deinit(gpa);
    try std.testing.expectEqualStrings("./dist", opts.input.?);
    try std.testing.expectEqualStrings("./out", opts.output.?);
}

test "parse algorithm and level" {
    const gpa = std.testing.allocator;
    var opts = try parse(gpa, &[_][]const u8{ "zcompress", "-a", "zstd", "-l", "3" });
    defer opts.deinit(gpa);
    try std.testing.expectEqual(Algorithm.zstd, opts.algo);
    try std.testing.expectEqual(@as(u4, 3), opts.level);
}

test "parse threads" {
    const gpa = std.testing.allocator;
    var opts = try parse(gpa, &[_][]const u8{ "zcompress", "-t", "8" });
    defer opts.deinit(gpa);
    try std.testing.expectEqual(@as(u16, 8), opts.threads);
}

test "parse flags" {
    const gpa = std.testing.allocator;
    var opts = try parse(gpa, &[_][]const u8{ "zcompress", "-c", "-v" });
    defer opts.deinit(gpa);
    try std.testing.expect(opts.cache);
    try std.testing.expect(opts.verbose);
}

test "invalid algorithm" {
    const gpa = std.testing.allocator;
    try std.testing.expectError(error.InvalidAlgorithm, parse(gpa, &[_][]const u8{ "zcompress", "-a", "lzma" }));
}

test "invalid level" {
    const gpa = std.testing.allocator;
    try std.testing.expectError(error.InvalidCompressionLevel, parse(gpa, &[_][]const u8{ "zcompress", "-l", "10" }));
}
