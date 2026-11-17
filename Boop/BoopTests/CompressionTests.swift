//
//  CompressionTests.swift
//  BoopTests
//
//  Fixtures were made with the gzip and lz4 CLIs and Python's zlib.
//

import JavaScriptCore
import XCTest

class CompressionTests: XCTestCase {

    private let text = "Hello, Boop! Hello, Boop! Hello, Boop! ünïcødé"

    private func string(_ data: Data) -> String? {
        String(data: data, encoding: .utf8)
    }

    func testGunzipBase64() throws {
        let input = try ScriptNative.binaryInput("H4sICPLF/GoAA3QudHh0APNIzcnJ11Fwys8vUFTwwMk5vCfv8PrkwztSDq8EAApxR/AyAAAA")
        XCTAssertEqual(string(try ScriptNative.inflate(input)), text)
    }

    func testGunzipJoinsMembers() throws {
        let input = try ScriptNative.binaryInput("H4sIAPLF/GoAA8vPS1UAAElhrCMEAAAAH4sIAPLF/GoAAyspzwcAZorKEQMAAAA=")
        XCTAssertEqual(string(try ScriptNative.inflate(input)), "one two")
    }

    func testInflatesZlibAndRawDeflateHex() throws {
        let zlib = "789cf348cdc9c9d75170cacf2f5054f0c0c939bc27eff0fae4c33b520eaf0400ab811341"
        let raw = "f348cdc9c9d75170cacf2f5054f0c0c939bc27eff0fae4c33b520eaf0400"
        XCTAssertEqual(string(try ScriptNative.inflate(try ScriptNative.binaryInput(zlib))), text)
        XCTAssertEqual(string(try ScriptNative.inflate(try ScriptNative.binaryInput("0x" + raw))), text)
    }

    func testGzipRoundTrip() throws {
        let compressed = try ScriptNative.deflate(Data(text.utf8))
        XCTAssertEqual(Array(compressed.prefix(2)), [0x1F, 0x8B])
        XCTAssertEqual(string(try ScriptNative.inflate(compressed)), text)
    }

    func testTruncatedGzipThrows() throws {
        let input = try ScriptNative.binaryInput("H4sICPLF/GoAA3QudHh0APNIzcnJ11Fwys8vUFTwwMk5")
        XCTAssertThrowsError(try ScriptNative.inflate(input))
    }

    func testLZ4Frame() throws {
        let input = try ScriptNative.binaryInput("04224d186440a71d000000df48656c6c6f2c20426f6f7021200d0007b0c3bc6ec3af63c3b864c3a900000000e52da726")
        XCTAssertEqual(string(try ScriptNative.lz4Decompress(input)), text)
    }

    func testLZ4LegacyFrameAndRawBlock() throws {
        let legacy = "02214c181d000000df48656c6c6f2c20426f6f7021200d0007b0c3bc6ec3af63c3b864c3a9"
        let raw = "df48656c6c6f2c20426f6f7021200d0007b0c3bc6ec3af63c3b864c3a9"
        XCTAssertEqual(string(try ScriptNative.lz4Decompress(try ScriptNative.binaryInput(legacy))), text)
        XCTAssertEqual(string(try ScriptNative.lz4Decompress(try ScriptNative.binaryInput(raw))), text)
    }

    /// `yes "boop line" | head -c 200000 | lz4 -B4 -BD -BX --content-size`:
    /// four linked 64 KB blocks with block checksums and a content size.
    func testLZ4LinkedBlocksWithChecksums() throws {
        let output = try ScriptNative.lz4Decompress(try ScriptNative.binaryInput(Self.linkedFrame))
        XCTAssertEqual(output.count, 200_000)
        XCTAssertEqual(string(output), String(repeating: "boop line\n", count: 20_000))
    }

