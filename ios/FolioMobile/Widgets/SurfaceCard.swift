import SwiftUI

/// Solid content surface.
///
/// Apple's Liquid Glass guidance is explicit: glass is a *layer above* the
/// content, reserved for navigation and controls. Content itself — especially
/// dense text like document summaries, OCR output, and audit entries — belongs
/// on an opaque surface, because "Liquid Glass over dense text is a legibility
/// disaster". Apple's own Mail app follows the same split: glass toolbar,
/// solid message body. `SurfaceCard` is that solid body layer.
struct SurfaceCard<Content: View>: View {
    var cornerRadius: CGFloat = 18
    var padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    var onTap: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let inner = content()
            .padding(padding)
            .background(shape.fill(AppColors.card))
            .overlay(shape.stroke(AppColors.line.opacity(0.6), lineWidth: 0.5))
            .shadow(color: Color.black.opacity(0.04), radius: 10, y: 3)

        if let onTap = onTap {
            Button(action: onTap) { inner }
                .buttonStyle(PressableStyle())
        } else {
            inner
        }
    }
}

/// Apple-style grouped inset list container: one solid surface, hairline
/// separators inset to the content edge, matching Settings.app.
struct GroupedCard<Data: RandomAccessCollection, Row: View>: View where Data.Element: Identifiable {
    let data: Data
    var cornerRadius: CGFloat = 18
    var separatorInset: CGFloat = 16
    @ViewBuilder var row: (Data.Element) -> Row

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        VStack(spacing: 0) {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, element in
                row(element)
                if index < data.count - 1 {
                    Divider()
                        .padding(.leading, separatorInset)
                }
            }
        }
        .background(shape.fill(AppColors.card))
        .overlay(shape.stroke(AppColors.line.opacity(0.6), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 3)
    }
}
