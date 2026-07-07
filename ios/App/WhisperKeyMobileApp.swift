import SwiftUI

@main
struct WhisperKeyMobileApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .task { await model.bootstrap() }
                .onOpenURL { url in model.handle(url: url) }
        }
    }
}
