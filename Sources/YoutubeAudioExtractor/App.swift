import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct YoutubeAudioExtractorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    var body: some Scene {
        WindowGroup("Youtube Audio Extractor") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
