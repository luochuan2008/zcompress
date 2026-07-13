//! Raw C interop bindings for libbrotli (encoder only).

const std = @import("std");

const brotli = @cImport({
    @cInclude("brotli/encode.h");
});

pub const available = @hasDecl(brotli, "BrotliEncoderMaxCompressedSize");

/// Get max possible compressed size.
pub fn maxCompressedSize(input_size: usize) usize {
    return brotli.BrotliEncoderMaxCompressedSize(input_size);
}

/// One-shot brotli compression. Returns compressed size, or error.
pub fn compress(dst: []u8, src: []const u8, quality: u8, lgwin: u8) !usize {
    var encoded_size: usize = dst.len;
    const ok = brotli.BrotliEncoderCompress(
        @intCast(quality),
        @intCast(lgwin),
        brotli.BROTLI_DEFAULT_MODE,
        src.len,
        @ptrCast(src.ptr),
        &encoded_size,
        @ptrCast(dst.ptr),
    );
    if (ok != brotli.BROTLI_TRUE) return error.BrotliCompressFailed;
    return encoded_size;
}
