// Placeholder ContentView for Story 1
// Will be replaced with full audio testing UI in Story 3
//
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.blue)

            Text("VeepaAudioTest")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Audio streaming test app for Veepa cameras")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("✅ Project Setup Complete")
                .font(.headline)
                .foregroundColor(.green)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
