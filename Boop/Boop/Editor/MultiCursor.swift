//
//  MultiCursor.swift
//  Boop
//
//  Created by Kirill on 11/17/26.
//

import Foundation

/// One cursor: an insertion point, or a selection that remembers which end moves.
/// Offsets are UTF-16, like NSRange.
struct Caret: Equatable {
    var anchor: Int
    var head: Int

    init(anchor: Int, head: Int) {
        self.anchor = anchor
        self.head = head
    }

    init(_ location: Int) {
        self.init(anchor: location, head: location)
    }

    init(range: NSRange) {
        self.init(anchor: range.location, head: NSMaxRange(range))
    }

    var range: NSRange {
        return NSRange(location: min(anchor, head), length: abs(head - anchor))
    }

    var isEmpty: Bool {
        return anchor == head
    }
}

/// The text model behind multi-cursor editing, kept apart from the view so it can be tested.
enum MultiCursor {

    /// A replacement made at one cursor.
    struct Edit: Equatable {
        var range: NSRange
        var replacement: String
    }

    /// Sorts carets by position and merges the ones that overlap or sit on the same spot.
    static func normalize(_ carets: [Caret]) -> [Caret] {
        let sorted = carets.sorted {
            let left = $0.range, right = $1.range
            return left.location != right.location ? left.location < right.location : left.length < right.length
        }
        var result: [Caret] = []
        for caret in sorted {
            guard let last = result.last else {
                result.append(caret)
                continue
            }
            let previous = last.range, next = caret.range
            let touchesInsertionPoint = next.location == NSMaxRange(previous) && (previous.length == 0 || next.length == 0)
            guard next.location < NSMaxRange(previous) || next.location == previous.location || touchesInsertionPoint else {
                result.append(caret)
                continue
            }
            let union = NSUnionRange(previous, next)
            let forward = caret.head >= caret.anchor
            result[result.count - 1] = forward
                ? Caret(anchor: union.location, head: NSMaxRange(union))
                : Caret(anchor: NSMaxRange(union), head: union.location)
        }
        return result
    }

    /// Orders and merges edits, and works out where each cursor lands: right after its replacement.
    static func plan(_ edits: [Edit]) -> (edits: [Edit], carets: [Caret]) {
        let sorted = edits.sorted { $0.range.location < $1.range.location }
        var merged: [Edit] = []
        for edit in sorted {
            if var last = merged.last,
               edit.range.location < NSMaxRange(last.range) || edit.range.location == last.range.location {
                last.range = NSUnionRange(last.range, edit.range)
                last.replacement += edit.replacement
                merged[merged.count - 1] = last
            } else {
                merged.append(edit)
            }
        }

        var delta = 0
        let carets = merged.map { edit -> Caret in
            let inserted = (edit.replacement as NSString).length
            let caret = Caret(edit.range.location + delta + inserted)
            delta += inserted - edit.range.length
            return caret
        }
        return (merged, normalize(carets))
    }

    /// Applies planned (sorted, non-overlapping) edits to a string.
    static func apply(_ edits: [Edit], to text: String) -> String {
        let result = NSMutableString(string: text)
        for edit in edits.reversed() {
            result.replaceCharacters(in: edit.range, with: edit.replacement)
        }
        return result as String
    }

    /// One range per line of `range`, without the line breaks.
    static func lines(in range: NSRange, of text: NSString) -> [NSRange] {
        guard range.length > 0 else { return [range] }
        var result: [NSRange] = []
        var location = range.location
        let end = NSMaxRange(range)
        while location < end {
            var lineEnd = 0, contentsEnd = 0
            text.getLineStart(nil, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: location, length: 0))
            result.append(NSRange(location: location, length: min(contentsEnd, end) - location))
            location = lineEnd
        }
        return result
    }

    /// The next match of `needle` after `location`, wrapping around, that no cursor already selects.
    static func nextOccurrence(of needle: String, in text: NSString, after location: Int, excluding taken: [NSRange]) -> NSRange? {
        guard !needle.isEmpty else { return nil }
        let searches = [
            NSRange(location: location, length: text.length - location),
            NSRange(location: 0, length: text.length)
        ]
        for searchRange in searches {
            var remaining = searchRange
            while remaining.length > 0 {
                let found = text.range(of: needle, options: [.literal], range: remaining)
                guard found.location != NSNotFound else { break }
                if !taken.contains(found) {
                    return found
                }
                remaining = NSRange(location: NSMaxRange(found), length: NSMaxRange(searchRange) - NSMaxRange(found))
            }
        }
        return nil
    }

    /// Every match of `needle`.
    static func occurrences(of needle: String, in text: NSString) -> [NSRange] {
        guard !needle.isEmpty else { return [] }
        var result: [NSRange] = []
        var remaining = NSRange(location: 0, length: text.length)
        while remaining.length > 0 {
            let found = text.range(of: needle, options: [.literal], range: remaining)
            guard found.location != NSNotFound else { break }
            result.append(found)
            remaining = NSRange(location: NSMaxRange(found), length: text.length - NSMaxRange(found))
        }
        return result
    }

    /// What each cursor pastes: one line each when the clipboard has exactly one line per cursor,
    /// otherwise the whole clipboard at every cursor.
    static func distribute(_ text: String, over count: Int) -> [String] {
        var lines = text.components(separatedBy: "\n")
        if lines.count > 1 && lines.last == "" {
            lines.removeLast()
        }
        if count > 1 && lines.count == count {
            return lines
        }
        return Array(repeating: text, count: count)
    }
}
