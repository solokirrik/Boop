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

    override func viewDidLoad() {
        super.viewDidLoad()

        installCompatibleLayoutManager()

        editorView.delegate = self
        editorView.contentTextView.selectedTextAttributes = [.backgroundColor: NSColor.selectedTextBackgroundColor]
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
