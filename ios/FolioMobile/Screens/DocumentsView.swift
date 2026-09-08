import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DocumentsView: View {
    @EnvironmentObject var state: AppState
    @State private var showUpload = false
    @State private var query: String = ""
    @State private var activeFilter: String? = nil
    @State private var pendingDelete: FolioDocument? = nil
    @FocusState private var searchFocused: Bool

    private var filtered: [FolioDocument] {
        state.documents.filter { doc in
            let matchesFilter = activeFilter == nil || doc.type == activeFilter
            guard matchesFilter else { return false }
            guard !query.isEmpty else { return true }
            // Search title, category, summary and OCR text — the same fields the
            // backend retrieval layer indexes.
            return [doc.title, doc.type, doc.summary, doc.rawText]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // A `List` (never `Form`) is used so rows get native swipe actions and
            // the system's own row-recycling performance.
            List {
                Section {
                    ForEach(filtered) { d in
                        DocumentRow(doc: d)
                            .onTapGesture { state.selectDoc(d) }
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            // Full-swipe left to delete, matching Mail.
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    pendingDelete = d
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    state.selectDoc(d)
                                    Haptics.play(.lightImpact)
                                } label: {
                                    Label("Open", systemImage: "doc.text.magnifyingglass")
                                }
                                .tint(AppColors.teal)
                            }
                            .contextMenu {
                                Button {
                                    state.selectDoc(d)
                                } label: {
                                    Label("Open document", systemImage: "doc.text")
                                }
                                ShareLink(item: d.rawText.isEmpty ? d.summary : d.rawText) {
                                    Label("Share extracted text", systemImage: "square.and.arrow.up")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    pendingDelete = d
                                } label: {
                                    Label("Move to recycle bin", systemImage: "trash")
                                }
                            } preview: {
                                DocumentPreviewCard(doc: d)
                            }
                    }
                } header: {
                    header
                        .textCase(nil)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                }

                if filtered.isEmpty {
                    EmptyVaultState(hasQuery: !query.isEmpty || activeFilter != nil)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }

                if !state.deletedDocs.isEmpty {
                    Section {
                        GroupedCard(data: state.deletedDocs) { d in
                            HStack {
                                Image(systemName: "trash").foregroundStyle(AppColors.slate)
                                Text(d.title)
                                    .font(AppFont.bodyMedium())
                                    .foregroundColor(AppColors.slate)
                                    .strikethrough()
                                Spacer()
                                Button {
                                    state.restoreDoc(d)
                                    Haptics.play(.success)
                                } label: {
                                    Label("Restore", systemImage: "arrow.counterclockwise")
                                        .font(AppFont.bodyMedium())
                                        .foregroundColor(AppColors.teal)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 90, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } header: {
                        Text("Recycle Bin")
                            .font(AppFont.headlineSmall())
                            .foregroundColor(AppColors.ink)
                            .textCase(nil)
                            .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 4, trailing: 20))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .refreshable {
                try? await Task.sleep(nanoseconds: 700_000_000)
                Haptics.play(.lightImpact)
            }

            uploadButton
        }
        .sheet(isPresented: $showUpload) {
            UploadSheetView()
                .environmentObject(state)
                .appleSheet(detents: [.medium, .large])
        }
        .fullScreenCover(item: $state.selectedDoc) { doc in
            DocumentDetailView(doc: doc).environmentObject(state)
        }
        // Destructive actions always confirm, per HIG.
        .confirmationDialog(
            "Move to recycle bin?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { doc in
            Button("Move '\(doc.title)' to bin", role: .destructive) {
                state.softDeleteDoc(doc)
                Haptics.play(.error)
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { _ in
            Text("You can restore it from the recycle bin at any time. The deletion is written to your POPIA audit ledger.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Document Vault")
                    .font(AppFont.headlineMedium())
                    .foregroundColor(AppColors.ink)
                Text("\(state.documents.count) documents · encrypted at rest")
                    .font(AppFont.bodyMedium())
                    .foregroundColor(AppColors.slate)
            }

            // Search field styled as chrome, so it takes the glass layer.
            GlassContainer(cornerRadius: 14, padding: EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(AppColors.slate)
                    TextField("Search titles, summaries, OCR text", text: $query)
                        .font(AppFont.bodyLarge())
                        .focused($searchFocused)
                        .submitLabel(.search)
                    if !query.isEmpty {
                        Button {
                            query = ""
                            Haptics.play(.lightImpact)
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(AppColors.slate)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: query.isEmpty)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "All", selected: activeFilter == nil) { activeFilter = nil }
                    ForEach(Array(Set(state.documents.map(\.type))).sorted(), id: \.self) { type in
                        FilterChip(title: type, selected: activeFilter == type) {
                            activeFilter = activeFilter == type ? nil : type
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabledIfAvailable()
        }
        .padding(.bottom, 4)
    }

    /// Floating action button: this is chrome above the content, so it is one of
    /// the few surfaces Apple explicitly sanctions for interactive glass.
    private var uploadButton: some View {
        GlassGroup(spacing: 10) {
            GlassContainer(
                cornerRadius: 28,
                tint: AppColors.teal,
                interactive: true,
                padding: EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20),
                onTap: {
                    Haptics.play(.lightImpact)
                    showUpload = true
                }
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.doc.fill")
                    Text("Upload").fontWeight(.semibold)
                }
                .foregroundStyle(.white)
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 100)
        .accessibilityLabel("Upload a document")
    }
}

private struct DocumentRow: View {
    let doc: FolioDocument

    var body: some View {
        SurfaceCard(cornerRadius: 18, padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColors.tealLight)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "doc.text")
                            .font(AppFont.chrome(22))
                            .foregroundStyle(AppColors.teal)
                    )
                VStack(alignment: .leading, spacing: 6) {
                    Text(doc.title)
                        .font(AppFont.bodyLarge().weight(.semibold))
                        .foregroundColor(AppColors.ink)
                    Text(doc.summary)
                        .font(AppFont.labelSmall())
                        .foregroundColor(AppColors.slate)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        DocTypeBadge(type: doc.type)
                        Spacer()
                        // Confidence is surfaced as a gauge, not just a number, so
                        // low-confidence OCR is visually obvious.
                        ConfidenceGauge(confidence: doc.confidence)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double tap to open. Swipe for actions.")
    }
}

private struct ConfidenceGauge: View {
    let confidence: Int

    private var tone: Color {
        confidence >= 95 ? AppColors.success : (confidence >= 85 ? AppColors.warning : AppColors.danger)
    }

    var body: some View {
        HStack(spacing: 5) {
            Capsule()
                .fill(AppColors.line.opacity(0.5))
                .frame(width: 34, height: 4)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(tone)
                        .frame(width: 34 * CGFloat(confidence) / 100, height: 4)
                }
            Text("\(confidence)%")
                .font(AppFont.chrome(11, .semibold))
                .foregroundColor(AppColors.slate)
        }
        .accessibilityLabel("OCR confidence \(confidence) percent")
    }
}

/// Rich context-menu preview, the same pattern Files and Photos use.
private struct DocumentPreviewCard: View {
    let doc: FolioDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                DocTypeBadge(type: doc.type)
                Spacer()
                Text("\(doc.pages) pages").font(AppFont.labelSmall()).foregroundColor(AppColors.slate)
            }
            Text(doc.title).font(AppFont.headlineSmall()).foregroundColor(AppColors.ink)
            Text(doc.summary).font(AppFont.bodyMedium()).foregroundColor(AppColors.slate)
            ForEach(doc.entities.prefix(3)) { entity in
                HStack {
                    Text(entity.label).font(AppFont.labelSmall()).foregroundColor(AppColors.slate)
                    Spacer()
                    Text(entity.value).font(AppFont.labelSmall().weight(.semibold)).foregroundColor(AppColors.ink)
                }
            }
        }
        .padding(18)
        .frame(width: 300)
        .background(AppColors.card)
    }
}

