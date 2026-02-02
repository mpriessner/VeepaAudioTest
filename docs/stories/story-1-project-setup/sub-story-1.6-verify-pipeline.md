# Sub-Story 1.6: Verify Complete Build Pipeline

**Goal**: Test entire build pipeline end-to-end (Flutter → sync → Xcode → app launch)

**Estimated Time**: 15-20 minutes

---

## 📋 What We're Testing

This sub-story verifies the **complete build pipeline** works:

1. ✅ Flutter module builds → App.xcframework created
2. ✅ Frameworks sync to iOS project
3. ✅ XcodeGen generates .xcodeproj
4. ✅ iOS app compiles
5. ✅ App launches on simulator

**Why This Matters**: If any step fails, the entire project is broken. This is the most critical verification.

---

## 🛠️ Implementation Steps

### Step 1.6.1: Build Flutter Frameworks (5 min)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio

# Clean previous builds (if any)
flutter clean

# Build iOS frameworks for all configurations
flutter build ios-framework --output=build/ios/framework

# This takes 2-4 minutes on first run
```

**✅ Expected output:**
```
Building frameworks for com.example.veepaAudio in release mode...
Building com.example.veepaAudio for iOS...
Built frameworks for veepa_audio.
```

**✅ Verification:**
```bash
# Check frameworks were created
ls -la build/ios/framework/Debug/
# Expected: App.xcframework, Flutter.xcframework, FlutterPluginRegistrant.xcframework

ls -la build/ios/framework/Release/
# Expected: Same frameworks

ls -la build/ios/framework/Profile/
# Expected: Same frameworks
```

---

### Step 1.6.2: Sync Frameworks to iOS Project (2 min)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest

# Run sync script
SRCROOT="$(pwd)" CONFIGURATION="Debug" bash Scripts/sync-flutter-frameworks.sh
```

**✅ Expected output:**
```
=== Flutter Framework Sync (VeepaAudioTest) ===
Build config: Debug
Source: .../flutter_module/veepa_audio/build/ios/framework/Debug
Destination: .../ios/VeepaAudioTest/Flutter/Debug
Syncing App.xcframework...
App.xcframework synced successfully
Syncing FlutterPluginRegistrant.xcframework...
Syncing Flutter.xcframework...
=== Flutter Framework Sync Complete ===
```

**✅ Verification:**
```bash
# Check frameworks were copied to iOS project
ls -la Flutter/Debug/
# Expected: App.xcframework, Flutter.xcframework, FlutterPluginRegistrant.xcframework

# Verify timestamps are recent (just synced)
stat -f "%Sm" Flutter/Debug/App.xcframework
# Expected: Current date/time
```

---

### Step 1.6.3: Generate Xcode Project (2 min)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest

# Generate .xcodeproj from project.yml
xcodegen generate
```

**✅ Expected output:**
```
⚙️  Generating project...
⚙️  Writing project...
Created project at /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest/VeepaAudioTest.xcodeproj
```

**✅ Verification:**
```bash
# Check Xcode project exists
test -d VeepaAudioTest.xcodeproj && echo "✅ Xcode project generated"

# Check project file is valid
ls -la VeepaAudioTest.xcodeproj/project.pbxproj
# Expected: project.pbxproj file exists (several hundred KB)
```

---

### Step 1.6.4: Build iOS App (5 min)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest

# Build for iOS Simulator
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Debug \
  build
```

**✅ Expected output (last line):**
```
** BUILD SUCCEEDED **
```

**If build fails**, check these common issues:
- ❌ Flutter frameworks not synced → Re-run Step 1.6.2
- ❌ Bridging header not found → Check project.yml SWIFT_OBJC_BRIDGING_HEADER setting
- ❌ Framework not found → Check project.yml framework references
- ❌ Code signing error → Check Development Team in project.yml

**✅ Verification:**
```bash
# Check app binary was created
ls -la ~/Library/Developer/Xcode/DerivedData/VeepaAudioTest-*/Build/Products/Debug-iphonesimulator/VeepaAudioTest.app/
# Expected: VeepaAudioTest executable exists
```

---

### Step 1.6.5: Launch App on Simulator (3 min)

```bash
# Option 1: Open in Xcode and run
open VeepaAudioTest.xcodeproj
# Then click Run button (⌘R)

# Option 2: Command line launch
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Debug \
  run
```

**✅ Expected result:**
- Simulator launches
- App installs
- App opens showing placeholder ContentView:
  - 🔵 Blue waveform icon
  - "VeepaAudioTest" title
  - "Audio streaming test app for Veepa cameras" subtitle
  - "✅ Project Setup Complete" green badge

**📸 Take a screenshot** to document successful Story 1 completion!

---

## ✅ Sub-Story 1.6 Complete Verification (ALL TESTS)

Run these commands to verify **every aspect** of Story 1:

```bash
# === Flutter Module Tests ===
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio

# Test 1: Flutter dependencies installed
flutter pub get
# Expected: "Got dependencies!"

# Test 2: Flutter code analyzes without errors
flutter analyze
# Expected: "No issues found!"

# Test 3: Frameworks built
test -d build/ios/framework/Debug/App.xcframework && echo "✅ Debug frameworks exist"
test -d build/ios/framework/Release/App.xcframework && echo "✅ Release frameworks exist"

# === iOS Project Tests ===
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest

# Test 4: Frameworks synced to iOS
test -d Flutter/Debug/App.xcframework && echo "✅ Frameworks synced"

# Test 5: Xcode project generated
test -f VeepaAudioTest.xcodeproj/project.pbxproj && echo "✅ Xcode project exists"

# Test 6: Project YAML is valid
python3 -c "import yaml; yaml.safe_load(open('project.yml'))" && echo "✅ project.yml valid"

# Test 7: Info.plist is valid
plutil -lint VeepaAudioTest/Resources/Info.plist && echo "✅ Info.plist valid"

# Test 8: Required permissions present
grep -q "NSMicrophoneUsageDescription" VeepaAudioTest/Resources/Info.plist && echo "✅ Microphone permission"
grep -q "NSLocalNetworkUsageDescription" VeepaAudioTest/Resources/Info.plist && echo "✅ Network permission"

# Test 9: App compiles
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Debug \
  build | tail -n 1
# Expected: "** BUILD SUCCEEDED **"
```

**✅ If all 9 tests pass**, Story 1 is complete!

---

## 🎯 Acceptance Criteria

- [ ] Flutter frameworks build successfully
- [ ] Frameworks sync to iOS project
- [ ] `xcodegen generate` creates .xcodeproj
- [ ] Xcode project compiles without errors
- [ ] App launches on iOS Simulator
- [ ] Placeholder UI displays correctly

---

## 🎉 Story 1 Complete!

**Deliverables Created:**
- ✅ Flutter module with method channel structure
- ✅ iOS project with XcodeGen configuration
- ✅ Build scripts for framework synchronization
- ✅ Working app that compiles and launches
- ✅ Proper permissions and configuration

**What Works Now:**
- Complete build pipeline (Flutter → iOS)
- App launches with placeholder UI
- Project structure ready for SDK integration

**Total Story 1 Time:** ~1.5-2 hours (as estimated)

**Next Step:** Proceed to [Story 2: SDK Integration](../story-2-sdk-integration/README.md)

---

## 🔗 Navigation

- ← Previous: [Sub-Story 1.5: iOS App Entry](sub-story-1.5-ios-app-entry.md)
- ↑ Story Overview: [README.md](README.md)
- → Next Story: [Story 2: SDK Integration](../story-2-sdk-integration/README.md)
