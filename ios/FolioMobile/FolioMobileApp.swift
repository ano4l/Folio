import SwiftUI

@main
struct FolioMobileApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            if state.authStep == "authenticated" {
                MainShellView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: state.authStep)
    }
}
