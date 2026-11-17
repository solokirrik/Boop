//
//  ScriptNative+Compression.swift
//  Boop
//

import Compression
import Foundation
import JavaScriptCore
import zlib

/// gzip/zlib/DEFLATE and LZ4 for `@boop/compression`. Compressed data
/// crosses the bridge as base64 or hex text.
extension ScriptNative {

    struct CompressionError: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }

    /// Guards against decompression bombs freezing the editor.
    static let maxOutput = 256 * 1024 * 1024

    static func installCompression(in native: JSValue) {
        // decompress(text, "deflate" | "lz4") -> { text, binary? } or { error }
        let decompress: @convention(block) (String, String) -> [String: String] = { text, kind in
            do {
                let data = try binaryInput(text)
                let output = kind == "lz4" ? try lz4Decompress(data) : try inflate(data)
                if let string = String(data: output, encoding: .utf8) {
                    return ["text": string]
                }
                return ["text": format(output, "hex"), "binary": "true"]
            } catch {
                return ["error": error.localizedDescription]
            }
        }

        // gzip(text) -> base64 of the gzipped UTF-8 text
        let gzip: @convention(block) (String) -> [String: String] = { text in
            do {
                return ["text": try deflate(Data(text.utf8)).base64EncodedString()]
            } catch {
                return ["error": error.localizedDescription]
            }
        }

        // lz4(text, "frame" | "block") -> base64 of an LZ4 frame, or of a
        // raw block after a 4-byte little-endian size, of the UTF-8 text
        let lz4: @convention(block) (String, String) -> [String: String] = { text, kind in
            do {
                let data = Data(text.utf8)
                let output = kind == "block" ? try lz4CompressSizedBlock(data) : try lz4Compress(data)
                return ["text": output.base64EncodedString()]
            } catch {
                return ["error": error.localizedDescription]
            }
        }

        native.setObject(decompress, forKeyedSubscript: "decompress" as NSString)
        native.setObject(gzip, forKeyedSubscript: "gzip" as NSString)
        native.setObject(lz4, forKeyedSubscript: "lz4" as NSString)
    }

    /// Hex when the text is only hex digits (whitespace and a 0x prefix
    /// allowed), base64 otherwise.
    static func binaryInput(_ text: String) throws -> Data {
        var compact = text.filter { !$0.isWhitespace }
        if compact.hasPrefix("0x") || compact.hasPrefix("0X") {
            compact.removeFirst(2)
        }
        guard !compact.isEmpty else {
            throw CompressionError("Paste the compressed data as base64 or hex")
        }
        if compact.count % 2 == 0, compact.allSatisfy(\.isHexDigit) {
            var bytes = [UInt8]()
            bytes.reserveCapacity(compact.count / 2)
            var index = compact.startIndex
            while index < compact.endIndex {
                let next = compact.index(index, offsetBy: 2)
                bytes.append(UInt8(compact[index..<next], radix: 16)!)
                index = next
            }
            return Data(bytes)
        }
        let data = decode(compact)
        guard !data.isEmpty else {
            throw CompressionError("Paste the compressed data as base64 or hex")
        }
        return data
    }

    // MARK: - zlib

    /// Inflates gzip (several members allowed), zlib or raw DEFLATE,
    /// picked from the first bytes. zlib checks the gzip CRC and zlib Adler.
    static func inflate(_ data: Data) throws -> Data {
        var input = [UInt8](data)
        let windowBits: Int32
        if input.count >= 2, input[0] == 0x1F, input[1] == 0x8B {
            windowBits = 15 + 16
        } else if input.count >= 2, input[0] & 0x0F == 8, (UInt16(input[0]) << 8 | UInt16(input[1])) % 31 == 0 {
            windowBits = 15
        } else {
            windowBits = -15
        }

        var stream = z_stream()
        guard inflateInit2_(&stream, windowBits, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            throw CompressionError("Couldn't start zlib")
        }
        defer { inflateEnd(&stream) }

        var output = Data()
        var chunk = [UInt8](repeating: 0, count: 64 * 1024)
        try input.withUnsafeMutableBufferPointer { inBuffer in
            stream.next_in = inBuffer.baseAddress
            stream.avail_in = uInt(inBuffer.count)
            while true {
                let status = chunk.withUnsafeMutableBufferPointer { outBuffer -> Int32 in
                    stream.next_out = outBuffer.baseAddress
                    stream.avail_out = uInt(outBuffer.count)
                    return zlib.inflate(&stream, Z_NO_FLUSH)
                }
                output.append(contentsOf: chunk[0..<(chunk.count - Int(stream.avail_out))])
                guard output.count <= maxOutput else {
                    throw CompressionError("Output is over 256 MB")
                }

                switch status {
                case Z_OK:
                    continue
                case Z_STREAM_END:
                    // Another gzip member may follow; zero padding may too.
                    let rest = UnsafeBufferPointer(start: stream.next_in, count: Int(stream.avail_in))
                    if windowBits == 31, rest.count >= 2, rest[0] == 0x1F, rest[1] == 0x8B {
                        inflateReset(&stream)
                        continue
                    }
                    return
                case Z_BUF_ERROR:
                    throw CompressionError("The data ends too early")
                default:
                    let message = stream.msg.map { String(cString: $0) } ?? "error \(status)"
                    throw CompressionError("Not valid \(windowBits == 31 ? "gzip" : windowBits == 15 ? "zlib" : "gzip, zlib or DEFLATE") data: \(message)")
                }
            }
        }
        return output
    }

    static func deflate(_ data: Data) throws -> Data {
        var input = [UInt8](data)
        var stream = z_stream()
        guard deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 15 + 16, 8, Z_DEFAULT_STRATEGY,
                            ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            throw CompressionError("Couldn't start zlib")
        }
        defer { deflateEnd(&stream) }

        var output = Data()
        var chunk = [UInt8](repeating: 0, count: 64 * 1024)
        input.withUnsafeMutableBufferPointer { inBuffer in
            stream.next_in = inBuffer.baseAddress
            stream.avail_in = uInt(inBuffer.count)
            var status = Z_OK
            while status != Z_STREAM_END {
                status = chunk.withUnsafeMutableBufferPointer { outBuffer -> Int32 in
                    stream.next_out = outBuffer.baseAddress
                    stream.avail_out = uInt(outBuffer.count)
                    return zlib.deflate(&stream, Z_FINISH)
                }
                output.append(contentsOf: chunk[0..<(chunk.count - Int(stream.avail_out))])
            }
        }
        return output
    }

    // MARK: - LZ4

    private static let lz4FrameMagic: UInt32 = 0x184D2204
    private static let lz4LegacyMagic: UInt32 = 0x184C2102

    /// Decodes LZ4 frames (as written by the lz4 CLI, including legacy
    /// `-l` frames and skippable frames). Data without a frame magic is
    /// decoded as one block, with or without a 4-byte little-endian size
    /// prefix (Python's lz4.block default). Checksums are skipped.
    static func lz4Decompress(_ data: Data) throws -> Data {
        let bytes = [UInt8](data)
        var output = [UInt8]()

        func u32(_ at: Int) throws -> UInt32 {
            guard at + 4 <= bytes.count else { throw CompressionError("The data ends too early") }
            return UInt32(bytes[at]) | UInt32(bytes[at + 1]) << 8 | UInt32(bytes[at + 2]) << 16 | UInt32(bytes[at + 3]) << 24
        }
        func isMagic(_ value: UInt32) -> Bool {
            value == lz4FrameMagic || value == lz4LegacyMagic || value & 0xFFFFFFF0 == 0x184D2A50
        }

        guard bytes.count >= 4, isMagic(try u32(0)) else {
            // A size-prefixed block if the decoded length matches the prefix.
            if bytes.count >= 4, case let size = Int(try u32(0)), size <= maxOutput {
                var sized = [UInt8]()
                if (try? lz4Block(bytes, 4..<bytes.count, into: &sized)) != nil, sized.count == size {
                    return Data(sized)
                }
            }
            try lz4Block(bytes, 0..<bytes.count, into: &output)
            return Data(output)
        }

        var i = 0
        while i < bytes.count {
            let magic = try u32(i)
            i += 4
            switch magic {
            case lz4FrameMagic:
                guard i + 2 <= bytes.count else { throw CompressionError("The data ends too early") }
                let flags = bytes[i]
                guard flags >> 6 == 1 else { throw CompressionError("Unsupported LZ4 frame version") }
                guard flags & 0x01 == 0 else { throw CompressionError("This LZ4 frame needs a dictionary") }
                i += 2 + (flags & 0x08 != 0 ? 8 : 0) + 1 // FLG, BD, content size, header checksum
                while true {
                    let size = try u32(i)
                    i += 4
                    if size == 0 { break }
                    let length = Int(size & 0x7FFF_FFFF)
                    guard i + length <= bytes.count else { throw CompressionError("The data ends too early") }
                    if size & 0x8000_0000 != 0 {
                        output.append(contentsOf: bytes[i..<(i + length)])
                    } else {
                        try lz4Block(bytes, i..<(i + length), into: &output)
                    }
                    i += length + (flags & 0x10 != 0 ? 4 : 0)
                }
                i += flags & 0x04 != 0 ? 4 : 0

            case lz4LegacyMagic:
                // Blocks run until the end or the next frame's magic.
                while i + 4 <= bytes.count, !isMagic(try u32(i)) {
                    let length = Int(try u32(i))
                    i += 4
                    guard i + length <= bytes.count else { throw CompressionError("The data ends too early") }
                    try lz4Block(bytes, i..<(i + length), into: &output)
                    i += length
                }

            case let skippable where skippable & 0xFFFFFFF0 == 0x184D2A50:
                i += 4 + Int(try u32(i))

            default:
                throw CompressionError("Unexpected bytes after the LZ4 frame")
            }
        }
        return Data(output)
    }

    private static let lz4BlockSize = 4 * 1024 * 1024

    /// Writes an LZ4 frame like `lz4` does by default: independent 4 MB
    /// blocks and a content checksum. Blocks come from Apple's raw LZ4
    /// encoder; a block that doesn't shrink is stored as is.
    static func lz4Compress(_ data: Data) throws -> Data {
        let input = [UInt8](data)
        let descriptor: [UInt8] = [0x64, 0x70] // FLG: v01, independent blocks, content checksum. BD: 4 MB.
        var out: [UInt8] = []
        appendLE(lz4FrameMagic, to: &out)
        out += descriptor
        out.append(UInt8((xxHash32(descriptor) >> 8) & 0xFF))

        var scratch = [UInt8](repeating: 0, count: lz4BlockSize)
        var start = 0
        while start < input.count {
            let block = input[start..<min(start + lz4BlockSize, input.count)]
            let size = block.withUnsafeBufferPointer { src in
                scratch.withUnsafeMutableBufferPointer { dst in
                    compression_encode_buffer(dst.baseAddress!, dst.count, src.baseAddress!, src.count, nil, COMPRESSION_LZ4_RAW)
                }
            }
            if size > 0, size < block.count {
                appendLE(UInt32(size), to: &out)
                out += scratch[0..<size]
            } else {
                appendLE(UInt32(block.count) | 0x8000_0000, to: &out)
                out += block
            }
            start += block.count
        }

        appendLE(0, to: &out) // End mark.
        appendLE(xxHash32(input), to: &out)
        return Data(out)
    }

    /// The uncompressed size as 4 little-endian bytes, then one raw block,
    /// as Python's lz4.block.compress and many C#/Node libraries write it.
    static func lz4CompressSizedBlock(_ data: Data) throws -> Data {
        let input = [UInt8](data)
        guard input.count <= 0x7E00_0000 else { throw CompressionError("Input is too large for one LZ4 block") }
        var out: [UInt8] = []
        appendLE(UInt32(input.count), to: &out)
        guard !input.isEmpty else { return Data(out) }

        // Apple's encoder needs slack beyond the LZ4 worst case.
        var scratch = [UInt8](repeating: 0, count: input.count * 2 + 64)
        let size = input.withUnsafeBufferPointer { src in
            scratch.withUnsafeMutableBufferPointer { dst in
                compression_encode_buffer(dst.baseAddress!, dst.count, src.baseAddress!, src.count, nil, COMPRESSION_LZ4_RAW)
            }
        }
        if size > 0 {
            return Data(out + scratch[0..<size])
        }

        // It gives up on tiny inputs; one literals-only sequence is valid LZ4.
        var rest = input.count - 15
        out.append(input.count < 15 ? UInt8(input.count) << 4 : 0xF0)
        while rest >= 0, input.count >= 15 {
            out.append(UInt8(min(rest, 255)))
            if rest < 255 { break }
            rest -= 255
        }
        return Data(out + input)
    }

    private static func appendLE(_ value: UInt32, to out: inout [UInt8]) {
        out += [UInt8(value & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value >> 16 & 0xFF), UInt8(value >> 24)]
    }

    /// xxHash32 with seed 0, the checksum LZ4 frames use.
    static func xxHash32<C: Collection>(_ input: C) -> UInt32 where C.Element == UInt8, C.Index == Int {
        let p1: UInt32 = 2_654_435_761, p2: UInt32 = 2_246_822_519, p3: UInt32 = 3_266_489_917
        let p4: UInt32 = 668_265_263, p5: UInt32 = 374_761_393
        func rotl(_ x: UInt32, _ r: UInt32) -> UInt32 { x << r | x >> (32 - r) }
        func read(_ i: Int) -> UInt32 {
            UInt32(input[i]) | UInt32(input[i + 1]) << 8 | UInt32(input[i + 2]) << 16 | UInt32(input[i + 3]) << 24
        }
        func round(_ acc: UInt32, _ lane: UInt32) -> UInt32 { rotl(acc &+ lane &* p2, 13) &* p1 }

        var i = input.startIndex
        let end = input.endIndex
        var hash: UInt32
        if input.count >= 16 {
            var v1 = p1 &+ p2, v2 = p2, v3: UInt32 = 0, v4 = 0 &- p1
            while i + 16 <= end {
                v1 = round(v1, read(i)); v2 = round(v2, read(i + 4))
                v3 = round(v3, read(i + 8)); v4 = round(v4, read(i + 12))
                i += 16
            }
            hash = rotl(v1, 1) &+ rotl(v2, 7) &+ rotl(v3, 12) &+ rotl(v4, 18)
        } else {
            hash = p5
        }
        hash = hash &+ UInt32(truncatingIfNeeded: input.count)
        while i + 4 <= end {
            hash = rotl(hash &+ read(i) &* p3, 17) &* p4
            i += 4
        }
        while i < end {
            hash = rotl(hash &+ UInt32(input[i]) &* p5, 11) &* p1
            i += 1
        }
        hash ^= hash >> 15; hash = hash &* p2
        hash ^= hash >> 13; hash = hash &* p3
        hash ^= hash >> 16
        return hash
    }

    /// One LZ4 block. Earlier output is the history, so linked blocks work.
    static func lz4Block(_ src: [UInt8], _ range: Range<Int>, into out: inout [UInt8]) throws {
        let invalid = CompressionError("Not valid LZ4 data")
        var i = range.lowerBound
        let end = range.upperBound

        func length(_ base: Int) throws -> Int {
            var length = base
            guard base == 15 else { return length }
            while true {
                guard i < end else { throw invalid }
                let byte = src[i]
                i += 1
                length += Int(byte)
                if byte != 255 { return length }
            }
        }

        while i < end {
            let token = src[i]
            i += 1

            let literals = try length(Int(token >> 4))
            guard i + literals <= end else { throw invalid }
            out.append(contentsOf: src[i..<(i + literals)])
            i += literals
            if i == end { break } // The last sequence has literals only.

            guard i + 2 <= end else { throw invalid }
            let offset = Int(src[i]) | Int(src[i + 1]) << 8
            i += 2
            guard offset > 0, offset <= out.count else { throw invalid }

            let match = try length(Int(token & 0x0F)) + 4
            guard out.count + match <= maxOutput else { throw CompressionError("Output is over 256 MB") }
            // Copy inside the buffer: appending a slice of `out` to itself
            // would copy the whole array on every match.
            let start = out.count - offset
            let dest = out.count
            out.append(contentsOf: repeatElement(0, count: match))
            out.withUnsafeMutableBufferPointer { buffer in
                let base = buffer.baseAddress!
                if offset >= match {
                    (base + dest).update(from: base + start, count: match)
                } else {
                    // Overlapping copy repeats the last `offset` bytes.
                    for k in 0..<match { base[dest + k] = base[start + k] }
                }
            }
        }
    }
}
