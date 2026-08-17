import AppKit
import SwiftUI

/// A plain text view whose selection is legal but invisible, mirroring Ensō's
/// `::selection { background: transparent }`.
///
/// Selection is deliberately not disabled: Copy has to keep working, and the
/// constraint against editing is social rather than enforced.
final class EditorTextView: NSTextView {
    /// Ensō kills the find bar; ⌘F in a five-line window is meaningless.
    override func performFindPanelAction(_ sender: Any?) {}
}

/// Holds the text view and slides it so the caret's line always lands in the
/// single uncovered slot at the bottom of the window.
///
/// Flipped so that y grows downward, which makes the offset arithmetic read the
/// same way as the CSS it came from.
final class PinnedTextHost: NSView {
    let textView: EditorTextView
    private let textLayout = NSLayoutManager()
    private let storage = NSTextStorage()
    private let container = NSTextContainer(
        size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
    )

    override var isFlipped: Bool { true }

    init(theme: Theme) {
        storage.addLayoutManager(textLayout)
        textLayout.addTextContainer(container)
        container.lineFragmentPadding = 0
        container.widthTracksTextView = false

        textView = EditorTextView(frame: .zero, textContainer: container)
        super.init(frame: .zero)

        clipsToBounds = true
        addSubview(textView)
        configure(theme: theme)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    private func configure(theme: Theme) {
        textView.isRichText = false
        textView.importsGraphics = false
        textView.drawsBackground = false
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = []
        textView.textContainerInset = NSSize(width: Metrics.horizontalPadding, height: 0)
        textView.font = Typeface.editor()
        textView.defaultParagraphStyle = Self.paragraphStyle
        textView.allowsUndo = true

        // Copy still works; you just cannot see what you selected.
        textView.selectedTextAttributes = [.backgroundColor: NSColor.clear]

        apply(theme: theme)
    }

    static var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = Metrics.lineHeight
        style.maximumLineHeight = Metrics.lineHeight
        style.lineSpacing = 0
        return style
    }

    func apply(theme: Theme) {
        textView.textColor = theme.inkNS
        textView.insertionPointColor = theme.inkNS
        textView.typingAttributes = [
            .font: Typeface.editor(),
            .foregroundColor: theme.inkNS,
            .paragraphStyle: Self.paragraphStyle,
        ]
        // Existing text keeps the attributes it was typed with, so restyle it too.
        let whole = NSRange(location: 0, length: storage.length)
        if whole.length > 0 {
            storage.addAttributes(
                [
                    .font: Typeface.editor(),
                    .foregroundColor: theme.inkNS,
                    .paragraphStyle: Self.paragraphStyle,
                ],
                range: whole
            )
        }
    }

    func apply(spelling: SpellingOptions) {
        textView.isContinuousSpellCheckingEnabled = spelling.checkSpelling
        textView.isAutomaticSpellingCorrectionEnabled = spelling.autocorrect
        textView.isAutomaticTextReplacementEnabled = spelling.autocorrect
        textView.isAutomaticQuoteSubstitutionEnabled = spelling.smartQuotes
        textView.isAutomaticDashSubstitutionEnabled = spelling.smartQuotes
    }

    override func layout() {
        super.layout()
        reposition()
    }

    /// Lays the text out at the current width, then positions it so the caret's
    /// line sits on the bottom row of the window.
    func reposition() {
        guard bounds.width > 0 else { return }

        textView.frame.size.width = bounds.width
        container.containerSize = NSSize(
            width: max(1, bounds.width - Metrics.horizontalPadding * 2),
            height: CGFloat.greatestFiniteMagnitude
        )
        textLayout.ensureLayout(for: container)

        let used = textLayout.usedRect(for: container).height
        textView.frame.size.height = max(used + Metrics.lineHeight, Metrics.windowHeight)
        textView.frame.origin = NSPoint(
            x: 0,
            y: Metrics.textOffset(caretLineMaxY: caretLineMaxY())
        )
    }

    /// Bottom edge of the caret's line fragment, measured from the top of the text.
    private func caretLineMaxY() -> CGFloat {
        let text = textView.string as NSString
        guard text.length > 0 else { return Metrics.lineHeight }

        let caret = min(textView.selectedRange().location, text.length)

        // A caret parked after a trailing newline belongs to the extra line
        // fragment, which has no glyphs and would otherwise report the line above.
        if caret == text.length,
           let scalar = text.substring(from: text.length - 1).unicodeScalars.first,
           CharacterSet.newlines.contains(scalar),
           textLayout.extraLineFragmentTextContainer != nil {
            return textLayout.extraLineFragmentRect.maxY
        }

        let charIndex = caret == text.length ? max(0, caret - 1) : caret
        let glyph = min(
            textLayout.glyphIndexForCharacter(at: charIndex),
            max(0, textLayout.numberOfGlyphs - 1)
        )
        return textLayout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).maxY
    }
}

/// SwiftUI wrapper.
struct ScrimTextView: NSViewRepresentable {
    @Binding var text: String
    let theme: Theme
    let spelling: SpellingOptions

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> PinnedTextHost {
        let host = PinnedTextHost(theme: theme)
        host.textView.delegate = context.coordinator
        host.apply(spelling: spelling)
        host.textView.string = text
        DispatchQueue.main.async {
            host.window?.makeFirstResponder(host.textView)
            host.reposition()
        }
        return host
    }

    func updateNSView(_ host: PinnedTextHost, context: Context) {
        context.coordinator.parent = self

        if host.textView.string != text {
            context.coordinator.isApplyingExternalChange = true
            host.textView.string = text
            host.textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
            context.coordinator.isApplyingExternalChange = false
        }
        host.apply(theme: theme)
        host.apply(spelling: spelling)
        host.reposition()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ScrimTextView
        var isApplyingExternalChange = false

        init(_ parent: ScrimTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let host = textView.superview as? PinnedTextHost else { return }
            host.reposition()
            guard !isApplyingExternalChange else { return }
            parent.text = textView.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let host = textView.superview as? PinnedTextHost else { return }
            host.reposition()
        }
    }
}
