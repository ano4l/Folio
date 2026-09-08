import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @EnvironmentObject var state: AppState

    @State private var emailText: String = "alex.m@folio-student.app"
    @State private var passwordText: String = "••••••••••••"
    @State private var obscure: Bool = true
    @State private var onMfa: Bool = false
    @State private var mfaPin: String = ""
    @State private var mfaError: String = ""
    @State private var biometricScanning: Bool = false
    @State private var toast: String? = nil
    @State private var shake: CGFloat = 0
    @FocusState private var pinFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Ask the device which biometry it actually has, so the button never
    /// promises Face ID on a Touch ID phone.
    private var biometryLabel: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Biometrics"
        }
    }

    private var biometrySymbol: String {
        biometryLabel == "Touch ID" ? "touchid" : "faceid"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 12)
                FolioLogo(size: 48)
                Spacer(minLength: 36)

                Text(onMfa ? "Multi-Factor Authentication" : "Welcome to Folio")
                    .font(AppFont.headlineLarge())
                    .foregroundColor(AppColors.ink)
                Spacer(minLength: 8)
                Text(onMfa
                     ? "Enter the 6-digit code sent to your device"
                     : "Encrypted document vault for student finance. Sign in to continue.")
                    .font(AppFont.bodyMedium())
                    .foregroundColor(AppColors.slate)
                Spacer(minLength: 32)

                if !onMfa {
                    credentialsCard
                    Spacer(minLength: 16)
                    biometricButton
                } else {
                    mfaCard
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 36)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: onMfa)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.paper.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let toast = toast {
                ToastView(text: toast)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var credentialsCard: some View {
        GlassContainer(cornerRadius: 20, padding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)) {
            VStack(spacing: 16) {
                LabeledField(label: "Email address", systemImage: "envelope") {
                    TextField("", text: $emailText)
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                LabeledField(label: "Password", systemImage: "lock") {
                    HStack {
                        Group {
                            if obscure {
                                SecureField("", text: $passwordText)
                            } else {
                                TextField("", text: $passwordText)
                            }
                        }
                        .textContentType(.password)
                        Button {
                            obscure.toggle()
                            Haptics.play(.selection)
                        } label: {
                            Image(systemName: obscure ? "eye.slash" : "eye")
                                .foregroundStyle(AppColors.slate)
                                .symbolBounce(value: obscure)
                        }
                        .accessibilityLabel(obscure ? "Show password" : "Hide password")
                    }
                }
                Button(action: submitCredentials) {
                    HStack {
                        Text("Sign in securely")
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var biometricButton: some View {
        GlassContainer(cornerRadius: 18, padding: EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20), onTap: biometricScanning ? nil : biometricLogin) {
            HStack {
                Spacer()
                if biometricScanning {
                    ProgressView().tint(AppColors.teal)
                } else {
                    Image(systemName: biometrySymbol)
                        .foregroundStyle(AppColors.teal)
                        .symbolBounce(value: biometricScanning)
                }
                Text(biometricScanning ? "Scanning \(biometryLabel)…" : "Sign in with \(biometryLabel)")
                    .font(AppFont.bodyLarge().weight(.semibold))
                    .foregroundColor(AppColors.teal)
                Spacer()
            }
        }
        .accessibilityLabel("Sign in with \(biometryLabel)")
    }

    private var mfaCard: some View {
        GlassContainer(cornerRadius: 20, padding: EdgeInsets(top: 28, leading: 20, bottom: 28, trailing: 20)) {
            VStack(spacing: 20) {
                PinEntryView(pin: $mfaPin, isFocused: $pinFocused)
                    .onChange(of: mfaPin) { newValue in
                        mfaError = ""
                        if newValue.count == 6 { verifyMfa() }
                    }

                if !mfaError.isEmpty {
                    Label(mfaError, systemImage: "exclamationmark.triangle.fill")
                        .font(AppFont.bodyMedium().weight(.medium))
                        .foregroundColor(AppColors.danger)
                        .transition(.opacity)
                }

                Button(action: verifyMfa) {
                    Text("Verify & continue").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    Haptics.play(.lightImpact)
                    showToast("New MFA passcode sent.")
                } label: {
                    Text("Resend passcode")
                        .font(AppFont.bodyMedium())
                        .foregroundColor(AppColors.teal)
                }
            }
        }
        // Horizontal shake is the standard iOS "wrong passcode" signal.
        .offset(x: shake)
        .onAppear { pinFocused = true }
    }

    private func submitCredentials() {
        Haptics.play(.lightImpact)
        withAnimation { onMfa = true }
        showToast("MFA passcode issued to your registered device.")
    }

    private func verifyMfa() {
        if mfaPin.count < 6 {
            withAnimation { mfaError = "Enter all 6 digits." }
            Haptics.play(.error)
            shakeField()
            return
        }
        Haptics.play(.success)
        state.login()
    }

    private func shakeField() {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 0.05).repeatCount(5, autoreverses: true)) {
            shake = 9
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.linear(duration: 0.05)) { shake = 0 }
        }
    }

    private func biometricLogin() {
        biometricScanning = true
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Verify your identity to access Folio") { success, _ in
                DispatchQueue.main.async {
                    biometricScanning = false
                    guard success else {
                        Haptics.play(.error)
                        showToast("\(biometryLabel) not recognised. Try again.")
                        return
                    }
                    Haptics.play(.success)
                    state.login()
                    showToast("Biometric identity verified. Welcome to Folio.")
                }
            }
        } else {
            // Device without biometric hardware: fall through to demo auth
            biometricScanning = false
            state.login()
        }
    }

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation { toast = nil }
        }
    }
}

private struct LabeledField<Content: View>: View {
    let label: String
    let systemImage: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundColor(AppColors.slate)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppFont.chrome(11))
                    .foregroundColor(AppColors.slate)
                content()
                    .font(AppFont.bodyLarge())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColors.card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppColors.line, lineWidth: 0.5))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.bodyLarge().weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .background(AppColors.teal.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct PinEntryView: View {
    @Binding var pin: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { i in
                    let filled = i < pin.count
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.card)
                        .frame(width: 44, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(filled ? AppColors.teal : AppColors.line, lineWidth: filled ? 2 : 1)
                        )
                        .overlay(
                            Text(filled ? String(Array(pin)[i]) : "")
                                .font(AppFont.chrome(22, .bold))
                                .foregroundColor(AppColors.ink)
                        )
                        .scaleEffect(filled ? 1 : 0.97)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: filled)
                }
            }
            TextField("", text: $pin)
                .keyboardType(.numberPad)
                // Lets iOS autofill the SMS code from the keyboard suggestion bar.
                .textContentType(.oneTimeCode)
                .focused(isFocused)
                .opacity(0.01)
                .onChange(of: pin) { newValue in
                    pin = String(newValue.filter { $0.isNumber }.prefix(6))
                }
                .accessibilityLabel("Six digit verification code")
                .accessibilityValue("\(pin.count) of 6 digits entered")
        }
        .hapticFeedback(.selection, trigger: pin.count)
        .contentShape(Rectangle())
        .onTapGesture { isFocused.wrappedValue = true }
    }
}

struct ToastView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(AppFont.bodyMedium().weight(.medium))
            .foregroundColor(AppColors.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            // Transient overlays are chrome, so the glass layer applies here.
            .glassSurface(cornerRadius: 18)
            .padding(.horizontal, 24)
            .accessibilityAddTraits(.isStaticText)
    }
}
