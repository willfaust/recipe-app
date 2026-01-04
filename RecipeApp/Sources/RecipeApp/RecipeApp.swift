import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct RecipeApp: App {
    @StateObject private var searchEngine = RecipeSearchEngine()

    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(searchEngine)
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        #endif
    }
}

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure app is frontmost and accepts keyboard input
        NSApp.activate(ignoringOtherApps: true)
        NSApp.setActivationPolicy(.regular)

        // Make sure we have a main window that's key
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
                window.makeFirstResponder(window.contentView)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
#endif
