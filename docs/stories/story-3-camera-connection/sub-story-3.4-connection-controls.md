# Sub-Story 3.4: Connection Controls Implementation

**Goal**: Implement connection section UI with UID/serviceParam inputs and connect/disconnect button

**Estimated Time**: 20-25 minutes

---

## 📋 Analysis of Source Code

From Story 3 original ContentView connection section:
- UID TextField with placeholder text and validation
- ServiceParam TextField (secure or normal text)
- Connect/Disconnect button with dynamic label and color
- Button disabled states based on connection status
- Input fields disabled when connected
- Async task for connection operation

**What to adapt:**
- ✅ Copy TextField configuration patterns
- ✅ Implement toggleConnection() with async/await
- ✅ Add proper input validation
- ✅ Handle connection errors
- ❌ Remove: QR code scanner, NFC reader

---

## 🛠️ Implementation Steps

### Step 3.4.1: Update connectionSection in ContentView (15 min)

Open `ios/VeepaAudioTest/VeepaAudioTest/Views/ContentView.swift` and replace the `connectionSection` implementation:

```swift
// MARK: - Connection Section

private var connectionSection: some View {
    VStack(spacing: 12) {
        Text("Connection")
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)

        // Connection Status
        HStack {
            Circle()
                .fill(connectionStatusColor)
                .frame(width: 12, height: 12)
            Text(connectionService.connectionState.description)
                .font(.subheadline)
            Spacer()
        }

        // UID Input
        TextField("Camera UID (e.g., ABCD-123456-ABCDE)", text: $uid)
            .textFieldStyle(.roundedBorder)
            .autocapitalization(.allCharacters)
            .disabled(isConnected)
            .onChange(of: uid) { _, newValue in
                // Validate UID format (15 characters with dashes)
                if newValue.count > 18 {
                    uid = String(newValue.prefix(18))
                }
            }

        // Service Param Input
        TextField("Service Param (from authentication API)", text: $serviceParam)
            .textFieldStyle(.roundedBorder)
            .autocapitalization(.none)
            .autocorrectionDisabled(true)
            .disabled(isConnected)

        // Connect/Disconnect Button
        Button(action: toggleConnection) {
            HStack {
                if isConnecting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(isConnected ? "Disconnect" : "Connect")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(connectionButtonColor)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .disabled(isConnecting || (!isConnected && (uid.isEmpty || serviceParam.isEmpty)))
    }
    .padding()
}

// MARK: - Connection Button Color Helper

private var connectionButtonColor: Color {
    if isConnecting {
        return .orange
    }
    return isConnected ? .red : .blue
}
```

**✅ Verification:**
```bash
cd ios/VeepaAudioTest
xcodegen generate

# Build to check for syntax errors
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# Expected: BUILD SUCCEEDED
```

---

### Step 3.4.2: Implement toggleConnection() Action (8 min)

Replace the `toggleConnection()` placeholder in ContentView:

```swift
// MARK: - Actions

private func toggleConnection() {
    Task {
        if isConnected {
            // Disconnect
            await connectionService.disconnect()
        } else {
            // Connect
            await connectionService.connect(uid: uid, serviceParam: serviceParam)

            // Check for connection errors
            if case .error(let message) = connectionService.connectionState {
                errorMessage = message
                showingError = true
            }
        }
    }
}
```

**✅ Verification:**
```bash
# Build again to verify new code
cd ios/VeepaAudioTest
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# Expected: BUILD SUCCEEDED
```

---

### Step 3.4.3: Test UI in Simulator (5 min)

```bash
cd ios/VeepaAudioTest

# Run in simulator
open VeepaAudioTest.xcodeproj
# In Xcode: Press Cmd+R to run

# Manual test checklist:
# 1. App launches and shows connection section
# 2. UID TextField accepts input
# 3. ServiceParam TextField accepts input
# 4. Connect button is disabled when fields are empty
# 5. Connect button becomes enabled when both fields have text
# 6. Tapping Connect changes button to "Disconnect" and shows "Connecting..." status
```

**Expected UI Behavior:**
- Empty fields → Connect button disabled (grayed out)
- Both fields filled → Connect button enabled (blue)
- Tapping Connect → Button shows spinner, changes to orange, status shows "Connecting..."
- When connected → Fields become disabled, button shows "Disconnect" (red)

---

## ✅ Sub-Story 3.4 Complete Verification

Run all checks:

```bash
cd ios/VeepaAudioTest

# 1. Verify updated connectionSection
grep -A 30 "private var connectionSection" VeepaAudioTest/Views/ContentView.swift
# ✅ Expected: See TextField configurations and button implementation

# 2. Verify toggleConnection implementation
grep -A 15 "private func toggleConnection" VeepaAudioTest/Views/ContentView.swift
# ✅ Expected: See Task with async connect/disconnect logic

# 3. Build succeeds
xcodegen generate
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# ✅ Expected: BUILD SUCCEEDED

# 4. Run in simulator
# Open Xcode and run app, verify connection UI works
```

---

## 🎯 Acceptance Criteria

- [ ] Connection status indicator with color coding
- [ ] UID TextField (disabled when connected, validates length)
- [ ] ServiceParam TextField (disabled when connected)
- [ ] Connect/Disconnect button (color changes with state)
- [ ] Button disabled during connection or with empty inputs
- [ ] toggleConnection() action implemented with async/await
- [ ] UI updates reactively to connection state
- [ ] Progress spinner shows during connection

---

## 🚨 Testing Notes

**To test with real camera (optional at this stage):**

```bash
# Get camera credentials
curl -X POST https://authentication.eye4.cn/getInitstring \
  -H "Content-Type: application/json" \
  -d '{"uid": ["ABCD"]}'

# Response will contain serviceParam string
# Enter UID and serviceParam in app UI, tap Connect
```

**Expected outcomes:**
- If camera is reachable: Status changes to "Connected", clientPtr logged
- If network error: Status shows "Error: [message]", alert appears
- If credentials invalid: Connection fails, error displayed

---

## 🔗 Navigation

- ← Previous: [Sub-Story 3.3: ContentView Layout](sub-story-3.3-contentview-layout.md)
- → Next: [Sub-Story 3.5: Audio Controls](sub-story-3.5-audio-controls.md)
- ↑ Story Overview: [README.md](README.md)
