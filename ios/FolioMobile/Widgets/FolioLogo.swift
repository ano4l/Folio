import SwiftUI

struct FolioLogo: View {
    var size: CGFloat = 40

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x0A84FF), Color(hex: 0x007AFF), Color(hex: 0x5856D6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: AppColors.teal.opacity(0.3), radius: size * 0.3, x: 0, y: size * 0.1)
                .overlay(
                    Image(systemName: "doc.text.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.white)
                        .frame(width: size * 0.5, height: size * 0.5)
                )

            Text("Folio")
                .font(.system(size: size * 0.55, weight: .bold))
                .foregroundColor(AppColors.ink)
                .tracking(-0.6)
        }
    }
}
