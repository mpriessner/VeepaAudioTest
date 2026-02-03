// ADAPTED FROM: Story 1 iOS app entry point pattern
// Changes: Pure SwiftUI app lifecycle (no UIKit AppDelegate)
//   - WindowGroup with ContentView as root
//   - Minimal initialization
//
import SwiftUI

@main
struct VeepaAudioTestApp: App {
    init() {
        // Initialize any app-level services here if needed
        print("🚀 VeepaAudioTest app initializing...")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
