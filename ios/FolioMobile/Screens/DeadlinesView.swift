import SwiftUI

struct DeadlinesView: View {
    @EnvironmentObject var state: AppState
    @State private var viewIndex = 0 // 0 = List, 1 = Calendar
    @State private var monthOffset = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Deadline Tracker").font(AppFont.headlineMedium()).foregroundColor(AppColors.ink)
                    Spacer()
                    Picker("View", selection: $viewIndex) {
                        Image(systemName: "list.bullet").tag(0)
                        Image(systemName: "calendar").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                    .hapticFeedback(.selection, trigger: viewIndex)
                }

                if viewIndex == 1 {
                    // The calendar is a control surface, so glass is appropriate here.
                    GlassContainer(cornerRadius: 18, padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)) {
                        MiniCalendarView(monthOffset: $monthOffset, markedDays: markedDays)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                let pending = state.deadlines.filter { !$0.completed }
                if pending.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(AppColors.success)
                            .symbolBounce(value: pending.count)
                        Text("All deadlines resolved")
                            .font(AppFont.headlineSmall())
                            .foregroundColor(AppColors.ink)
                        Text("Nothing needs your attention right now.")
                            .font(AppFont.bodyMedium())
                            .foregroundColor(AppColors.slate)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                } else {
                    ForEach(pending) { d in
                        SurfaceCard(cornerRadius: 18) {
                            HStack(spacing: 14) {
                                Capsule().fill(severityColor(d.severity)).frame(width: 4, height: 54)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(d.action)
                                        .font(AppFont.bodyLarge().weight(.semibold))
                                        .foregroundColor(AppColors.ink)
                                    Text(d.doc)
                                        .font(AppFont.labelSmall())
                                        .foregroundColor(AppColors.slate)
                                    HStack(spacing: 4) {
                                        Image(systemName: d.days <= 7 ? "exclamationmark.triangle.fill" : "clock")
                                            .font(AppFont.chrome(11))
                                        Text("Due \(d.due) · \(d.days) days left")
                                            .numericRoll(value: d.days)
                                    }
                                    .font(AppFont.chrome(12, .bold))
                                    .foregroundStyle(severityColor(d.severity))
                                }
                                Spacer()
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        state.resolveDeadline(d.id)
                                    }
                                    Haptics.play(.success)
                                } label: {
                                    Image(systemName: "checkmark.circle")
                                        .font(AppFont.chrome(26))
                                        .foregroundStyle(AppColors.teal)
                                }
                                .buttonStyle(PressableStyle())
                                .accessibilityLabel("Mark '\(d.action)' complete")
                            }
                        }
                        .contextMenu {
                            Button {
                                withAnimation { state.resolveDeadline(d.id) }
                                Haptics.play(.success)
                            } label: {
                                Label("Mark complete", systemImage: "checkmark.circle")
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }

                let done = state.deadlines.filter { $0.completed }
                if !done.isEmpty {
                    Text("Completed")
                        .font(AppFont.headlineSmall())
                        .foregroundColor(AppColors.ink)
                        .padding(.top, 8)
                    GroupedCard(data: done) { d in
                        HStack {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(AppColors.success)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(d.action)
                                    .font(AppFont.bodyMedium())
                                    .foregroundColor(AppColors.slate)
                                    .strikethrough()
                                Text("\(d.doc) · was due \(d.due)")
                                    .font(AppFont.labelSmall())
                                    .foregroundColor(AppColors.slate)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 110)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: state.deadlines)
            .animation(.easeInOut(duration: 0.25), value: viewIndex)
        }
        .refreshable {
            try? await Task.sleep(nanoseconds: 700_000_000)
            Haptics.play(.lightImpact)
        }
    }

    private var markedDays: Set<Int> {
        Set(state.deadlines.filter { !$0.completed }.compactMap { day(from: $0.due) })
    }

    private func day(from dateStr: String) -> Int? {
        let parts = dateStr.split(separator: " ")
        return parts.first.flatMap { Int($0) }
    }

    private func severityColor(_ s: String) -> Color {
        switch s {
        case "high": return AppColors.danger
        case "medium": return AppColors.warning
        default: return AppColors.teal
        }
    }
}

/// Lightweight native month-grid calendar (no third-party dependency).
struct MiniCalendarView: View {
    @Binding var monthOffset: Int
    let markedDays: Set<Int>

    private var calendar: Calendar { Calendar.current }
    private var displayedMonth: Date {
        calendar.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { monthOffset -= 1 }
                    Haptics.play(.selection)
                } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Previous month")
                Spacer()
                Text(monthTitle)
                    .font(AppFont.chrome(15, .bold))
                    .foregroundColor(AppColors.ink)
                    .numericRoll(value: monthOffset)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { monthOffset += 1 }
                    Haptics.play(.selection)
                } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("Next month")
            }
            .foregroundStyle(AppColors.teal)

            let columns = Array(repeating: GridItem(.flexible()), count: 7)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, d in
                    Text(d).font(AppFont.chrome(11, .semibold)).foregroundColor(AppColors.slate)
                }
                ForEach(0..<leadingBlanks, id: \.self) { _ in Text("") }
                ForEach(1...daysInMonth, id: \.self) { day in
                    let isToday = day == todayDay && monthOffset == 0
                    let marked = markedDays.contains(day)
                    ZStack {
                        if isToday {
                            Circle().fill(AppColors.teal)
                        } else if marked {
                            Circle().stroke(AppColors.warning, lineWidth: 1.5)
                        }
                        Text("\(day)")
                            .font(AppFont.chrome(13, isToday ? .bold : .regular))
                            .foregroundColor(isToday ? .white : AppColors.ink)
                    }
                    .frame(height: 30)
                    .accessibilityLabel(
                        marked
                        ? "\(day), has a deadline"
                        : (isToday ? "\(day), today" : "\(day)")
                    )
                }
            }
        }
    }

    /// Locale-aware weekday initials, so the grid is correct outside en-US.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: displayedMonth)
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30
    }

    private var leadingBlanks: Int {
        let comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstOfMonth = calendar.date(from: comps) else { return 0 }
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var todayDay: Int {
        calendar.component(.day, from: Date())
    }
}
