//! zcompress — High-performance asset compression library.
//!
//! Exports the public API for use by both the CLI and external consumers.

pub const compress = @import("compress/mod.zig");
pub const fs = @import("fs/mod.zig");
pub const cache = @import("cache/mod.zig");
pub const cli = @import("cli/mod.zig");
