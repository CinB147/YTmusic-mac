import AppKit
import SwiftUI
import WebKit

/// Dev aid: `YTM_SELFTEST=<dir>` runs `<dir>/test.js` in the page after load,
/// writes its result to `<dir>/result.txt`, a web snapshot to `<dir>/web.png`, then quits.
enum SelfTest {
    @MainActor
    static func runIfRequested(_ player: Player) {
        guard let dir = ProcessInfo.processInfo.environment["YTM_SELFTEST"] else { return }
        let base = URL(fileURLWithPath: dir)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(9))
            let js = (try? String(contentsOf: base.appendingPathComponent("test.js"), encoding: .utf8)) ?? "return null"
            var result: String
            do {
                let value = try await player.webView.callAsyncJavaScript(js, arguments: [:], in: nil, contentWorld: .page)
                result = String(describing: value ?? "nil")
            } catch {
                result = "ERROR: \(error)"
            }
            result += "\n--- native ---\npath=\(player.path) loggedIn=\(String(describing: player.loggedIn)) "
                + "playlists=\(player.playlists.count) title=\(player.title) playing=\(player.isPlaying) "
                + "pos=\(player.position) dur=\(player.duration)\n"
            try? result.write(to: base.appendingPathComponent("result.txt"), atomically: true, encoding: .utf8)
            if let image = try? await player.webView.takeSnapshot(configuration: nil),
               let tiff = image.tiffRepresentation,
               let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: base.appendingPathComponent("web.png"))
            }
            let bar = ImageRenderer(content: PlayerBar().environmentObject(player)
                .frame(width: 1280, height: 92).environment(\.colorScheme, .dark))
            bar.scale = 2
            if let tiff = bar.nsImage?.tiffRepresentation,
               let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: base.appendingPathComponent("bar.png"))
            }
            if let window = NSApp.windows.first(where: { $0.isVisible }) {
                try? "\(window.windowNumber)".write(to: base.appendingPathComponent("window.txt"), atomically: true, encoding: .utf8)
                try? await Task.sleep(for: .seconds(4))
            }
            NSApp.terminate(nil)
        }
    }
}
