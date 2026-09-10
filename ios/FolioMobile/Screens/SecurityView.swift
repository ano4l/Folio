import SwiftUI
import UIKit

struct SecurityView: View {
    @EnvironmentObject var state: AppState
    @State private var categoryFilter: String? = nil

    private let categoryColors: [String: Color] = [
        "Access": AppColors.teal,
        "AI Queries": AppColors.purple,
        "Security": AppColors.navy,
        "Document": AppColors.warning,
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Security & Compliance").font(AppFont.headlineMedium()).foregroundColor(AppColors.ink)
                Text("POPIA-aligned access controls and audit ledger")
                    .font(AppFont.bodyMedium()).foregroundColor(AppColors.slate)

                // Settings rows are content, not chrome, so they use the opaque
                // grouped surface Settings.app uses.
                SurfaceCard(cornerRadius: 18, padding: EdgeInsets()) {
                    VStack(spacing: 0) {
                        toggleRow(icon: "number", title: "Multi-factor authentication", subtitle: "Require 6-digit code on sign-in", isOn: $state.mfaEnabled)
                        Divider().padding(.leading, 56)
                        toggleRow(icon: "faceid", title: "Biometric unlock", subtitle: "Face ID / fingerprint passkey", isOn: $state.biometricEnabled)
                        Divider().padding(.leading, 56)
                        toggleRow(icon: "square.and.arrow.up", title: "Financial aid data share", subtitle: "Share verified documents with funders", isOn: $state.sharingEnabled)
                    }
                }

                Text("Immutable POPIA Access Ledger")
                    .font(AppFont.headlineSmall())
                    .foregroundColor(AppColors.ink)
                    .padding(.top, 8)
                Text("Every vault interaction is cryptographically logged and cannot be edited or removed.")
                    .font(AppFont.labelSmall()).foregroundColor(AppColors.slate)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        LedgerChip(title: "All", tint: AppColors.slate, selected: categoryFilter == nil) {
                            categoryFilter = nil
                        }
                        ForEach(orderedCategories, id: \.self) { cat in
                            LedgerChip(
                                title: cat,
                                tint: categoryColors[cat] ?? AppColors.slate,
                                selected: categoryFilter == cat
                            ) {
                                categoryFilter = categoryFilter == cat ? nil : cat
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollClipDisabledIfAvailable()

                ForEach(visibleLogs) { log in
                    let c = categoryColors[log.category] ?? AppColors.slate
                    SurfaceCard(cornerRadius: 16, padding: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)) {
                        HStack(alignment: .top, spacing: 12) {
                            Text(log.category)
                                .font(AppFont.chrome(10, .bold))
                                .foregroundColor(c)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(c.opacity(0.12)))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(log.action)
                                    .font(AppFont.bodyMedium().weight(.semibold))
                                    .foregroundColor(AppColors.ink)
                                Text(log.detail)
                                    .font(AppFont.labelSmall())
                                    .foregroundColor(AppColors.slate)
                                Text("\(log.actor) · \(log.time)")
                                    .font(AppFont.chrome(11))
                                    .foregroundColor(AppColors.slate)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = "\(log.category) — \(log.action)\n\(log.detail)\n\(log.actor) · \(log.time)"
                            Haptics.play(.success)
                        } label: {
                            Label("Copy ledger entry", systemImage: "doc.on.doc")
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: categoryFilter)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 110)
        }
    }

    private var orderedCategories: [String] {
        var seen: [String] = []
        for log in state.auditLogs where !seen.contains(log.category) {
            seen.append(log.category)
        }
        return seen
    }

    private var visibleLogs: [AuditEntry] {
        guard let filter = categoryFilter else { return state.auditLogs }
        return state.auditLogs.filter { $0.category == filter }
    }

    private func toggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.tealLight)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(AppFont.chrome(16))
                        .foregroundStyle(AppColors.teal)
                        .symbolBounce(value: isOn.wrappedValue)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.bodyMedium().weight(.semibold))
                    .foregroundColor(AppColors.ink)
                Text(subtitle)
                    .font(AppFont.labelSmall())
                    .foregroundColor(AppColors.slate)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(AppColors.teal)
                .hapticFeedback(.selection, trigger: isOn.wrappedValue)
                // Labelled on the control itself so VoiceOver can still toggle it.
                .accessibilityLabel(title)
                .accessibilityHint(subtitle)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

private struct LedgerChip: View {
    let title: String
    let tint: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { action() }
            Haptics.play(.selection)
        } label: {
            Text(title)
                .font(AppFont.chrome(12, .semibold))
                .foregroundColor(selected ? .white : tint)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(selected ? tint : tint.opacity(0.12)))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
