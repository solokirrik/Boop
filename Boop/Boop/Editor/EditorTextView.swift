//
//  EditorTextView.swift
//  Boop
//
//  Created by Kirill on 11/17/26.
//

import Cocoa

/// NSTextView with code-editor typing: Tab inserts spaces, Return keeps the indentation,
/// and more than one cursor can type, delete, move and paste at once.
///
/// NSTextView can hold several selections but drops empty ones, so while more than one
/// cursor is active they live in `carets`. The native selection then shows the non-empty
/// ones and the insertion points are drawn by `CaretOverlayView`.
final class EditorTextView: NSTextView {

    var tabWidth = 4

    /// The insertion point color; hidden from NSTextView while several cursors are drawn here.
    var caretColor: NSColor = .textColor {
        didSet { updateInsertionPointColor() }
    }

    /// All cursors while more than one is active, sorted and non-overlapping. Empty otherwise.
    private(set) var carets: [Caret] = []

    var isMultiCursor: Bool {
        return carets.count > 1
    }

    /// Selection changes made while this is set belong to multi-cursor editing and keep the cursors.
    private var isUpdatingSelection = false
    private let caretOverlay = CaretOverlayView()
    private var blinkTimer: Timer?

    // MARK: Cursors

    /// The cursors to work from: the extra ones, or the native selection.
    private var currentCarets: [Caret] {
        if isMultiCursor {
            return carets
        }
        return selectedRanges.map { Caret(range: $0.rangeValue) }
    }

    /// Makes `newCarets` the cursors. One cursor goes back to a plain native selection.
    func setCarets(_ newCarets: [Caret]) {
        let length = (string as NSString).length
        let clamped = newCarets.map { Caret(anchor: min(max($0.anchor, 0), length), head: min(max($0.head, 0), length)) }
        let normalized = MultiCursor.normalize(clamped)
        guard normalized.count > 1 else {
            endMultiCursor()
            if let only = normalized.first {
                setSelectedRange(only.range)
            }
            return
        }

        carets = normalized
        let selections = normalized.filter { !$0.isEmpty }.map { NSValue(range: $0.range) }
        withSelectionUpdate {
            let native = selections.isEmpty ? [NSValue(range: normalized[normalized.count - 1].range)] : selections
            super.setSelectedRanges(native, affinity: .downstream, stillSelecting: false)
        }
        updateInsertionPointColor()
        restartBlinking()
    }

    /// Drops the extra cursors and leaves the native selection as it is.
    private func endMultiCursor() {
        guard !carets.isEmpty else { return }
        carets = []
        blinkTimer?.invalidate()
        blinkTimer = nil
        updateInsertionPointColor()
        caretOverlay.carets = []
    }

    private func withSelectionUpdate(_ body: () -> Void) {
        let wasUpdating = isUpdatingSelection
        isUpdatingSelection = true
        body()
        isUpdatingSelection = wasUpdating
    }

