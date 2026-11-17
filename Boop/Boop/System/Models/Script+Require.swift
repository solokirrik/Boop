//
//  Script+Require.swift
//  Boop
//
//  Created by Ivan on 6/29/20.
//

import CryptoKit
import Foundation
import JavaScriptCore

extension Script {

    static private let boopPrefix = "@boop/"
    static private let moduleExt = ".js"

    func setupRequire(context: JSContext) {
        let require: @convention(block) (String) -> (JSValue?) = {
             [unowned self] path in

            var path = path

            if !path.hasSuffix(Script.moduleExt) {
                path += Script.moduleExt
            }

            guard
                let url = self.url(for: path),
                let rawCode = try? String(contentsOf: url),
                let context = JSContext.current()
            else {
                return nil
            }

            // The module body runs inside a function so it gets its own
            // `module` and `exports`. Built in modules also get `native`,
            // Swift helpers they wrap (see ScriptNative below).

           let wrappedCode =
"""
/***********************************
*     Start of Boop's wrapper      *
***********************************/

(function(native) {
    var module = {
        exports: {}
    };

    const moduleWrapper = (function (exports, module) {

/***********************************
 *      End of Boop's wrapper      *
 ***********************************/

\(rawCode)

/***********************************
*     Start of Boop's wrapper      *
***********************************/

    }).apply(module.exports, [module.exports, module]);

    return module.exports;
})

/***********************************
*      End of Boop's wrapper      *
***********************************/

"""

            guard
                let factory = context.evaluateScript(wrappedCode, withSourceURL: url),
                factory.isObject
            else {
                return nil
            }

            let native: Any = path.starts(with: Script.boopPrefix)
                ? ScriptNative.module(in: context)
                : JSValue(undefinedIn: context) as Any

            return factory.call(withArguments: [native])
        }

        context.setObject(require, forKeyedSubscript: "require" as NSString)

    }

    private func url(for path: String) -> URL? {
        if path.starts(with: Script.boopPrefix) {
            let fileName = String(path.dropFirst(Script.boopPrefix.count).dropLast(3))
            return Bundle.main.url(forResource: fileName, withExtension: Script.moduleExt, subdirectory: "scripts/lib")
        }

        guard
            !self.isBuiltInt,
            let url = try? ScriptManager.getBookmarkURL()
        else {
            // For now, built in scripts can't import custom stuff.
            return nil
        }

        return url.appendingPathComponent(path, isDirectory: false)

    }
}

/// Swift helpers handed to built in modules as `native`.
/// Text crosses the bridge as UTF-8; failures come back as `null`.
enum ScriptNative {

    static func module(in context: JSContext) -> JSValue {
        let native = JSValue(newObjectIn: context)!

        // digest("sha256", text, "hex" | "base64")
        let digest: @convention(block) (String, String, String) -> String? = { algorithm, text, encoding in
            hash(algorithm, Data(text.utf8)).map { format($0, encoding) }
        }

        // hmac("sha256", key, text, "hex" | "base64")
        let hmac: @convention(block) (String, String, String, String) -> String? = { algorithm, key, text, encoding in
            authenticationCode(algorithm, key: Data(key.utf8), data: Data(text.utf8)).map { format($0, encoding) }
        }

        let base64Encode: @convention(block) (String, Bool) -> String = { text, urlSafe in
            encode(Data(text.utf8), urlSafe: urlSafe)
        }

        let base64Decode: @convention(block) (String) -> String = { text in
            String(decoding: decode(text), as: UTF8.self)
        }

        // btoa/atob work on binary strings: one character per byte.
        let btoa: @convention(block) (String) -> String? = { text in
            var bytes = [UInt8]()
            for unit in text.utf16 {
                guard unit <= 0xFF else { return nil }
                bytes.append(UInt8(unit))
            }
            return encode(Data(bytes), urlSafe: false)
        }

        let atob: @convention(block) (String) -> String = { text in
            String(String.UnicodeScalarView(decode(text).map { Unicode.Scalar($0) }))
        }

        // Grapheme clusters: "é", "🇺🇦" and "👩‍👩‍👧" count as one.
        let characterCount: @convention(block) (String) -> Int = { text in
            text.count
        }

        // formatXML(text, minify) -> { text } or { error }
        let formatXML: @convention(block) (String, Bool) -> [String: String] = { text, minify in
            do {
                return ["text": try xml(text, minify: minify)]
            } catch {
                return ["error": error.localizedDescription]
            }
        }

        native.setObject(digest, forKeyedSubscript: "digest" as NSString)
        native.setObject(hmac, forKeyedSubscript: "hmac" as NSString)
        native.setObject(base64Encode, forKeyedSubscript: "base64Encode" as NSString)
        native.setObject(base64Decode, forKeyedSubscript: "base64Decode" as NSString)
        native.setObject(btoa, forKeyedSubscript: "btoa" as NSString)
        native.setObject(atob, forKeyedSubscript: "atob" as NSString)
        native.setObject(characterCount, forKeyedSubscript: "characterCount" as NSString)
        native.setObject(formatXML, forKeyedSubscript: "formatXML" as NSString)
        installCompression(in: native)

        return native
    }

