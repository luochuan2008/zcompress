//! Raw C interop bindings for libzstd.

const std = @import("std");

const zstd = @cImport({
    @cInclude("zstd.h");
});

pub const available = @hasDecl(zstd, "ZSTD_compress");

/// Get the maximum possible compressed size for a given input size.
pub fn compressBound(src_size: usize) usize {
    return zstd.ZSTD_compressBound(src_size);
}

/// Simple one-shot compression. Returns compressed size, or error.
pub fn compress(dst: []u8, src: []const u8, level: u8) !usize {
    const ret = zstd.ZSTD_compress(dst.ptr, dst.len, src.ptr, src.len, level);
    if (zstd.ZSTD_isError(ret) != 0) return error.ZstdCompressFailed;
    return ret;
}