    func testXXHash32MatchesReference() {
        XCTAssertEqual(ScriptNative.xxHash32([UInt8]()), 0x02CC_5D05)
        // Header checksum byte the lz4 CLI wrote for FLG 64, BD 40.
        XCTAssertEqual((ScriptNative.xxHash32([0x64, 0x40] as [UInt8]) >> 8) & 0xFF, 0xA7)
    }

    func testLZ4CompressRoundTrip() throws {
        for sample in ["", text, String(repeating: "boop line\n", count: 600_000)] {
            let frame = try ScriptNative.lz4Compress(Data(sample.utf8))
            XCTAssertEqual(Array(frame.prefix(4)), [0x04, 0x22, 0x4D, 0x18])
            XCTAssertEqual(string(try ScriptNative.lz4Decompress(frame)), sample)
        }
    }

    /// Output of an online tool that writes Python's lz4.block format.
    func testLZ4SizePrefixedBlock() throws {
        XCTAssertEqual(string(try ScriptNative.lz4Decompress(try ScriptNative.binaryInput("FwAAAGhoZWxsbyAGAFBoZWxsbw=="))), "hello hello hello hello")
        XCTAssertEqual(string(try ScriptNative.lz4Decompress(try ScriptNative.binaryInput("AwAAADBhYmM="))), "abc")
    }

    func testLZ4SizedBlockRoundTrip() throws {
        for sample in ["", "abc", text, String(repeating: "boop line\n", count: 100_000)] {
            let block = try ScriptNative.lz4CompressSizedBlock(Data(sample.utf8))
            XCTAssertEqual(Array(block.prefix(4)), [UInt8(sample.utf8.count & 0xFF), UInt8(sample.utf8.count >> 8 & 0xFF), UInt8(sample.utf8.count >> 16 & 0xFF), 0])
            XCTAssertEqual(string(try ScriptNative.lz4Decompress(block)), sample)
        }
    }

    /// Apple's encoder gives up on tiny or incompressible input; the
    /// literals-only fallback must still decode, around the 15 and 270
    /// byte length-encoding boundaries too.
    func testLZ4SizedBlockFallbackLengths() throws {
        for count in [1, 14, 15, 16, 100, 269, 270, 271, 525, 600] {
            let input = Data((0..<count).map { UInt8(truncatingIfNeeded: $0 &* 131 &+ 7) })
            let block = try ScriptNative.lz4CompressSizedBlock(input)
            XCTAssertEqual(try ScriptNative.lz4Decompress(block), input, "\(count) bytes")
        }
    }

    func testLZ4RejectsGarbage() throws {
        XCTAssertThrowsError(try ScriptNative.lz4Decompress(Data([0x04, 0x22, 0x4D, 0x18, 0x64])))
        XCTAssertThrowsError(try ScriptNative.lz4Decompress(Data([0x1F, 0xFF, 0x00])))
    }

    func testModuleReturnsHexForBinaryOutputAndErrors() throws {
        let context = JSContext()!
        context.setObject(ScriptNative.module(in: context), forKeyedSubscript: "native" as NSString)

        // gzip of the bytes 00 ff 10.
        let binary = try ScriptNative.deflate(Data([0x00, 0xFF, 0x10])).base64EncodedString()
        let result = context.evaluateScript("native.decompress('\(binary)', 'deflate')")!
        XCTAssertEqual(result.forProperty("text").toString(), "00ff10")
        XCTAssertEqual(result.forProperty("binary").toString(), "true")

        let error = context.evaluateScript("native.decompress('', 'lz4')")!
        XCTAssertTrue(error.forProperty("error").isString)
    }

    private static let linkedFrame = """
    BCJNGFxAQA0DAAAAAADcFAEAAK9ib29wIGxpbmUKCgD/////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////3lBvb3AgbDPltk0K
    AQAAD/r/////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////+hQbmUKYm8YIkZoCgEAAA8KAP//////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////oUHAgbGluQcdxIhcAAAAP+v//////////////////NVBsaW5lCseYoPsAAAAAI32FaQ==
    """
}
