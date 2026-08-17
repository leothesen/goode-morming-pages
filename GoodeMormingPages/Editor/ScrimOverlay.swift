import SwiftUI

/// Four bars of the page colour laid over the lines above the caret.
///
/// They **erase** rather than dim — which is why the ground behind them must stay
/// flat and opaque. Put a translucent material behind the editor and these bars
/// stop matching their backdrop, turning a smooth dissolve into four hard edges.
struct ScrimOverlay: View {
    let theme: Theme

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<Metrics.scrimOpacities.count, id: \.self) { index in
                Rectangle()
                    .fill(theme.page)
                    .opacity(Metrics.scrimOpacities[index])
                    .frame(height: Metrics.lineHeight)
            }
            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
    }
}
