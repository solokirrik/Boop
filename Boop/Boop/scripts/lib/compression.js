/*
 *  Compression for Boop, backed by zlib and a Swift LZ4 decoder.
 *
 *  Compressed data is text: base64 (either alphabet) or hex.
 *
 *  gunzip(text): gzip, zlib or raw DEFLATE, detected from the first bytes.
 *  lz4Decompress(text): LZ4 frames (lz4 CLI, legacy -l too) or one raw block,
 *  with or without a 4-byte size prefix.
 *  Both return { text, binary }; binary output that isn't UTF-8 comes back
 *  as hex with binary set to true. Bad input throws an Error.
 *
 *  gzip(text): gzips the UTF-8 text and returns base64.
 *  lz4(text): LZ4 frame of the UTF-8 text (as `lz4` writes it), as base64.
 *  lz4Block(text): 4-byte little-endian size + one raw LZ4 block, as base64
 *  (Python's lz4.block.compress default).
 */

function unwrap(result) {
    if (result.error) {
        throw new Error(result.error)
    }
    return { text: result.text, binary: result.binary === 'true' }
}

function gunzip(text) {
    return unwrap(native.decompress(String(text), 'deflate'))
}

function lz4Decompress(text) {
    return unwrap(native.decompress(String(text), 'lz4'))
}

function gzip(text) {
    return unwrap(native.gzip(String(text))).text
}

function lz4(text) {
    return unwrap(native.lz4(String(text), 'frame')).text
}

function lz4Block(text) {
    return unwrap(native.lz4(String(text), 'block')).text
}

module.exports = {
    gunzip,
    lz4Decompress,
    gzip,
    lz4,
    lz4Block
}
