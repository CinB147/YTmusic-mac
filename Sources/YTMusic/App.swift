import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Keep playing when the window is closed; clicking the Dock icon brings it back.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    var openMainWindow: (() -> Void)?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag, let openMainWindow else { return true }
        openMainWindow()
        return false
    }
}

// Hands the scene's openWindow action to the AppDelegate so the Dock icon can reopen a closed window.
private struct ReopenBridge: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    let appDelegate: AppDelegate

    func body(content: Content) -> some View {
        content.onAppear {
            appDelegate.openMainWindow = { [openWindow] in
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

@main
struct YTMusicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var player = Player()

    var body: some Scene {
        Window("YTMusic", id: "main") {
            ContentView()
                .environmentObject(player)
                .preferredColorScheme(.dark)
                .frame(minWidth: 960, minHeight: 620)
                .task { SelfTest.runIfRequested(player) }
                .modifier(ReopenBridge(appDelegate: appDelegate))
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Playback") {
                Button("Play / Pause") { player.togglePlay() }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                Button("Next") { player.next() }
                    .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])
                Button("Previous") { player.previous() }
                    .keyboardShortcut(.leftArrow, modifiers: [.command, .shift])
                Divider()
                Button("Like") { player.toggleLike() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
            }
            CommandMenu("Navigate") {
                Button("Back") { player.goBack() }.keyboardShortcut("[", modifiers: .command)
                Button("Forward") { player.goForward() }.keyboardShortcut("]", modifiers: .command)
                Button("Reload") { player.reload() }.keyboardShortcut("r", modifiers: .command)
                Divider()
                Button("Home") { player.navigate("/") }.keyboardShortcut("1", modifiers: .command)
                Button("Explore") { player.navigate("/explore") }.keyboardShortcut("2", modifiers: .command)
                Button("Library") { player.navigate("/library") }.keyboardShortcut("3", modifiers: .command)
            }
        }
    }
}
