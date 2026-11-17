//
//  MultiCursorTests.swift
//  BoopTests
//
//  Created by Kirill on 11/17/26.
//

import XCTest

class MultiCursorTests: XCTestCase {

    func testNormalizeSortsAndMergesOverlappingAndDuplicateCarets() {
        let carets = [Caret(9), Caret(anchor: 2, head: 5), Caret(4), Caret(9), Caret(0)]

        XCTAssertEqual(MultiCursor.normalize(carets), [Caret(0), Caret(anchor: 2, head: 5), Caret(9)])
    }

    func testNormalizeMergesInsertionPointAtSelectionEdgeButKeepsTouchingSelections() {
        XCTAssertEqual(MultiCursor.normalize([Caret(anchor: 0, head: 3), Caret(3)]), [Caret(anchor: 0, head: 3)])
        XCTAssertEqual(MultiCursor.normalize([Caret(anchor: 0, head: 3), Caret(anchor: 3, head: 5)]).count, 2)
    }

    func testNormalizeKeepsBackwardSelectionDirection() {
        XCTAssertEqual(MultiCursor.normalize([Caret(anchor: 5, head: 2), Caret(anchor: 4, head: 1)]),
                       [Caret(anchor: 5, head: 1)])
    }

    func testTypingAtThreeCursorsShiftsLaterCursors() {
        let text = "a\nb\nc"
        let edits = [0, 2, 4].map { MultiCursor.Edit(range: NSRange(location: $0, length: 0), replacement: "- ") }

        let plan = MultiCursor.plan(edits)

        XCTAssertEqual(MultiCursor.apply(plan.edits, to: text), "- a\n- b\n- c")
        XCTAssertEqual(plan.carets, [Caret(2), Caret(6), Caret(10)])
    }

    func testReplacingSelectionsOfDifferentLengths() {
        let text = "one two three"
        let edits = [NSRange(location: 0, length: 3), NSRange(location: 8, length: 5)]
            .map { MultiCursor.Edit(range: $0, replacement: "x") }

        let plan = MultiCursor.plan(edits)

        XCTAssertEqual(MultiCursor.apply(plan.edits, to: text), "x two x")
        XCTAssertEqual(plan.carets, [Caret(1), Caret(7)])
    }

    func testOverlappingDeletionsMergeAndCursorsCollapse() {
        // Delete word backward from 3 and 5 in "abc d": both reach 0
        let edits = [NSRange(location: 0, length: 3), NSRange(location: 0, length: 5)]
            .map { MultiCursor.Edit(range: $0, replacement: "") }

        let plan = MultiCursor.plan(edits)

        XCTAssertEqual(plan.edits, [MultiCursor.Edit(range: NSRange(location: 0, length: 5), replacement: "")])
        XCTAssertEqual(plan.carets, [Caret(0)])
    }

    func testAdjacentBackspacesBothApply() {
        let edits = [NSRange(location: 1, length: 1), NSRange(location: 2, length: 1)]
            .map { MultiCursor.Edit(range: $0, replacement: "") }

        let plan = MultiCursor.plan(edits)

        XCTAssertEqual(MultiCursor.apply(plan.edits, to: "abcd"), "ad")
        XCTAssertEqual(plan.carets, [Caret(1)])
    }

    func testEmojiOffsetsAreUTF16() {
        let edits = [MultiCursor.Edit(range: NSRange(location: 0, length: 0), replacement: "😀"),
                     MultiCursor.Edit(range: NSRange(location: 1, length: 0), replacement: "😀")]

        let plan = MultiCursor.plan(edits)

        XCTAssertEqual(MultiCursor.apply(plan.edits, to: "ab"), "😀a😀b")
        XCTAssertEqual(plan.carets, [Caret(2), Caret(5)])
    }

    func testLinesSplitsSelectionWithoutLineBreaks() {
        let text = "one\ntwo\n\nfour" as NSString

        let lines = MultiCursor.lines(in: NSRange(location: 1, length: 11), of: text)

        XCTAssertEqual(lines.map { text.substring(with: $0) }, ["ne", "two", "", "fou"])
    }

    func testLinesIgnoresTrailingLineBreak() {
        let text = "one\ntwo\n" as NSString

        let lines = MultiCursor.lines(in: NSRange(location: 0, length: 8), of: text)

        XCTAssertEqual(lines.map { text.substring(with: $0) }, ["one", "two"])
    }

    func testNextOccurrenceSkipsSelectedMatchesAndWraps() {
        let text = "foo bar foo baz foo" as NSString
        let first = NSRange(location: 0, length: 3)
        let last = NSRange(location: 16, length: 3)

        XCTAssertEqual(MultiCursor.nextOccurrence(of: "foo", in: text, after: 3, excluding: [first]),
                       NSRange(location: 8, length: 3))
        XCTAssertEqual(MultiCursor.nextOccurrence(of: "foo", in: text, after: 19, excluding: [last]), first)
        XCTAssertNil(MultiCursor.nextOccurrence(of: "foo", in: text, after: 19,
                                                excluding: [first, NSRange(location: 8, length: 3), last]))
    }

    func testOccurrencesFindsEveryMatch() {
        XCTAssertEqual(MultiCursor.occurrences(of: "aa", in: "aaaa a aa"),
                       [NSRange(location: 0, length: 2), NSRange(location: 2, length: 2), NSRange(location: 7, length: 2)])
    }

    func testPasteGivesOneLinePerCursorWhenCountsMatch() {
        XCTAssertEqual(MultiCursor.distribute("a\nb\nc\n", over: 3), ["a", "b", "c"])
        XCTAssertEqual(MultiCursor.distribute("a\nb", over: 3), ["a\nb", "a\nb", "a\nb"])
        XCTAssertEqual(MultiCursor.distribute("x", over: 2), ["x", "x"])
    }
}