private struct FilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { action() }
            Haptics.play(.selection)
        } label: {
            Text(title)
                .font(AppFont.chrome(12, .semibold))
                .foregroundColor(selected ? .white : AppColors.ink)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(
                    Capsule().fill(selected ? AppColors.teal : AppColors.card)
                )
                .overlay(
                    Capsule().stroke(AppColors.line.opacity(selected ? 0 : 0.8), lineWidth: 0.5)
                )
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct EmptyVaultState: View {
    let hasQuery: Bool

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: hasQuery ? "magnifyingglass" : "tray")
                .font(.system(size: 42))
                .foregroundStyle(AppColors.slate)
            Text(hasQuery ? "No matching documents" : "Your vault is empty")
                .font(AppFont.headlineSmall())
                .foregroundColor(AppColors.ink)
            Text(hasQuery
                 ? "Try a different search term or clear the active category filter."
                 : "Upload funding letters, bursary agreements or fee statements to get started.")
                .font(AppFont.bodyMedium())
                .foregroundColor(AppColors.slate)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .padding(.horizontal, 30)
    }
}

extension View {
    /// Lets horizontally scrolling chips overflow their container without being
    /// clipped (iOS 17+); a no-op on earlier releases.
    @ViewBuilder
    func scrollClipDisabledIfAvailable() -> some View {
        if #available(iOS 17.0, *) {
            self.scrollClipDisabled()
        } else {
            self
        }
    }
}

