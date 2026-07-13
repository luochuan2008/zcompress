//! Compression module.
//! Re-exports compression implementations and pipeline.

pub const gzip = @import("gzip.zig");
pub const zstd = @import("zstd.zig");
pub const brotli = @import("brotli.zig");
pub const pipeline = @import("pipeline.zig");
