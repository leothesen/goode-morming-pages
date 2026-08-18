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

    // MARK: - The word goal

    /// A hairline. Thin enough to read as a rule rather than a widget.
    static let goalBarHeight: CGFloat = 2

    /// The unreached part of the goal, drawn behind the fill.
    ///
    /// Without it the bar has zero width at zero words, so the empty morning
    /// renders nothing at all -- indistinguishable from having no goal set.
    static let goalBedOpacity: CGFloat = 0.09

    /// How far the bar swells at the moment you arrive, scaled from its bottom
    /// edge so the swell costs no layout.
    static let goalSwellScale: CGFloat = 2.5

    /// The rise, then the settle. A single beat: long enough to be seen, short
    /// enough that it is over before it becomes a thing being watched.
    static let goalSwellRise: Double = 0.25
    static let goalSwellFall: Double = 0.4

    /// How far through the goal you are, clamped so writing past it doesn't
    /// overflow the window. A goal of zero has no fraction -- it isn't a goal.
    static func goalFraction(count: Int, goal: Int) -> Double {
        guard goal > 0, count > 0 else { return 0 }
        return min(Double(count) / Double(goal), 1)
    }

    /// Whether to show the number as well as the line.
    ///
    /// The bar carries progress; the number only appears once you have arrived,
    /// when it stops being a target and becomes a fact. With no goal set the bar
    /// has nothing to fill, so the number is all there is.
    static func showsWordCount(hasHitGoal: Bool, goal: Int) -> Bool {
        hasHitGoal || goal == 0
    }

    // MARK: - The toolbar

    /// The band at the top of the window that reveals the toolbar.
    ///
    /// The controls themselves are invisible until shown, so making them their
    /// own hover target means you have to already know where they are. Sensing
    /// the whole strip makes "move the pointer up" work, which is what everyone
    /// does when they want the chrome back.
    static let toolbarHoverHeight: CGFloat = 72

    /// Whether a point in the editor's coordinate space should show the toolbar.
    static func isInToolbarZone(y: CGFloat) -> Bool {
        y >= 0 && y <= toolbarHoverHeight
    }

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
