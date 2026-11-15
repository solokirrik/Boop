//
//  MainViewController.swift
//  Boop
//
//  Created by Ivan on 1/26/19.
//

import Cocoa
import SavannaKit

class MainViewController: NSViewController {

    @IBOutlet weak var editorView: SyntaxTextView!

    /// Called on every user edit with the editor's full text.
    var onTextChange: ((String) -> Void)?

    private var isLoading = false
    private let emptyHint = EmptyEditorHint()

    override func viewDidLoad() {
        super.viewDidLoad()

        installCompatibleLayoutManager()

        editorView.delegate = self
        editorView.contentTextView.selectedTextAttributes = [.backgroundColor: NSColor.selectedTextBackgroundColor]

        emptyHint.translatesAutoresizingMaskIntoConstraints = false
        editorView.addSubview(emptyHint)
        NSLayoutConstraint.activate([
            emptyHint.centerXAnchor.constraint(equalTo: editorView.centerXAnchor),
            emptyHint.centerYAnchor.constraint(equalTo: editorView.centerYAnchor)
        ])
        updateEmptyHint()
    }

    /// Shown while the editor is empty: first launch, new and cleared tabs.
    private func updateEmptyHint() {
        emptyHint.isHidden = !editorView.contentTextView.string.isEmpty
    }

    /// Replaces the editor content without reporting it as an edit.
    func load(text: String) {
        isLoading = true
        let textView = editorView.contentTextView
        textView.string = text
        textView.didChangeText()
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.undoManager?.removeAllActions()
        isLoading = false
        updateEmptyHint()
    }

    private func installCompatibleLayoutManager() {
        guard let textStorage = editorView.contentTextView.textStorage,
              let textContainer = editorView.contentTextView.textContainer,
              let currentLayoutManager = editorView.contentTextView.layoutManager,
              let containerIndex = currentLayoutManager.textContainers.firstIndex(where: { $0 === textContainer }) else {
            return
        }

        let layoutManager = NSLayoutManager()
        currentLayoutManager.removeTextContainer(at: containerIndex)
        textStorage.removeLayoutManager(currentLayoutManager)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
    }

    func clear() {
        let textView = editorView.contentTextView
        textView.textStorage?.beginEditing()

        let range = NSRange(location: 0, length: textView.textStorage?.length ?? textView.string.count)

        guard textView.shouldChangeText(in: range, replacementString: "") else {
            return
        }

        textView.textStorage?.replaceCharacters(in: range, with: "")

        textView.textStorage?.endEditing()
        textView.didChangeText()
    }
}

extension MainViewController: SyntaxTextViewDelegate {
    func theme(for appearance: NSAppearance) -> SyntaxColorTheme {
        return DefaultTheme(appearance: appearance)
    }

    func didChangeText(_ syntaxTextView: SyntaxTextView) {
        updateEmptyHint()
        guard !isLoading else { return }
        onTextChange?(syntaxTextView.contentTextView.string)
    }

    func didChangeSelectedRange(_ syntaxTextView: SyntaxTextView, selectedRange: NSRange) {

    }

    func didChangeFont(_ font: Font) {
        //
    }

    func lexerForSource(_ source: String) -> Lexer {
        return BoopLexer()
    }
}

/// "What can I do here?" for an empty editor, in the style of VS Code and Zed.
/// It never takes clicks, so typing and pasting work as usual.
final class EmptyEditorHint: NSView {

    private static let rows: [(String, String)] = [
        ("Run a script", "⌘P"),
        ("Repeat last script", "⇧⌘B"),
        ("New tab", "⌘T")
    ]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        let intro = NSTextField(labelWithString: "Paste or type some text, then")
        intro.font = .systemFont(ofSize: 13)
        intro.textColor = .tertiaryLabelColor

        let grid = NSGridView(views: EmptyEditorHint.rows.map { title, keys in
            let label = NSTextField(labelWithString: title)
            label.font = .systemFont(ofSize: 13)
            label.textColor = .secondaryLabelColor
            let shortcut = NSTextField(labelWithString: keys)
            shortcut.font = .systemFont(ofSize: 13, weight: .medium)
            shortcut.textColor = .tertiaryLabelColor
            return [label, shortcut]
        })
        grid.columnSpacing = 24
        grid.rowSpacing = 8
        grid.column(at: 1).xPlacement = .trailing

        let stack = NSStackView(views: [intro, grid])
        stack.orientation = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("EmptyEditorHint is created in code")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}
