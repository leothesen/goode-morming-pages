import CoreGraphics

/// Every measurement in the writing surface, derived from Ensō's shipped stylesheet.
///
/// Ensō sets a 22px root and a 1.6 line unit (`--ru`), then expresses everything
/// in multiples of that unit. Keeping the same derivation here means the layout
/// stays internally consistent if the base size ever changes.
enum Metrics {
    /// Root type size. Everything below is a multiple of this.
    static let baseFontSize: CGFloat = 22

    /// Ensō's `--ru`. One line unit.
    static let lineUnit: CGFloat = 1.6

    /// 35.2pt. The single most important number in the app: the scrims, the
    /// window height and the scroll offset are all multiples of it.
    static let lineHeight: CGFloat = baseFontSize * lineUnit

    /// Lines visible in the writing window. The last one is the one you write on.
    static let visibleLines: Int = 5

    /// Lines covered by a scrim. Always `visibleLines - 1`.
    static let scrimLines: Int = visibleLines - 1

    /// 176pt.
    static let windowHeight: CGFloat = lineHeight * CGFloat(visibleLines)

    /// 550pt — Ensō's `max-width: 25rem`.
    static let measure: CGFloat = baseFontSize * 25

    /// 35.2pt — Ensō's `padding: 0 calc(var(--ru) * 1rem)`.
    static let horizontalPadding: CGFloat = lineHeight

    /// -88pt. The writing block sits above the vertical centre, not on it.
    static let verticalOffset: CGFloat = -lineHeight * 2.5

    /// Top line first. The topmost line is almost entirely erased; the line
    /// directly above the caret is only dimmed.
    static let scrimOpacities: [CGFloat] = [0.98, 0.92, 0.85, 0.70]

    /// Where the caret's line should sit so that it lands in the one uncovered
    /// slot at the bottom of the window.
    ///
    /// - Parameter caretLineMaxY: The bottom edge of the caret's line fragment,
    ///   measured from the top of the text content.
    /// - Returns: The y origin to place the text view at, in a flipped container.
    ///
    /// On an empty buffer this returns `windowHeight - lineHeight` (140.8), which
    /// pushes the first line down into the bottom slot rather than leaving it
    /// under the heaviest scrim.
    static func textOffset(caretLineMaxY: CGFloat) -> CGFloat {
        windowHeight - caretLineMaxY
    }
}
