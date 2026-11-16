//
//  EditorView.swift
//  Boop
//
//  Created by Kirill on 11/16/26.
//

import Cocoa

protocol EditorViewDelegate: AnyObject {
    func editorDidChangeText(_ editor: EditorView)
}

/// The text editor: a standard NSTextView in a scroll view, with Boop's syntax colors.
final class EditorView: NSView {

    weak var delegate: EditorViewDelegate?

    let scrollView = NSScrollView()
    let contentTextView: EditorTextView

    private var pendingHighlight: DispatchWorkItem?
    private var highlightGeneration = 0
    private static let highlightQueue = DispatchQueue(label: "boop.syntax-highlight", qos: .userInitiated)

    /// Up to this size (UTF-16 units) text is colored on every keystroke; larger texts
    /// are lexed in the background once typing pauses (~400 ms per MB to lex).
    private static let instantHighlightLength = 20_000

    var text: String {
        return contentTextView.string
    }

    private var theme: EditorTheme {
        return EditorTheme(appearance: effectiveAppearance)
    }

    required init?(coder: NSCoder) {
        contentTextView = EditorView.makeTextView()
        super.init(coder: coder)
        setUp()
    }

    override init(frame frameRect: NSRect) {
        contentTextView = EditorView.makeTextView()
        super.init(frame: frameRect)
        setUp()
    }

    private static func makeTextView() -> EditorTextView {
        if #available(macOS 12.0, *) {
            return EditorTextView(usingTextLayoutManager: true)
        }
        return EditorTextView()
    }

    private func setUp() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        let textView = contentTextView
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 4, height: 6)

        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        // It's a code scratchpad: keep quotes and dashes exactly as typed
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        scrollView.documentView = textView
        applyTheme()

        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)),
                                               name: NSText.didChangeNotification, object: textView)
        NotificationCenter.default.addObserver(self, selector: #selector(transparencyDidChange),
                                               name: WindowTransparency.didChangeNotification, object: nil)
    }

    @objc private func transparencyDidChange() {
        contentTextView.backgroundColor = theme.backgroundColor.withAlphaComponent(1 - WindowTransparency.level)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyTheme()
    }

    private func applyTheme() {
        let theme = self.theme
        let textView = contentTextView
        textView.font = theme.font
        textView.textColor = theme.textColor
        textView.backgroundColor = theme.backgroundColor.withAlphaComponent(1 - WindowTransparency.level)
        textView.drawsBackground = true
        textView.insertionPointColor = theme.textColor
        textView.typingAttributes = theme.baseAttributes
        textView.tabWidth = theme.tabWidth
        highlightNow()
    }

    @objc private func textDidChange(_ notification: Notification) {
        highlightNow()
        delegate?.editorDidChangeText(self)
    }

    /// Colors small texts right away; large ones in the background after a short pause.
    private func highlightNow() {
        pendingHighlight?.cancel()
        pendingHighlight = nil
        highlightGeneration += 1
        guard let storage = contentTextView.textStorage else { return }

        if storage.length <= EditorView.instantHighlightLength {
            SyntaxHighlighter.apply(SyntaxHighlighter.paint(storage.string), to: storage, theme: theme)
            return
        }

        let generation = highlightGeneration
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, generation == self.highlightGeneration else { return }
            let source = storage.string // copy; lexing happens off the main thread
            let theme = self.theme
            EditorView.highlightQueue.async {
                let paint = SyntaxHighlighter.paint(source)
                DispatchQueue.main.async { [weak self] in
                    // Drop results if the text changed while lexing
                    guard let self = self, generation == self.highlightGeneration,
                          storage.string == source else { return }
                    SyntaxHighlighter.apply(paint, to: storage, theme: theme)
                }
            }
        }
        pendingHighlight = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }
}

/// NSTextView with code-editor typing: Tab inserts spaces, Return keeps the indentation.
final class EditorTextView: NSTextView {

    var tabWidth = 4

    override func insertTab(_ sender: Any?) {
        insertText(String(repeating: " ", count: tabWidth), replacementRange: selectedRange())
    }

    override func insertNewline(_ sender: Any?) {
        let text = string as NSString
        let lineRange = text.lineRange(for: NSRange(location: selectedRange().location, length: 0))
        let line = text.substring(with: lineRange)
        let indentation = line.prefix { $0 == " " || $0 == "\t" }
        insertText("\n" + indentation, replacementRange: selectedRange())
    }
}
