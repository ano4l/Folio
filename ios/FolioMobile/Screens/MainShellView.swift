import SwiftUI

struct MainShellView: View {
    @EnvironmentObject var state: AppState
    @State private var tabIndex: Int = 0
    @State private var showNotifications: Bool = false
    @Namespace private var dockPill

    private let titles = ["Dashboard", "Documents", "Ask AI", "Deadlines", "Security"]

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                topBar
                ZStack {
                    DashboardView(onAskTap: { select(2) }).opacity(tabIndex == 0 ? 1 : 0)
                    DocumentsView().opacity(tabIndex == 1 ? 1 : 0)
                    AskAIView().opacity(tabIndex == 2 ? 1 : 0)
                    DeadlinesView().opacity(tabIndex == 3 ? 1 : 0)
                    SecurityView().opacity(tabIndex == 4 ? 1 : 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(AppColors.paper.ignoresSafeArea())

            dock
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        // Haptic confirmation on every tab switch, exactly like the system tab bar.
        .hapticFeedback(.selection, trigger: tabIndex)
        .sheet(isPresented: $showNotifications) {
            NotificationsSheet()
                .environmentObject(state)
                .appleSheet(detents: [.medium, .large])
        }
    }

    private func select(_ index: Int) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            tabIndex = index
        }
    }

    private var topBar: some View {
        HStack {
            Text(titles[tabIndex])
                .font(AppFont.headlineSmall())
                .foregroundColor(AppColors.ink)
                .contentTransitionIfAvailable(value: tabIndex)
            Spacer()

            Button(action: { showNotifications = true }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: state.pendingCount > 0 ? "bell.badge" : "bell")
                        .font(AppFont.chrome(18))
                        .foregroundColor(AppColors.ink)
                        .frame(width: 30, height: 30)
                        .symbolBounce(value: state.pendingCount)
                    if state.pendingCount > 0 {
                        Text("\(state.pendingCount)")
                            .font(AppFont.chrome(9, .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 15, minHeight: 15)
                            .background(Circle().fill(AppColors.danger))
                            .offset(x: 4, y: -2)
                            .numericRoll(value: state.pendingCount)
                    }
                }
            }
            .accessibilityLabel("Notifications")
            .accessibilityValue("\(state.pendingCount) pending deadlines")

            Menu {
                VStack(alignment: .leading) {
                    Text("Alex Mokoena").font(.system(size: 13, weight: .bold))
                    Text("alex.m@folio-student.app").font(.system(size: 11))
                    Text("Student Account").font(.system(size: 10))
                }
                Divider()
                Button(role: .destructive, action: { state.logout() }) {
                    Label("Sign out", systemImage: "power")
                }
            } label: {
                Circle()
                    .fill(AppColors.teal)
                    .frame(width: 30, height: 30)
                    .overlay(Text("AM").font(AppFont.chrome(11, .bold)).foregroundColor(.white))
                    .shadow(color: AppColors.teal.opacity(0.3), radius: 8)
            }
            .accessibilityLabel("Account menu")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        // The bar is chrome, so it takes the glass layer; content scrolls beneath it.
        .background(.bar)
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    }

    /// The dock is a single shared glass sample. Grouping matters: without a
    /// container, adjacent glass surfaces each sample their own backdrop and a
    /// seam appears between them, and the selection pill cannot morph.
    private var dock: some View {
        GlassGroup(spacing: 14) {
            GlassContainer(
                cornerRadius: 32,
                interactive: true,
                padding: EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
            ) {
                HStack(spacing: 0) {
                    DockItem(icon: "house", activeIcon: "house.fill", label: "Home", selected: tabIndex == 0, namespace: dockPill) { select(0) }
                    DockItem(icon: "doc.text", activeIcon: "doc.text.fill", label: "Docs", selected: tabIndex == 1, namespace: dockPill) { select(1) }
                    DockItem(icon: "bubble.left.and.bubble.right", activeIcon: "bubble.left.and.bubble.right.fill", label: "Ask AI", selected: tabIndex == 2, namespace: dockPill) { select(2) }
                    DockItem(icon: "calendar", activeIcon: "calendar.circle.fill", label: "Deadlines", selected: tabIndex == 3, namespace: dockPill) { select(3) }
                    DockItem(icon: "shield", activeIcon: "shield.fill", label: "Security", selected: tabIndex == 4, namespace: dockPill) { select(4) }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
    }
}

private struct DockItem: View {
    let icon: String
    let activeIcon: String
    let label: String
    let selected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: selected ? activeIcon : icon)
                    .font(AppFont.chrome(20))
                    .foregroundColor(selected ? AppColors.teal : AppColors.slate)
                    .symbolBounce(value: selected)
                Text(label)
                    .font(AppFont.chrome(10, selected ? .semibold : .medium))
                    .foregroundColor(selected ? AppColors.teal : AppColors.slate)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background {
                // The active pill slides between tabs instead of cross-fading,
                // which is the system tab-bar behaviour on iOS 26.
                if selected {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppColors.teal.opacity(0.14))
                        .matchedGeometryEffect(id: "dockPill", in: namespace)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

extension View {
    /// Cross-fades text content when a value changes (iOS 16+ safe).
    @ViewBuilder
    func contentTransitionIfAvailable<V: Equatable>(value: V) -> some View {
        self.animation(.easeInOut(duration: 0.2), value: value)
    }
}

private struct NotificationsSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        let pending = state.deadlines.filter { !$0.completed }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if pending.isEmpty {
                        // Apple-standard empty state rather than bare text.
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(AppColors.success)
                            Text("All caught up").font(AppFont.headlineSmall())
                            Text("No pending deadlines on your vault.")
                                .font(AppFont.bodyMedium())
                                .foregroundColor(AppColors.slate)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                    } else {
                        ForEach(pending) { d in
                            SurfaceCard(cornerRadius: 14, padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)) {
                                HStack {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(severityColor(d.severity))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(d.action).font(AppFont.bodyMedium().weight(.semibold))
                                        Text("\(d.doc) · due \(d.due)")
                                            .font(AppFont.labelSmall())
                                            .foregroundColor(AppColors.slate)
                                    }
                                    Spacer()
                                    Text("\(d.days)d left")
                                        .font(AppFont.chrome(11, .bold))
                                        .foregroundColor(AppColors.warning)
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.warningLight))
                                }
                            }
                            // Long-press affordance mirroring system context menus.
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
                }
                .padding(20)
            }
            .background(AppColors.paper.ignoresSafeArea())
            .navigationTitle("Pending Deadlines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func severityColor(_ severity: String) -> Color {
        switch severity {
        case "high": return AppColors.danger
        case "medium": return AppColors.warning
        default: return AppColors.teal
        }
    }
}