struct UploadSheetView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss

    @State private var fileName: String? = nil
    @State private var title: String = ""
    @State private var type: String = "Funding Award Letter"
    @State private var uploading = false
    @State private var showPicker = false
    @State private var stage: String = ""
    @FocusState private var titleFocused: Bool

    private let types = ["Funding Award Letter", "Bursary Agreement", "Fee Statement", "Bank Letter", "Appeal Correspondence"]

    private var canSubmit: Bool { fileName != nil && !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    dropZone

                    LabeledField(label: "Document title") {
                        TextField("e.g. NSFAS funding award 2026", text: $title)
                            .font(AppFont.bodyLarge())
                            .focused($titleFocused)
                            .submitLabel(.done)
                    }

                    LabeledField(label: "Category") {
                        // Menu picker keeps the sheet compact and gives the
                        // standard iOS pull-down affordance.
                        Picker("Category", selection: $type) {
                            ForEach(types, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .tint(AppColors.teal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Label("Files are encrypted client-side, then sent straight to storage with a presigned URL — the app server never sees your document bytes.", systemImage: "lock.shield")
                        .font(AppFont.labelSmall())
                        .foregroundColor(AppColors.slate)

                    Button(action: submit) {
                        if uploading {
                            HStack(spacing: 8) {
                                ProgressView().tint(.white)
                                Text(stage)
                                    .fadeContentTransition()
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Text("Upload & process").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(uploading || !canSubmit)
                    .opacity(canSubmit || uploading ? 1 : 0.5)
                    .animation(.easeInOut(duration: 0.2), value: canSubmit)
                }
                .padding(20)
            }
            .background(AppColors.paper.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Secure Upload")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .interactiveDismissDisabled(uploading)
        }
        .fileImporter(isPresented: $showPicker, allowedContentTypes: [.pdf, .png, .jpeg, .image], onCompletion: { result in
            if case .success(let url) = result {
                fileName = url.lastPathComponent
                if title.isEmpty {
                    title = url.deletingPathExtension().lastPathComponent
                }
                Haptics.play(.success)
            }
        })
    }

    private var dropZone: some View {
        Button {
            Haptics.play(.lightImpact)
            showPicker = true
        } label: {
            VStack(spacing: 10) {
                Image(systemName: fileName != nil ? "checkmark.seal.fill" : "icloud.and.arrow.up")
                    .font(.system(size: 38))
                    .foregroundStyle(AppColors.teal)
                    .symbolBounce(value: fileName)
                Text(fileName ?? "Choose a PDF or image")
                    .font(AppFont.bodyLarge().weight(.semibold))
                    .foregroundColor(AppColors.ink)
                    .multilineTextAlignment(.center)
                Text(fileName == nil ? "Up to 25 MB · PDF, PNG, JPEG" : "Tap to choose a different file")
                    .font(AppFont.labelSmall())
                    .foregroundColor(AppColors.slate)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(fileName != nil ? AppColors.tealLight : AppColors.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        fileName != nil ? AppColors.teal : AppColors.line,
                        style: StrokeStyle(lineWidth: 1, dash: fileName != nil ? [] : [6, 4])
                    )
            )
        }
        .buttonStyle(PressableStyle())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: fileName)
        .accessibilityLabel(fileName == nil ? "Choose a file to upload" : "Selected file \(fileName!)")
    }

    private func submit() {
        guard canSubmit else { return }
        uploading = true
        // Narrated progress: users should always know which step is running.
        let stages = ["Encrypting…", "Uploading…", "Running OCR…", "Extracting entities…"]
        for (i, s) in stages.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.45) {
                withAnimation { stage = s }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(stages.count) * 0.45) {
            let newDoc = FolioDocument(
                id: Int(Date().timeIntervalSince1970 * 1000),
                title: title,
                type: type,
                date: AppState.today(),
                pages: 1,
                status: "Ready",
                confidence: 92,
                summary: "Newly uploaded document. OCR extraction completed.",
                entities: [],
                rawText: "Document uploaded: \(fileName ?? "")\nOCR extraction complete."
            )
            state.addDocument(newDoc)
            uploading = false
            Haptics.play(.success)
            dismiss()
        }
    }
}

private struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFont.labelSmall())
                .foregroundColor(AppColors.slate)
                .textCase(.uppercase)
            content()
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.card))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppColors.line, lineWidth: 0.5))
        }
    }
}

