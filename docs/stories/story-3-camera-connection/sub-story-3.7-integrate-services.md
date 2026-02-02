# Sub-Story 3.7: Integrate Services with AppDelegate

**Goal**: Wire up services to ContentView and update AppDelegate to use SwiftUI lifecycle

**Estimated Time**: 20-25 minutes

---

## 📋 Analysis of Source Code

From Story 1 original VeepaAudioTestApp structure:
- SwiftUI app entry point with @main
- WindowGroup for scene management
- Proper app lifecycle with ContentView as root
- Info.plist configuration for launch screen

**What to adapt:**
- ✅ Create proper SwiftUI app entry point
- ✅ Wire ContentView as root view
- ✅ Ensure services initialize correctly
- ✅ Update Info.plist for SwiftUI app
- ❌ Remove: UIKit AppDelegate/SceneDelegate (use pure SwiftUI)

---

## 🛠️ Implementation Steps

### Step 3.7.1: Create VeepaAudioTestApp.swift (10 min)

Create `ios/VeepaAudioTest/VeepaAudioTest/VeepaAudioTestApp.swift`:

```swift
// ADAPTED FROM: Story 1 iOS app entry point pattern
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
```

**✅ Verification:**
```bash
cd ios/VeepaAudioTest

# Check file created
ls -la VeepaAudioTest/VeepaAudioTestApp.swift
# Expected: File exists

# Build
xcodegen generate
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# Expected: BUILD SUCCEEDED
```

---

### Step 3.7.2: Update project.yml for SwiftUI App (8 min)

Update `ios/VeepaAudioTest/project.yml` to include app entry point:

```yaml
targets:
  VeepaAudioTest:
    type: application
    platform: iOS
    deploymentTarget: "15.0"

    sources:
      - path: VeepaAudioTest
        name: App
        type: group
        excludes:
          - "*.md"
          - ".DS_Store"
      - path: VeepaAudioTest/Services
        name: Services
        type: group
      - path: VeepaAudioTest/Views
        name: Views
        type: group

    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.veepatest.audio
        INFOPLIST_FILE: VeepaAudioTest/Info.plist
        SWIFT_OBJC_BRIDGING_HEADER: VeepaAudioTest/VeepaAudioTest-Bridging-Header.h
        CODE_SIGN_STYLE: Automatic
        DEVELOPMENT_TEAM: ""  # Add your team ID if needed

        # SwiftUI specific
        ENABLE_PREVIEWS: YES

        # Framework search paths
        FRAMEWORK_SEARCH_PATHS:
          - $(inherited)
          - $(PROJECT_DIR)/Frameworks/Flutter
          - $(PROJECT_DIR)/Frameworks/Plugins
```

**✅ Verification:**
```bash
cd ios/VeepaAudioTest

# Regenerate Xcode project
xcodegen generate

# Verify app entry point is recognized
grep -r "VeepaAudioTestApp" VeepaAudioTest.xcodeproj/
# Expected: File referenced in project

# Build
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# Expected: BUILD SUCCEEDED
```

---

### Step 3.7.3: Update Info.plist for SwiftUI (5 min)

Ensure `ios/VeepaAudioTest/VeepaAudioTest/Info.plist` has required keys:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- App Configuration -->
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>

    <!-- SwiftUI Launch -->
    <key>UILaunchScreen</key>
    <dict>
        <key>UIColorName</key>
        <string>LaunchScreenBackground</string>
    </dict>

    <!-- Permissions -->
    <key>NSMicrophoneUsageDescription</key>
    <string>This app needs microphone access to test camera audio streaming.</string>
    <key>NSLocalNetworkUsageDescription</key>
    <string>This app needs local network access to connect to cameras via P2P.</string>

    <!-- iOS Configuration -->
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>arm64</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
</dict>
</plist>
```

**✅ Verification:**
```bash
cd ios/VeepaAudioTest

# Validate Info.plist XML
plutil -lint VeepaAudioTest/Info.plist
# Expected: OK

# Check required keys
grep -A 1 "UILaunchScreen" VeepaAudioTest/Info.plist
grep -A 1 "NSMicrophoneUsageDescription" VeepaAudioTest/Info.plist
# Expected: Both keys found
```

---

### Step 3.7.4: Test Complete App Launch (5 min)

```bash
cd ios/VeepaAudioTest

# Clean build
xcodebuild clean -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest

# Build
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build

# Run in simulator
open VeepaAudioTest.xcodeproj
# In Xcode: Select iPhone 15 simulator, press Cmd+R

# Verify:
# 1. App launches without crashes
# 2. ContentView displays with all three sections
# 3. Connection section shows "Disconnected" status
# 4. Audio controls show "Stopped" status
# 5. Debug log shows "0 log entries"
# 6. All buttons are in correct initial state
```

---

## ✅ Sub-Story 3.7 Complete Verification

Run all checks:

```bash
cd ios/VeepaAudioTest

# 1. Verify app entry point exists
ls -la VeepaAudioTest/VeepaAudioTestApp.swift
# ✅ Expected: File present with @main

# 2. Verify Info.plist has required keys
grep "UILaunchScreen" VeepaAudioTest/Info.plist
grep "NSMicrophoneUsageDescription" VeepaAudioTest/Info.plist
# ✅ Expected: Both keys found

# 3. Verify project structure
xcodegen generate
tree -L 2 VeepaAudioTest/
# ✅ Expected: Services/ and Views/ directories present

# 4. Complete build succeeds
xcodebuild clean -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# ✅ Expected: BUILD SUCCEEDED

# 5. App launches in simulator
# Open Xcode and run - should launch without errors
```

---

## 🎯 Acceptance Criteria

- [ ] VeepaAudioTestApp.swift created with @main
- [ ] WindowGroup with ContentView as root
- [ ] Services properly initialized
- [ ] Info.plist has UILaunchScreen key
- [ ] Info.plist has microphone permission
- [ ] project.yml includes all source groups
- [ ] App compiles and launches successfully
- [ ] All UI elements render correctly
- [ ] No crashes on launch

---

## 🚨 Common Issues

### Issue 1: "Cannot find 'ContentView' in scope"
**Fix**: Ensure ContentView.swift is in the Views group and included in project.yml sources

### Issue 2: "Missing Info.plist key: UILaunchScreen"
**Fix**: Add UILaunchScreen dictionary to Info.plist (already included above)

### Issue 3: App launches to blank screen
**Fix**:
1. Check VeepaAudioTestApp has @main attribute
2. Verify WindowGroup contains ContentView()
3. Check ContentView's body returns a valid View

### Issue 4: Services not initializing
**Fix**:
1. Verify @StateObject declarations in ContentView
2. Check service classes conform to ObservableObject
3. Ensure FlutterEngineManager and VeepaConnectionBridge are accessible

---

## 🔗 Navigation

- ← Previous: [Sub-Story 3.6: Debug Log View](sub-story-3.6-debug-log-view.md)
- → Next: [Sub-Story 3.8: End-to-End Test](sub-story-3.8-end-to-end-test.md)
- ↑ Story Overview: [README.md](README.md)
