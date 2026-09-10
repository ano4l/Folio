import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    var onAskTap: () -> Void = {}
    @State private var isRefreshing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Welcome back, Alex")
                    .font(AppFont.headlineLarge())
                    .foregroundColor(AppColors.ink)
                Spacer(minLength: 4)
                Text("Encrypted document vault & AI retrieval assistant active.")
                    .font(AppFont.bodyMedium())
                    .foregroundColor(AppColors.slate)
                Spacer(minLength: 24)

                HStack(spacing: 10) {
                    StatCard(icon: "doc.text.fill", label: "Documents", value: state.documents.count, color: AppColors.teal, bg: AppColors.tealLight)
                    StatCard(icon: "clock.fill", label: "Pending", value: state.pendingCount, color: AppColors.warning, bg: AppColors.warningLight)
                    StatCard(icon: "shield.fill", label: "Audit events", value: state.auditLogs.count, color: AppColors.navy, bg: AppColors.navyLight)
                }
                Spacer(minLength: 28)

                SectionTitle("Ask your documents")
                Spacer(minLength: 10)
                Button(action: {
                    Haptics.play(.lightImpact)
                    onAskTap()
                }) {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.white)
                                    .symbolBounce(value: state.chatMessages.count)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ask Folio AI").font(AppFont.bodyLarge().weight(.bold)).foregroundStyle(.white)
                            Text("Grounded search across all vault files…")
                                .font(AppFont.bodyMedium())
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(18)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0x007AFF), Color(hex: 0x0A84FF), Color(hex: 0x5856D6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: AppColors.teal.opacity(0.25), radius: 14, y: 6)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Ask Folio AI about your documents")
                Spacer(minLength: 28)

                SectionTitle("Recent documents")
                Spacer(minLength: 10)
                GroupedCard(data: Array(state.documents.prefix(3)), separatorInset: 64) { doc in
                    Button(action: { state.selectDoc(doc) }) {
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.tealLight)
                                .frame(width: 42, height: 42)
                                .overlay(Image(systemName: "doc.text").foregroundStyle(AppColors.teal))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(doc.title)
                                    .font(AppFont.bodyMedium().weight(.semibold))
                                    .foregroundColor(AppColors.ink)
                                    .lineLimit(1)
                                Text("\(doc.date) · \(doc.pages) pgs · \(doc.confidence)% OCR")
                                    .font(AppFont.labelSmall())
                                    .foregroundColor(AppColors.slate)
                            }
                            Spacer()
                            DocTypeBadge(type: doc.type)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                    }
                    .buttonStyle(PressableStyle())
                }
                Spacer(minLength: 28)

                SectionTitle("Urgent deadlines")
                Spacer(minLength: 10)
                let pending = state.deadlines.filter { !$0.completed }
                GroupedCard(data: pending, separatorInset: 64) { d in
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(severityBg(d.severity))
                            .frame(width: 42, height: 42)
                            .overlay(Image(systemName: "calendar").foregroundStyle(severityColor(d.severity)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.action).font(AppFont.bodyMedium().weight(.semibold)).foregroundColor(AppColors.ink)
                            Text("\(d.doc) · due \(d.due)").font(AppFont.labelSmall()).foregroundColor(AppColors.slate)
                        }
                        Spacer()
                        Text("\(d.days) days")
                            .font(AppFont.chrome(12, .bold))
                            .foregroundColor(AppColors.warning)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.warningLight))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .contextMenu {
                        Button {
                            state.resolveDeadline(d.id)
                            Haptics.play(.success)
                        } label: {
                            Label("Mark as complete", systemImage: "checkmark.circle")
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        // Standard system pull-to-refresh gesture, with a haptic on completion.
        .refreshable {
            isRefreshing = true
            try? await Task.sleep(nanoseconds: 700_000_000)
            isRefreshing = false
            Haptics.play(.lightImpact)
        }
    }

    private func severityColor(_ s: String) -> Color {
        switch s {
        case "high": return AppColors.danger
        case "medium": return AppColors.warning
        default: return AppColors.teal
        }
    }
    private func severityBg(_ s: String) -> Color {
        switch s {
        case "high": return AppColors.dangerLight
        case "medium": return AppColors.warningLight
        default: return AppColors.tealLight
        }
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(AppFont.headlineSmall()).foregroundColor(AppColors.ink)
    }
}

struct StatCard: View {
    let icon: String
    let label: String
    let value: Int
    let color: Color
    let bg: Color

    var body: some View {
        SurfaceCard(cornerRadius: 18, padding: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)) {
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(bg)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: icon)
                            .font(AppFont.chrome(15))
                            .foregroundStyle(color)
                            .symbolBounce(value: value)
                    )
                // Digits roll like Fitness/Stocks instead of hard-cutting.
                Text("\(value)")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundColor(AppColors.ink)
                    .numericRoll(value: value)
                Text(label)
                    .font(AppFont.chrome(11, .medium))
                    .foregroundColor(AppColors.slate)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