extension View {
    /// Cross-fades text changes instead of hard-cutting them (iOS 16+).
    @ViewBuilder
    func fadeContentTransition() -> some View {
        if #available(iOS 16.0, *) {
            self.contentTransition(.opacity)
        } else {
            self
        }
    }
}

struct DocumentDetailView: View {
    let doc: FolioDocument
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @State private var tabIndex = 0
    @State private var confirmDelete = false
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("View", selection: $tabIndex) {
                    Text("Extracted Data").tag(0)
                    Text("OCR Raw Text").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .hapticFeedback(.selection, trigger: tabIndex)

                ScrollView {
                    Group {
                        if tabIndex == 0 {
                            extractedTab
                        } else {
                            ocrTab
                        }
                    }
                    // Slide between tabs in the direction of travel, mirroring
                    // the system segmented-control behaviour.
                    .transition(.asymmetric(
                        insertion: .move(edge: tabIndex == 0 ? .leading : .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
                .animation(.easeInOut(duration: 0.22), value: tabIndex)
            }
            .background(AppColors.paper.ignoresSafeArea())
            .navigationTitle(doc.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        state.selectDoc(nil)
                        dismiss()
                    } label: {
                        Label("Done", systemImage: "chevron.left")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ShareLink(item: doc.rawText.isEmpty ? doc.summary : doc.rawText) {
                            Label("Share extracted text", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            UIPasteboard.general.string = doc.rawText.isEmpty ? doc.summary : doc.rawText
                            copied = true
                            Haptics.play(.success)
                        } label: {
                            Label("Copy OCR text", systemImage: "doc.on.doc")
                        }
                        Divider()
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Label("Move to recycle bin", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Document actions")
                }
            }
            .overlay(alignment: .bottom) {
                if copied {
                    Label("Copied to clipboard", systemImage: "checkmark.circle.fill")
                        .font(AppFont.bodyMedium())
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .glassSurface(cornerRadius: 22)
                        .padding(.bottom, 30)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(nanoseconds: 1_600_000_000)
                            withAnimation { copied = false }
                        }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: copied)
            .confirmationDialog("Move to recycle bin?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Move to bin", role: .destructive) {
                    state.softDeleteDoc(doc)
                    Haptics.play(.error)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This is reversible from the recycle bin and is recorded in your audit ledger.")
            }
        }
    }

    private var extractedTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                DocTypeBadge(type: doc.type)
                Text("\(doc.date) · \(doc.pages) pages")
                    .font(AppFont.labelSmall())
                    .foregroundColor(AppColors.slate)
            }
            // Content layers stay opaque: glass over dense text hurts legibility.
            SurfaceCard(cornerRadius: 18, padding: EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(AppColors.teal)
                            .symbolBounce(value: doc.id)
                        Text("AI Grounded Summary")
                            .font(AppFont.headlineSmall())
                            .foregroundColor(AppColors.ink)
                    }
                    Text(doc.summary)
                        .font(AppFont.bodyLarge())
                        .foregroundColor(AppColors.ink)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                }
            }
            Text("Extracted Entities")
                .font(AppFont.headlineSmall())
                .foregroundColor(AppColors.ink)
            GroupedCard(data: doc.entities) { e in
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.label).font(AppFont.labelSmall()).foregroundColor(AppColors.slate)
                    Text(e.value)
                        .font(AppFont.bodyLarge().weight(.semibold))
                        .foregroundColor(AppColors.ink)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = e.value
                        Haptics.play(.success)
                    } label: {
                        Label("Copy value", systemImage: "doc.on.doc")
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    private var ocrTab: some View {
        SurfaceCard(cornerRadius: 18, padding: EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)) {
            Text(doc.rawText.isEmpty ? doc.summary : doc.rawText)
                .font(.system(.footnote, design: .monospaced))
                .foregroundColor(AppColors.ink)
                .lineSpacing(5)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
}