    private func updateInsertionPointColor() {
        insertionPointColor = isMultiCursor ? .clear : caretColor
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        // Anyone else choosing a selection (a click, Select All, Find, Undo) ends multi-cursor editing
        if !isUpdatingSelection {
            endMultiCursor()
        }
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelectingFlag)
    }

    override func didChangeText() {
        // Text changed by something other than the cursors, e.g. a script: their offsets are stale
        if !isUpdatingSelection {
            endMultiCursor()
        }
        super.didChangeText()
    }

    // MARK: Drawing

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if caretOverlay.superview !== self {
            caretOverlay.frame = bounds
            caretOverlay.autoresizingMask = [.width, .height]
            addSubview(caretOverlay)
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        // Rewrapped lines move the cursors
        if isMultiCursor {
            refreshCarets()
        }
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        refreshCarets()
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        refreshCarets()
        return resigned
    }

    private func restartBlinking() {
        blinkTimer?.invalidate()
        caretOverlay.isOn = true
        refreshCarets()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.caretOverlay.isOn.toggle()
            self.caretOverlay.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        blinkTimer = timer
    }

    private func refreshCarets() {
        guard isMultiCursor, window?.firstResponder === self else {
            caretOverlay.carets = []
            return
        }
        // Keep the overlay above the text fragments TextKit adds as subviews
        if subviews.last !== caretOverlay {
            addSubview(caretOverlay, positioned: .above, relativeTo: nil)
        }
        caretOverlay.color = caretColor
        caretOverlay.carets = carets.filter { $0.isEmpty }.compactMap { caretRect(at: $0.head) }
    }

    /// Where the insertion point at `index` is drawn, in this view's coordinates.
    private func caretRect(at index: Int) -> NSRect? {
        guard let window = window else { return nil }
        var actual = NSRange()
        let screenRect = firstRect(forCharacterRange: NSRange(location: index, length: 0), actualRange: &actual)
        guard screenRect != .zero else { return nil }
        let rect = convert(window.convertFromScreen(screenRect), from: nil)
        return NSRect(x: floor(rect.minX), y: rect.minY, width: 1, height: rect.height)
    }

    // MARK: Editing

    /// Replaces each cursor's selection, and leaves each cursor after its replacement.
    private func perform(_ edits: [MultiCursor.Edit]) {
        let plan = MultiCursor.plan(edits)
        let changes = plan.edits.filter { $0.range.length > 0 || !$0.replacement.isEmpty }
        guard !changes.isEmpty else {
            setCarets(plan.carets)
            return
        }
        guard let storage = textStorage,
              shouldChangeText(inRanges: changes.map { NSValue(range: $0.range) }, replacementStrings: changes.map { $0.replacement }) else {
            return
        }

        withSelectionUpdate {
            storage.beginEditing()
            for change in changes.reversed() {
                storage.replaceCharacters(in: change.range, with: NSAttributedString(string: change.replacement, attributes: typingAttributes))
            }
            storage.endEditing()
            didChangeText()
        }
        let before = carets
        setCarets(plan.carets)
        registerCaretUndo(restoring: before, redoing: carets)
        scrollToLastCaret()
    }

    /// Undo restores the text and leaves one selection over the changes; this puts the cursors back too.
    private func registerCaretUndo(restoring before: [Caret], redoing after: [Caret]) {
        undoManager?.registerUndo(withTarget: self) { view in
            view.registerCaretUndo(restoring: after, redoing: before)
            // After NSTextView has restored the text and its own selection
            DispatchQueue.main.async {
                view.setCarets(before)
            }
        }
    }

    private func replaceEach(_ replacement: (Caret) -> String) {
        perform(carets.map { MultiCursor.Edit(range: $0.range, replacement: replacement($0)) })
    }

    private func scrollToLastCaret() {
        if let last = carets.last ?? currentCarets.last {
            scrollRangeToVisible(NSRange(location: last.head, length: 0))
        }
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        guard isMultiCursor else {
            super.insertText(string, replacementRange: replacementRange)
            return
        }
        guard replacementRange.location == NSNotFound else {
            // An input method replacing specific text: only makes sense for one cursor
            endMultiCursor()
            super.insertText(string, replacementRange: replacementRange)
            return
        }
        let text = (string as? NSAttributedString)?.string ?? (string as? String) ?? ""
        replaceEach { _ in text }
    }

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        // Composing (e.g. Japanese input) works with one cursor
        if isMultiCursor, let last = carets.last {
            endMultiCursor()
            setSelectedRange(last.range)
        }
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
    }

    override func insertTab(_ sender: Any?) {
        let spaces = String(repeating: " ", count: tabWidth)
        if isMultiCursor {
            replaceEach { _ in spaces }
            return
        }
        insertText(spaces, replacementRange: selectedRange())
    }

    override func insertNewline(_ sender: Any?) {
        if isMultiCursor {
            replaceEach { "\n" + indentation(at: $0.range.location) }
            return
        }
        insertText("\n" + indentation(at: selectedRange().location), replacementRange: selectedRange())
    }

    private func indentation(at location: Int) -> String {
        let text = string as NSString
        let line = text.substring(with: text.lineRange(for: NSRange(location: location, length: 0)))
        return String(line.prefix { $0 == " " || $0 == "\t" })
    }

    // MARK: Moving and deleting

    /// Movement commands, with or without extending the selection, mapped to the plain move.
    private static let moves: [Selector: (move: Selector, extending: Bool)] = {
        let names = [
            "moveLeft", "moveRight", "moveUp", "moveDown", "moveForward", "moveBackward",
            "moveWordLeft", "moveWordRight", "moveWordForward", "moveWordBackward",
            "moveToBeginningOfLine", "moveToEndOfLine", "moveToLeftEndOfLine", "moveToRightEndOfLine",
            "moveToBeginningOfParagraph", "moveToEndOfParagraph",
            "moveToBeginningOfDocument", "moveToEndOfDocument"
        ]
        var moves: [Selector: (move: Selector, extending: Bool)] = [:]
        for name in names {
            let move = NSSelectorFromString(name + ":")
            moves[move] = (move, false)
            moves[NSSelectorFromString(name + "AndModifySelection:")] = (move, true)
        }
        return moves
    }()

    /// Deletion commands mapped to the move that finds the other end of what an insertion point deletes.
    private static let deletions: [Selector: Selector] = [
        #selector(deleteBackward(_:)): #selector(moveBackward(_:)),
        #selector(deleteBackwardByDecomposingPreviousCharacter(_:)): #selector(moveBackward(_:)),
        #selector(deleteForward(_:)): #selector(moveForward(_:)),
        #selector(deleteWordBackward(_:)): #selector(moveWordBackward(_:)),
        #selector(deleteWordForward(_:)): #selector(moveWordForward(_:)),
        #selector(deleteToBeginningOfLine(_:)): #selector(moveToBeginningOfLine(_:)),
        #selector(deleteToEndOfLine(_:)): #selector(moveToEndOfLine(_:)),
        #selector(deleteToBeginningOfParagraph(_:)): #selector(moveToBeginningOfParagraph(_:)),
        #selector(deleteToEndOfParagraph(_:)): #selector(moveToEndOfParagraph(_:))
    ]

    override func doCommand(by selector: Selector) {
        guard isMultiCursor else {
            super.doCommand(by: selector)
            return
        }
        if selector == #selector(cancelOperation(_:)) {
            collapseToFirstCaret()
        } else if let move = EditorTextView.moves[selector] {
            moveCarets(with: move.move, extending: move.extending)
        } else if let move = EditorTextView.deletions[selector] {
            deleteAtCarets(towards: move)
        } else {
            super.doCommand(by: selector)
        }
    }

    /// Runs NSTextView's own `move` on `range` alone and returns the selection it ends with,
    /// so every cursor moves exactly like a single one would.
    private func nativeMove(_ move: Selector, from range: NSRange) -> NSRange {
        var result = range
        withSelectionUpdate {
            super.setSelectedRanges([NSValue(range: range)], affinity: .downstream, stillSelecting: false)
            super.doCommand(by: move)
            result = selectedRange()
        }
        return result
    }

    private func moveCarets(with move: Selector, extending: Bool) {
        let moved = carets.map { caret -> Caret in
            if extending {
                let head = nativeMove(move, from: NSRange(location: caret.head, length: 0)).location
                return Caret(anchor: caret.anchor, head: head)
            }
            return Caret(nativeMove(move, from: caret.range).location)
        }
        setCarets(moved)
        scrollToLastCaret()
    }

    private func deleteAtCarets(towards move: Selector) {
        let edits = carets.map { caret -> MultiCursor.Edit in
            guard caret.isEmpty else {
                return MultiCursor.Edit(range: caret.range, replacement: "")
            }
            let target = nativeMove(move, from: NSRange(location: caret.head, length: 0)).location
            return MultiCursor.Edit(range: Caret(anchor: caret.head, head: target).range, replacement: "")
        }
        perform(edits)
    }

    private func collapseToFirstCaret() {
        guard let first = carets.first else { return }
        setCarets([first])
    }

    // MARK: Clipboard

    override func copy(_ sender: Any?) {
        guard isMultiCursor else {
            super.copy(sender)
            return
        }
        copySelections()
    }

    override func cut(_ sender: Any?) {
        guard isMultiCursor else {
            super.cut(sender)
            return
        }
        guard copySelections() else { return }
        replaceEach { _ in "" }
    }

    override func paste(_ sender: Any?) {
        guard isMultiCursor, let text = NSPasteboard.general.string(forType: .string) else {
            super.paste(sender)
            return
        }
        let pieces = MultiCursor.distribute(text, over: carets.count)
        perform(zip(carets, pieces).map { MultiCursor.Edit(range: $0.range, replacement: $1) })
    }

    /// Puts the selected text of every cursor on the clipboard, one per line.
    @discardableResult
    private func copySelections() -> Bool {
        let text = string as NSString
        let selected = carets.filter { !$0.isEmpty }.map { text.substring(with: $0.range) }
        guard !selected.isEmpty else {
            NSSound.beep()
            return false
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(selected.joined(separator: "\n"), forType: .string)
        return true
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])
        if modifiers == .option {
            selectColumn(startingWith: event)
        } else if modifiers == .command && event.clickCount == 1 {
            addCaret(startingWith: event)
        } else {
            super.mouseDown(with: event)
        }
    }

    /// Follows the mouse until it's released, calling `update` with each location.
    private func trackMouse(startingWith event: NSEvent, update: (NSPoint) -> Void) {
        update(convert(event.locationInWindow, from: nil))
        while let next = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            autoscroll(with: next)
            update(convert(next.locationInWindow, from: nil))
            if next.type == .leftMouseUp {
                break
            }
        }
    }

    /// ⌘-click adds a cursor, ⌘-drag adds a selection, ⌘-click on a cursor removes it.
    private func addCaret(startingWith event: NSEvent) {
        let existing = currentCarets
        let start = characterIndexForInsertion(at: convert(event.locationInWindow, from: nil))
        var head = start
        trackMouse(startingWith: event) { point in
            head = characterIndexForInsertion(at: point)
            setCarets(existing + [Caret(anchor: start, head: head)])
        }
        if head == start, existing.count > 1, let index = existing.firstIndex(of: Caret(start)) {
            var remaining = existing
            remaining.remove(at: index)
            setCarets(remaining)
        }
    }

    /// ⌥-drag puts a cursor on every line between the start and the mouse, selecting
    /// from the start column to the mouse's column. Short lines get a cursor at their end.
    private func selectColumn(startingWith event: NSEvent) {
        let start = convert(event.locationInWindow, from: nil)
        let lineHeight = caretRect(at: selectedRange().location)?.height ?? 16
        trackMouse(startingWith: event) { point in
            let top = max(min(start.y, point.y), bounds.minY)
            let bottom = min(max(start.y, point.y), bounds.maxY)
            var columns: [Caret] = []
            var y = top
            while y <= bottom + 0.5 {
                let anchor = characterIndexForInsertion(at: NSPoint(x: start.x, y: y))
                let head = characterIndexForInsertion(at: NSPoint(x: point.x, y: y))
                columns.append(Caret(anchor: anchor, head: head))
                y += lineHeight
            }
            setCarets(columns)
        }
    }

    // MARK: Commands

    /// Adds a cursor on the line above the topmost cursor.
    @IBAction func addCursorAbove(_ sender: Any?) {
        addCaretVertically(above: true)
    }

    /// Adds a cursor on the line below the bottommost cursor.
    @IBAction func addCursorBelow(_ sender: Any?) {
        addCaretVertically(above: false)
    }

    private func addCaretVertically(above: Bool) {
        let existing = currentCarets
        guard let edge = above ? existing.first : existing.last,
              let rect = caretRect(at: edge.head) else { return }
        let y = above ? rect.minY - rect.height / 2 : rect.maxY + rect.height / 2
        guard y >= bounds.minY, y <= bounds.maxY else {
            NSSound.beep()
            return
        }
        let index = characterIndexForInsertion(at: NSPoint(x: rect.minX, y: y))
        guard index != edge.head else {
            NSSound.beep()
            return
        }
        setCarets(existing + [Caret(index)])
        scrollRangeToVisible(NSRange(location: index, length: 0))
    }

    /// Selects the word at the cursor, or adds a selection at the next match of the last selection.
    @IBAction func selectNextOccurrence(_ sender: Any?) {
        let existing = currentCarets
        guard let last = existing.last else { return }
        if existing.count == 1 && last.isEmpty {
            setSelectedRange(selectionRange(forProposedRange: last.range, granularity: .selectByWord))
            return
        }
        let text = string as NSString
        guard !last.isEmpty,
              let found = MultiCursor.nextOccurrence(of: text.substring(with: last.range), in: text,
                                                      after: NSMaxRange(last.range), excluding: existing.map { $0.range }) else {
            NSSound.beep()
            return
        }
        setCarets(existing + [Caret(range: found)])
        scrollRangeToVisible(found)
    }

    /// Selects every match of the selection (or of the word at the cursor).
    @IBAction func selectAllOccurrences(_ sender: Any?) {
        guard let last = currentCarets.last else { return }
        let range = last.isEmpty ? selectionRange(forProposedRange: last.range, granularity: .selectByWord) : last.range
        let text = string as NSString
        let matches = MultiCursor.occurrences(of: text.substring(with: range), in: text)
        guard !matches.isEmpty else {
            NSSound.beep()
            return
        }
        setCarets(matches.map { Caret(range: $0) })
    }

    /// Turns each selection into one selection per line.
    @IBAction func splitSelectionIntoLines(_ sender: Any?) {
        let text = string as NSString
        let lines = currentCarets.flatMap { MultiCursor.lines(in: $0.range, of: text) }
        setCarets(lines.map { Caret(range: $0) })
    }
}

/// Draws the insertion points of every cursor, above the text and out of the way of clicks.
final class CaretOverlayView: NSView {

    var carets: [NSRect] = [] {
        didSet { needsDisplay = true }
    }
    var color: NSColor = .textColor
    var isOn = true

    override var isFlipped: Bool {
        return true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    override func draw(_ dirtyRect: NSRect) {
        guard isOn else { return }
        color.setFill()
        for caret in carets where caret.intersects(dirtyRect) {
            caret.fill()
        }
    }
}
