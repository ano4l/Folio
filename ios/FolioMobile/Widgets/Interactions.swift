import SwiftUI
import UIKit

/// Apple-grade tactile feedback.
///
/// On iOS 17+ SwiftUI's `.sensoryFeedback` is preferred because the system
/// coalesces haptics, respects the user's System Haptics setting, and avoids
/// the engine spin-up cost of manually managed generators. Older releases fall
/// back to `UIFeedbackGenerator`.
enum Haptics {
    enum Kind {
        case selection      // tab / segment change
        case lightImpact    // button, chip
        case success        // deadline resolved, upload done, auth passed
        case warning        // out of credits
        case error          // destructive / failed action
    }

    static func play(_ kind: Kind) {
        switch kind {
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .lightImpact:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

extension View {
    /// Fires haptic feedback whenever `value` changes, using the modern
    /// `.sensoryFeedback` API when available.
    @ViewBuilder
    func hapticFeedback<V: Equatable>(_ kind: Haptics.Kind, trigger value: V) -> some View {
        if #available(iOS 17.0, *) {
            self.sensoryFeedback(kind.sensoryFeedback, trigger: value)
        } else {
            self.onChange(of: value) { _ in Haptics.play(kind) }
        }
    }

    /// SF Symbol bounce on state change (iOS 17+). No-op on earlier releases so
    /// the symbol simply renders statically instead of faking an animation.
    @ViewBuilder
    func symbolBounce<V: Equatable>(value: V) -> some View {
        if #available(iOS 17.0, *) {
            self.symbolEffect(.bounce, options: .speed(1.4), value: value)
        } else {
            self
        }
    }

    /// Animated digit roll for counters (credits, stats), matching the
    /// system behaviour in Fitness and Stocks.
    @ViewBuilder
    func numericRoll<V: Equatable>(value: V) -> some View {
        if #available(iOS 17.0, *) {
            self.contentTransition(.numericText())
                .animation(.snappy(duration: 0.35), value: value)
        } else {
            self
        }
    }

    /// Registers a custom bar so scrolling content fades out beneath it,
    /// preserving legibility exactly as system toolbars do.
    @ViewBuilder
    func softScrollEdge(_ edge: VerticalEdge) -> some View {
        if #available(iOS 17.0, *) {
            self.background(
                LinearGradient(
                    colors: [AppColors.paper.opacity(edge == .top ? 0.9 : 0),
                             AppColors.paper.opacity(edge == .top ? 0 : 0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            )
        } else {
            self
        }
    }

    /// Applies sheet detents + a visible grabber where supported.
    @ViewBuilder
    func appleSheet(detents: Set<PresentationDetent> = [.large]) -> some View {
        self.presentationDetents(detents)
            .presentationDragIndicator(.visible)
    }
}

@available(iOS 17.0, *)
private extension Haptics.Kind {
    var sensoryFeedback: SensoryFeedback {
        switch self {
        case .selection: return .selection
        case .lightImpact: return .impact(weight: .light)
        case .success: return .success
        case .warning: return .warning
        case .error: return .error
        }
    }
}
