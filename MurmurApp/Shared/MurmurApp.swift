import SwiftUI

@main
struct MurmurApp: App {
    var body: some Scene {
        WindowGroup {
            TranscriptionView()
        }
        .defaultSize(width: 500, height: 400)
    }
}
