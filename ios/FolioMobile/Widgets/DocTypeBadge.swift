import SwiftUI

struct DocTypeBadge: View {
    let type: String

    private struct Style {
        let label: String
        let fg: Color
        let bg: Color
    }

    private static let styles: [String: Style] = [
        "Funding Award Letter": Style(label: "Funding", fg: AppColors.warning, bg: AppColors.warningLight),
        "Bursary Agreement": Style(label: "Bursary", fg: AppColors.teal, bg: AppColors.tealLight),
        "Fee Statement": Style(label: "Fees", fg: AppColors.navy, bg: AppColors.navyLight),
        "Bank Letter": Style(label: "Bank", fg: AppColors.purple, bg: AppColors.purpleLight),
        "Appeal Correspondence": Style(label: "Appeal", fg: AppColors.danger, bg: AppColors.dangerLight),
    ]

    var body: some View {
        let style = Self.styles[type] ?? Style(label: "Doc", fg: AppColors.slate, bg: AppColors.paper)
        Text(style.label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(style.fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(style.bg.opacity(0.85))
            )
            .overlay(
                Capsule().stroke(style.fg.opacity(0.2), lineWidth: 0.5)
            )
    }
}