    static func hash(_ algorithm: String, _ data: Data) -> Data? {
        switch algorithm {
        case "md5": return Data(Insecure.MD5.hash(data: data))
        case "sha1": return Data(Insecure.SHA1.hash(data: data))
        case "sha256": return Data(SHA256.hash(data: data))
        case "sha512": return Data(SHA512.hash(data: data))
        default: return nil
        }
    }

    static func authenticationCode(_ algorithm: String, key: Data, data: Data) -> Data? {
        let key = SymmetricKey(data: key)
        switch algorithm {
        case "md5": return Data(HMAC<Insecure.MD5>.authenticationCode(for: data, using: key))
        case "sha1": return Data(HMAC<Insecure.SHA1>.authenticationCode(for: data, using: key))
        case "sha256": return Data(HMAC<SHA256>.authenticationCode(for: data, using: key))
        case "sha512": return Data(HMAC<SHA512>.authenticationCode(for: data, using: key))
        default: return nil
        }
    }

    static func format(_ data: Data, _ encoding: String) -> String {
        encoding == "base64"
            ? data.base64EncodedString()
            : data.map { String(format: "%02x", $0) }.joined()
    }

    /// Parses with XMLDocument and prints it back, indented by four spaces or
    /// minified. The parser drops whitespace-only text between tags; elements
    /// holding text are printed as is so their content isn't changed. The XML
    /// declaration and DOCTYPE are copied from the input verbatim.
    static func xml(_ text: String, minify: Bool) throws -> String {
        let document = try XMLDocument(xmlString: text, options: [.nodePreserveCDATA, .nodeLoadExternalEntitiesNever])
        let prolog = [#"^\s*<\?xml[^>]*\?>"#, #"<!DOCTYPE[^\[>]*(\[[\s\S]*?\])?\s*>"#].compactMap { pattern in
            text.range(of: pattern, options: [.regularExpression, .caseInsensitive])
                .map { text[$0].trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        let nodes = (document.children ?? []).map { minify ? $0.xmlString(options: xmlLeafOptions) : indented($0, depth: 0) }
        return (prolog + nodes).joined(separator: minify ? "" : "\n")
    }

    private static let xmlLeafOptions: XMLNode.Options = [.nodeCompactEmptyElement, .nodePreserveCDATA]

    private static func indented(_ node: XMLNode, depth: Int) -> String {
        guard
            let element = node as? XMLElement,
            let children = element.children, !children.isEmpty,
            children.allSatisfy({ $0.kind != .text }),
            let shell = element.copy() as? XMLElement
        else {
            return node.xmlString(options: xmlLeafOptions)
        }

        // Print the element empty ("<a x="1"></a>") and put the children between the tags.
        shell.setChildren(nil)
        let tags = shell.xmlString(options: [])
        guard let close = tags.range(of: "</", options: .backwards) else {
            return node.xmlString(options: xmlLeafOptions)
        }
        let indent = String(repeating: "    ", count: depth)
        let inner = children.map { "\n" + indent + "    " + indented($0, depth: depth + 1) }.joined()
        return String(tags[..<close.lowerBound]) + inner + "\n" + indent + String(tags[close.lowerBound...])
    }

    /// URL-safe output uses `-_` and drops the `=` padding, as in JWTs.
    static func encode(_ data: Data, urlSafe: Bool) -> String {
        let encoded = data.base64EncodedString()
        guard urlSafe else { return encoded }
        return encoded
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Lenient: accepts both alphabets, missing padding, whitespace and
    /// stray characters, which are skipped.
    static func decode(_ text: String) -> Data {
        var cleaned = String(text.unicodeScalars.compactMap { scalar -> Character? in
            switch scalar {
            case "-": return "+"
            case "_": return "/"
            case "A"..."Z", "a"..."z", "0"..."9", "+", "/": return Character(scalar)
            default: return nil
            }
        })
        // A lone trailing character can't encode a byte.
        if cleaned.count % 4 == 1 { cleaned.removeLast() }
        cleaned += String(repeating: "=", count: (4 - cleaned.count % 4) % 4)
        return Data(base64Encoded: cleaned) ?? Data()
    }
}
