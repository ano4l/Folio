import SwiftUI

/// Apple Liquid Glass surface.
///
/// Design rationale (per Apple's "Adopting Liquid Glass" guidance):
/// * On iOS 26+ this defers to the **real** system material via `.glassEffect(_:in:)`,
///   which gives true refraction, a specular highlight that tracks device pose,
///   and automatic adaptation to overlap/scroll-edge context.
/// * On iOS 16–18 it degrades to `.ultraThinMaterial` plus a hairline specular
///   border — the fallback Apple itself recommends, since `UIGlassEffect` has no
///   back-deployed equivalent.
/// * When **Reduce Transparency** is on, it renders an opaque surface so text
///   never loses contrast.
/// * `interactive` should only be set on surfaces the user actually touches;
///   the live warp costs an extra fullscreen sample per frame.
struct GlassContainer<Content: View>: View {
    var cornerRadius: CGFloat = 20
    var tint: Color? = nil
    var interactive: Bool = false
    var padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    var onTap: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let inner = content()
            .padding(padding)
            .glassSurface(
                cornerRadius: cornerRadius,
                tint: tint,
                interactive: interactive,
                reduceTransparency: reduceTransparency
            )

        if let onTap = onTap {
            Button(action: onTap) { inner }
                .buttonStyle(PressableStyle())
        } else {
            inner
        }
    }
}

/// Groups nearby glass surfaces so they share a single backdrop sample.
/// Apple treats this as a rendering *requirement*, not an optimisation:
/// glass cannot sample other glass, so ungrouped neighbours show a seam.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
    }
}

extension View {
    @ViewBuilder
    func glassSurface(
        cornerRadius: CGFloat,
        tint: Color? = nil,
        interactive: Bool = false,
        reduceTransparency: Bool = false
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if reduceTransparency {
            // Accessibility path: fully opaque, no blur, keeps AA contrast ratios.
            self.background(shape.fill(tint ?? AppColors.card))
                .overlay(shape.stroke(AppColors.line, lineWidth: 0.5))
        } else if #available(iOS 26.0, *) {
            // Native Liquid Glass. Note: no `.clipped()`/`.mask()` here — an
            // ancestor clip silently disables backdrop sampling.
            self.glassEffect(GlassStyleFactory.make(tint: tint, interactive: interactive), in: shape)
        } else {
            self.background(
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    if let tint = tint { shape.fill(tint.opacity(0.75)) }
                }
            )
            .overlay(shape.stroke(Color.white.opacity(0.55), lineWidth: 1))
            .clipShape(shape)
            .shadow(color: Color.black.opacity(0.06), radius: 16, y: 6)
        }
    }
}

/// Builds the concrete `Glass` value. Kept out of the `@ViewBuilder` so the
/// availability gate stays a single, easy-to-audit boundary.
@available(iOS 26.0, *)
enum GlassStyleFactory {
    static func make(tint: Color?, interactive: Bool) -> Glass {
        var glass: Glass = .regular
        if let tint = tint {
            // Apple blends tint ~30% in light and ~50% in dark, so keep brand
            // tints light-handed to avoid an opaque look in Dark Mode.
            glass = glass.tint(tint.opacity(0.7))
        }
        if interactive {
            glass = glass.interactive()
        }
        return glass
    }
}

/// Subtle Apple-style press response: scales down and dims briefly, and honours
/// Reduce Motion by dropping the scale change.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
