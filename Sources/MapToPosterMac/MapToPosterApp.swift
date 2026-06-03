import SwiftUI

@main
struct MapToPosterApp: App {
    init() {
        // Headless self-test:  MapToPoster --test "City" "Country" out.png [dist]
        if CommandLine.arguments.contains("--test") {
            HeadlessTest.run(arguments: CommandLine.arguments)
        }
        // Ensure the app behaves as a regular, focusable GUI app even when
        // launched directly from a build script.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("MapToPoster") {
            ContentView()
        }
        .windowStyle(.titleBar)
    }
}
