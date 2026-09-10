import SwiftUI
import UIKit
import Speech
import AVFoundation

struct AskAIView: View {
    @EnvironmentObject var state: AppState
    @State private var inputText: String = ""
    @State private var showCreditSheet = false
    @State private var micPulse = false
    @FocusState private var inputFocused: Bool
    @StateObject private var speech = SpeechRecognizer()
    @StateObject private var speaker = SpeechSpeaker()

    private let suggestions = [
        "When is my bursary renewal?",
        "Do I still owe any fees?",
        "What are my funding award conditions?",
        "Draft a summary for my graduate application",
    ]

    var body: some View {
        VStack(spacing: 0) {
            creditBar

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(state.chatMessages) { msg in
                            ChatBubbleRow(
                                message: msg,
                                isSpeaking: speaker.isSpeaking,
                                onSpeak: { speak($0) },
                                onSourceTap: { docTitle in
                                    if let match = state.documents.first(where: { $0.title == docTitle }) {
                                        Haptics.play(.lightImpact)
                                        state.selectDoc(match)
                                    }
                                }
                            )
                            .id(msg.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                        if state.aiTyping {
                            TypingIndicator()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 130)
                }
                .onChange(of: state.chatMessages.count) { _ in
                    if let last = state.chatMessages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            if state.chatMessages.count <= 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { s in
                            Button {
                                Haptics.play(.lightImpact)
                                inputText = s
                                send()
                            } label: {
                                Text(s)
                                    .font(AppFont.chrome(12, .medium))
                                    .foregroundColor(AppColors.ink)
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Capsule().fill(AppColors.card))
                                    .overlay(Capsule().stroke(AppColors.line, lineWidth: 0.5))
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 38)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            inputBar
                .padding(.horizontal, 16)
                .padding(.bottom, 90)
                .padding(.top, 8)
        }
        .animation(.easeInOut(duration: 0.25), value: state.chatMessages.count)
        .sheet(isPresented: $showCreditSheet) {
            CreditSheetView()
                .environmentObject(state)
                .appleSheet(detents: [.medium])
        }
        .onChange(of: speech.transcript) { newValue in
            inputText = newValue
        }
        .onDisappear {
            if speech.isListening { speech.stopListening() }
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private var freeLeft: Int { max(0, state.monthlyFreeLimit - state.monthlyFreeUsed) }

    /// The credit meter is chrome pinned above the transcript, so it takes the
    /// glass layer and gets a live-updating capacity gauge.
    private var creditBar: some View {
        GlassContainer(cornerRadius: 16, padding: EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(freeLeft > 0 ? AppColors.warning : AppColors.danger)
                    .font(AppFont.chrome(14))
                    .symbolBounce(value: freeLeft)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("\(freeLeft)")
                            .numericRoll(value: freeLeft)
                        Text("free left · \(state.aiCredits) credits")
                    }
                    .font(AppFont.chrome(12, .semibold))
                    .foregroundColor(AppColors.slate)

                    GeometryReader { geo in
                        Capsule().fill(AppColors.line.opacity(0.5))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(freeLeft > 0 ? AppColors.warning : AppColors.danger)
                                    .frame(width: geo.size.width * CGFloat(freeLeft) / CGFloat(max(1, state.monthlyFreeLimit)))
                                    .animation(.snappy, value: freeLeft)
                            }
                    }
                    .frame(height: 3)
                }
                Button {
                    Haptics.play(.lightImpact)
                    showCreditSheet = true
                } label: {
                    Text("Top up")
                        .font(AppFont.chrome(13, .semibold))
                        .foregroundColor(AppColors.teal)
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(freeLeft) free questions remaining, \(state.aiCredits) paid credits")
    }

    private var canSend: Bool { !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var inputBar: some View {
        GlassGroup(spacing: 8) {
            GlassContainer(
                cornerRadius: 26,
                interactive: true,
                padding: EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 8)
            ) {
                HStack(spacing: 8) {
                    Button(action: toggleListening) {
                        ZStack {
                            // Pulsing halo makes an active mic unmistakable.
                            if speech.isListening {
                                Circle()
                                    .fill(AppColors.danger.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                    .scaleEffect(micPulse ? 1.25 : 0.85)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: micPulse)
                            }
                            Image(systemName: speech.isListening ? "mic.fill" : "mic")
                                .foregroundStyle(speech.isListening ? AppColors.danger : AppColors.slate)
                                .symbolBounce(value: speech.isListening)
                        }
                        .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel(speech.isListening ? "Stop dictation" : "Start dictation")

                    TextField("Ask about your documents…", text: $inputText, axis: .vertical)
                        .font(AppFont.bodyLarge())
                        .lineLimit(1...4)
                        .focused($inputFocused)
                        .submitLabel(.send)
                        .onSubmit { send() }

                    Button(action: send) {
                        Image(systemName: "arrow.up")
                            .font(AppFont.chrome(15, .bold))
                            .foregroundStyle(.white)
                            .padding(9)
                            .background(Circle().fill(canSend ? AppColors.teal : AppColors.slate.opacity(0.4)))
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(!canSend)
                    .animation(.easeInOut(duration: 0.2), value: canSend)
                    .accessibilityLabel("Send question")
                }
            }
        }
        .onChange(of: speech.isListening) { listening in
            micPulse = listening
        }
    }

    private func toggleListening() {
        Haptics.play(speech.isListening ? .selection : .lightImpact)
        if speech.isListening {
            speech.stopListening()
        } else {
            speech.startListening()
        }
    }

    private func send() {
        let q = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        guard state.hasCredits else {
            Haptics.play(.warning)
            showCreditSheet = true
            return
        }
        if speech.isListening { speech.stopListening() }
        Haptics.play(.lightImpact)
        state.sendChat(q)
        inputText = ""
        speech.transcript = ""
    }

    private var synthesizer: AVSpeechSynthesizer { speaker.synthesizer }

    private func speak(_ text: String) {
        speaker.toggle(text)
    }
}

/// Text-to-speech wrapper that publishes playback state so the UI can offer a
/// stop affordance rather than trapping the user in a long read-out.
final class SpeechSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false
    let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggle(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-ZA") ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.48
        synthesizer.speak(utterance)
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
}

private struct ChatBubbleRow: View {
    let message: ChatMessage
    let isSpeaking: Bool
    let onSpeak: (String) -> Void
    let onSourceTap: (String) -> Void

    var body: some View {
        let isUser = message.role == "user"
        VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
            HStack {
                if isUser { Spacer(minLength: 40) }
                Text(message.text)
                    .font(AppFont.bodyLarge())
                    .textSelection(.enabled)
                    .foregroundColor(isUser ? .white : AppColors.ink)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(isUser ? AppColors.teal : AppColors.card)
                    .clipShape(BubbleShape(isUser: isUser))
                    .overlay(
                        Group {
                            if !isUser {
                                BubbleShape(isUser: isUser).stroke(AppColors.line, lineWidth: 0.5)
                            }
                        }
                    )
                if !isUser { Spacer(minLength: 40) }
            }

            if !isUser && !message.sources.isEmpty {
                FlowSources(sources: message.sources, onTap: onSourceTap)
            }
            if !isUser {
                HStack(spacing: 14) {
                    Button {
                        Haptics.play(.lightImpact)
                        onSpeak(message.text)
                    } label: {
                        Image(systemName: isSpeaking ? "stop.circle" : "speaker.wave.2")
                            .font(AppFont.chrome(14))
                            .foregroundStyle(isSpeaking ? AppColors.teal : AppColors.slate)
                            .symbolBounce(value: isSpeaking)
                    }
                    .accessibilityLabel(isSpeaking ? "Stop reading aloud" : "Read answer aloud")

                    Button {
                        UIPasteboard.general.string = message.text
                        Haptics.play(.success)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(AppFont.chrome(13))
                            .foregroundStyle(AppColors.slate)
                    }
                    .accessibilityLabel("Copy answer")
                }
                .padding(.leading, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .padding(.vertical, 2)
    }
}

private struct FlowSources: View {
    let sources: [ChatSource]
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(sources, id: \.self) { s in
                    Button(action: { onTap(s.doc) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text.fill").font(AppFont.chrome(10))
                            Text(s.doc).font(AppFont.chrome(11, .semibold)).lineLimit(1)
                        }
                        .foregroundColor(AppColors.teal)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(AppColors.tealLight))
                    }
                }
            }
        }
    }
}

private struct BubbleShape: Shape {
    let isUser: Bool
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 20
        let tail: CGFloat = 4
        var corners: UIRectCorner = [.topLeft, .topRight]
        corners.insert(isUser ? .bottomLeft : .bottomRight)
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        // Slightly squared tail corner
        let tailCorner: UIRectCorner = isUser ? .bottomRight : .bottomLeft
        let tailPath = UIBezierPath(roundedRect: rect, byRoundingCorners: tailCorner, cornerRadii: CGSize(width: tail, height: tail))
        path.append(tailPath)
        return Path(path.cgPath)
    }
}

/// Animated three-dot indicator matching the Messages typing bubble. Honours
/// Reduce Motion by falling back to a static row of dots.
private struct TypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(AppColors.slate)
                    .frame(width: 6, height: 6)
                    .opacity(reduceMotion || phase == i ? 1 : 0.35)
                    .scaleEffect(!reduceMotion && phase == i ? 1.25 : 1)
                    .animation(.easeInOut(duration: 0.25), value: phase)
            }
        }
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000)
                phase = (phase + 1) % 3
            }
        }
        .accessibilityLabel("Folio AI is typing")
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.line, lineWidth: 0.5))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CreditSheetView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    private let packages = [10, 25, 50]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your monthly free allowance is exhausted. Purchase credits to keep querying.")
                    .font(AppFont.bodyMedium()).foregroundColor(AppColors.slate)

                ForEach(packages, id: \.self) { n in
                    Button {
                        state.purchaseCredits(n)
                        Haptics.play(.success)
                        dismiss()
                    } label: {
                        HStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.warningLight)
                                .frame(width: 40, height: 40)
                                .overlay(Image(systemName: "bolt.fill").foregroundStyle(AppColors.warning))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(n) AI credits")
                                    .font(AppFont.bodyLarge().weight(.semibold))
                                    .foregroundColor(AppColors.ink)
                                Text("R\(n * 2).00")
                                    .font(AppFont.labelSmall())
                                    .foregroundColor(AppColors.slate)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(AppColors.slate)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColors.card))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppColors.line, lineWidth: 0.5))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Buy \(n) credits for \(n * 2) rand")
                }
                Spacer()
            }
            .padding(20)
            .background(AppColors.paper.ignoresSafeArea())
            .navigationTitle("Top up AI credits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

/// Wraps SFSpeechRecognizer + AVAudioEngine for live microphone transcription.
final class SpeechRecognizer: ObservableObject {
    @Published var transcript: String = ""
    @Published var isListening: Bool = false

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-ZA")) ?? SFSpeechRecognizer()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    func startListening() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self = self, status == .authorized else { return }
            DispatchQueue.main.async { self.beginSession() }
        }
    }

    private func beginSession() {
        guard let recognizer = recognizer, recognizer.isAvailable else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request = request else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                self.transcript = result.bestTranscription.formattedString
            }
            if error != nil || (result?.isFinal ?? false) {
                self.stopListening()
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        try? audioEngine.start()
        isListening = true
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        isListening = false
    }
}
