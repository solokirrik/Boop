//
//  BoopLexer.swift
//  Boop
//
//  Created by Ivan on 1/26/19.
//

import Cocoa

/// Regex rules for Boop's generic, language-agnostic syntax colors.
enum BoopLexer {

    // This is not really an exhaustive list, it's more of a rough estimation of
    // what you can encounter in a lot/most of languages. Add more to it!
    // BTW is attribute the correct name? Token was taken.
    static let commonAttributes = ["var", "val", "let", "if", "else", "export", "import", "return", "static", "fun", "function", "func", "class", "open", "new", "as", "where", "select", "delete", "add", "limit", "update", "insert"]

    static let moreAttributes = ["true", "false", "to", "string", "int", "float", "double", "bool", "boolean", "from"]

    struct Rule {
        let type: BoopToken.TokenType
        let regex: NSRegularExpression
        let isGreedy: Bool
    }

    /// Applied in this order; later rules win where they overlap.
    static let rules: [Rule] = {
        var rules = [Rule?]()

        let number = #"\b(?:0x[a-f0-9]+|(?:\d(?:_\d+)*\d*(?:\.\d*)?|\.\d\+)(?:e[+\-]?\d+)?)\b"#
        rules.append(rule(.number, number))

        // Common attributes
        rules.append(rule(.attribute, #"\b(\#(commonAttributes.joined(separator: "|")))\b"#))
        rules.append(rule(.keyword, #"\b(\#(moreAttributes.joined(separator: "|")))\b"#))

        // Extras
        let utcDate = "(?:(Sun|Mon|Tue|Wed|Thu|Fri|Sat),\\s+)?(0[1-9]|[1-2]?[0-9]|3[01])\\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\\s+(19[0-9]{2}|[2-9][0-9]{3})\\s+(2[0-3]|[0-1][0-9]):([0-5][0-9])(?::(60|[0-5][0-9]))?\\s+([-\\+][0-9]{2}[0-5][0-9]|(?:UT|GMT|(?:E|C|M|P)(?:ST|DT)|[A-IK-Z]))"
        rules.append(rule(.number, utcDate))

        // - Match MD5 strings
        rules.append(rule(.keyword, "[a-f0-9]{32}"))

        // - Bootleg XML-like tags match
        rules.append(rule(.attribute, "<(?:.*?)\\b[^>]*\\/?>"))

        // - Match JSON labels and generic parameters
        rules.append(rule(.extra, #""([^"]+?)"\s*(?=:)"#, greedy: true))

        // Strings
        let quotes = #"(["'`])(?:\\(?:\r\n|[\s\S])|(?!\1)[^\\\r\n])*\1"#
        rules.append(rule(.string, quotes, greedy: true))
        rules.append(rule(.string, "(\"\"\")(.*?)(\"\"\")", options: [.dotMatchesLineSeparators, .caseInsensitive], greedy: true))

        // Comments
        rules.append(rule(.comment, #"(?=(\/\/.*))"#))
        rules.append(rule(.comment, #"(?=(\/\*[\s\S]*?(?:\*\/|$)))"#, options: [.dotMatchesLineSeparators], greedy: true))
        rules.append(rule(.comment, #"<!--[\s\S]*?-->"#, options: [.dotMatchesLineSeparators, .caseInsensitive], greedy: true))

        return rules.compactMap { $0 }
    }()

    private static func rule(_ type: BoopToken.TokenType, _ pattern: String, options: NSRegularExpression.Options = .caseInsensitive, greedy: Bool = false) -> Rule? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }
        return Rule(type: type, regex: regex, isGreedy: greedy)
    }

    /// Tokens in rule order. Zero-length lookahead matches use their first capture group.
    static func tokens(in source: String) -> [BoopToken] {
        let fullRange = NSRange(location: 0, length: (source as NSString).length)
        var tokens = [BoopToken]()

        for rule in rules {
            for match in rule.regex.matches(in: source, options: [], range: fullRange) {
                var range = match.range
                if range.length == 0, match.numberOfRanges > 1 {
                    range = match.range(at: 1)
                }
                guard range.location != NSNotFound, range.length > 0 else { continue }
                tokens.append(BoopToken(type: rule.type, range: range, isGreedy: rule.isGreedy))
            }
        }
        return tokens
    }

    /// Drops tokens that start inside an earlier greedy token (a keyword inside a string, etc.).
    static func activeTokens(_ tokens: [BoopToken]) -> [BoopToken] {
        let order = tokens.indices.sorted {
            tokens[$0].range.location != tokens[$1].range.location
                ? tokens[$0].range.location < tokens[$1].range.location
                : $0 < $1
        }

        var inactive = Set<Int>()
        var current: Int?
        for index in order {
            if let owner = current,
               tokens[owner].isGreedy,
               NSLocationInRange(tokens[index].range.location, tokens[owner].range) {
                inactive.insert(index)
            } else {
                current = index
            }
        }
        return tokens.indices.filter { !inactive.contains($0) }.map { tokens[$0] }
    }
}

/// Applies syntax colors to the editor's text storage.
enum SyntaxHighlighter {

    /// One entry per UTF-16 unit: 0 = plain text, otherwise the token type's index + 1.
    typealias Paint = [UInt8]

    private static let types: [BoopToken.TokenType] = [.comment, .string, .attribute, .keyword, .number, .extra]

    /// Resolves overlapping tokens into one color per character (later rules win).
    /// Pure and thread-safe, so large texts can be lexed off the main thread.
    static func paint(_ source: String) -> Paint {
        let length = (source as NSString).length
        var paint = Paint(repeating: 0, count: length)
        for token in BoopLexer.activeTokens(BoopLexer.tokens(in: source)) {
            let start = token.range.location
            let end = min(NSMaxRange(token.range), length)
            guard start < end, let index = types.firstIndex(of: token.type) else { continue }
            let value = UInt8(index + 1)
            for position in start..<end { paint[position] = value }
        }
        return paint
    }

    /// Writes the colors as sequential, non-overlapping runs (fast even for large texts).
    static func apply(_ paint: Paint, to storage: NSTextStorage, theme: EditorTheme) {
        guard paint.count == storage.length else { return } // text changed meanwhile
        let base = theme.baseAttributes
        let colors = [theme.textColor] + types.map { theme.color(for: $0) }

        storage.beginEditing()
        // Plain text everywhere first, then only the colored runs, front to back
        storage.setAttributes(base, range: NSRange(location: 0, length: storage.length))
        var runStart = 0
        while runStart < paint.count {
            let value = paint[runStart]
            var runEnd = runStart + 1
            while runEnd < paint.count && paint[runEnd] == value { runEnd += 1 }
            if value != 0 {
                storage.addAttribute(.foregroundColor, value: colors[Int(value)], range: NSRange(location: runStart, length: runEnd - runStart))
            }
            runStart = runEnd
        }
        storage.endEditing()
    }
}
