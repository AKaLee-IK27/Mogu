import SwiftUI

/// Personalized loading state shared by the scan/preview screens.
///
/// One shape, per-feature identity: each screen passes its own SF Symbol,
/// accent `tint`, and copy, so the loading view reads as *that* feature
/// rather than a generic spinner. The indeterminate arc is the primary
/// motion; a tinted halo breathes subtly behind it. Keeping it to two
/// motions (arc + halo) avoids the busy "AI default" loader look.
struct FeatureLoadingView: View {
    let icon: String
    let tint: SwiftUI.Color
    let title: String
    var subtitle: String? = nil

    @State private var spinning = false
    @State private var breathing = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Breathing tinted halo — subtle secondary motion.
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 76, height: 76)
                    .scaleEffect(breathing ? 1.0 : 0.82)
                    .opacity(breathing ? 0.9 : 0.45)

                // Static track the arc travels along.
                Circle()
                    .stroke(tint.opacity(0.15), lineWidth: 3)
                    .frame(width: 58, height: 58)

                // Indeterminate arc — primary motion.
                Circle()
                    .trim(from: 0, to: 0.22)
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 58, height: 58)
                    .rotationEffect(.degrees(spinning ? 360 : 0))

                // Feature mark — holds still at the center.
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    spinning = true
                }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    breathing = true
                }
            }

            VStack(spacing: 5) {
                Text(title)
                    .font(DesignTokens.Font.bodyStrong)
                    .foregroundStyle(DesignTokens.Color.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Font.caption)
                        .foregroundStyle(DesignTokens.Color.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}
