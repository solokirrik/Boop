//
//  ScriptSearch.swift
//  Boop
//
//  Created by Kirill on 11/16/26.
//

import Foundation

/// Command-palette style matching, like VS Code and Zed: the query's letters must
/// appear in order, with bonuses for word starts and consecutive letters.
enum FuzzyMatcher {

    /// Higher is better; nil when the letters don't all appear in order.
    static func score(_ query: String, in candidate: String) -> Int? {
        let needle = Array(fold(query))
        let haystack = Array(fold(candidate))
        guard !needle.isEmpty, needle.count <= haystack.count else { return nil }

        // Try every start position of the first letter; keep the best alignment.
        var best: Int?
        for start in haystack.indices where haystack[start] == needle[0] {
            if let score = align(needle, haystack, from: start), score > (best ?? .min) {
                best = score
            }
        }
        return best
    }

    /// Plain containment, for descriptions where scattered letters would be noise.
    static func contains(_ query: String, in candidate: String) -> Bool {
        return fold(candidate).contains(fold(query))
    }

    private static func align(_ needle: [Character], _ haystack: [Character], from start: Int) -> Int? {
        var score = 0
        var index = start
        var previousMatch: Int?

        for letter in needle {
            while index < haystack.count && haystack[index] != letter {
                index += 1
            }
            guard index < haystack.count else { return nil }

            // After a long jump the letter must start a word: "time" shouldn't match "Trim Query"
            if let previous = previousMatch, index - previous - 1 > 3, !isWordStart(haystack, index) {
                return nil
            }

            score += 1
            if isWordStart(haystack, index) { score += 8 }
            if let previous = previousMatch {
                score += previous == index - 1 ? 6 : -min(index - previous - 1, 3)
            }
            previousMatch = index
            index += 1
        }

        if start == 0 { score += 6 }          // matches the very beginning
        score -= min(start, 10) / 2           // later starts rank a bit lower
        return score
    }

    private static func isWordStart(_ text: [Character], _ index: Int) -> Bool {
        guard index > 0 else { return true }
        let previous = text[index - 1]
        return previous == " " || previous == "-" || previous == "_" || previous == "." || previous == "/"
    }

    private static func fold(_ text: String) -> String {
        return text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}

extension Script {

    /// Relevance of this script for a picker query; nil when it doesn't match.
    /// Every space-separated term must match the name, a tag or the description.
    func searchScore(for query: String) -> Int? {
        let terms = query.split(separator: " ").map(String.init)
        guard !terms.isEmpty else { return nil }

        var total = 0
        for term in terms {
            guard let termScore = score(term: term) else { return nil }
            total += termScore
        }

        // Shorter names win ties ("URL Encode" over "URL Entities Encode")
        total -= (name?.count ?? 0) / 8
        // Scripts can nudge their ranking with "bias" (around ±0.1)
        total += Int((bias ?? 0) * 100)
        return total
    }

    private func score(term: String) -> Int? {
        var best: Int?
        func consider(_ value: Int?) {
            if let value = value, value > (best ?? .min) { best = value }
        }

        if let name = name {
            consider(FuzzyMatcher.score(term, in: name).map { $0 * 4 })
        }
        for tag in tags where !tag.isEmpty {
            consider(FuzzyMatcher.score(term, in: tag).map { $0 * 2 })
        }
        if term.count >= 3, let desc = desc, FuzzyMatcher.contains(term, in: desc) {
            consider(term.count * 2)
        }
        return best
    }
}
