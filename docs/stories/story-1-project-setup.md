# Story 1: Project Setup and Initial Structure

**Epic**: VeepaAudioTest - Minimal Audio Testing App
**Story**: Initialize Xcode project and Flutter module
**Estimated Time**: 45-60 minutes

---

## 📋 Story Description

As a **developer**, I want to **set up the basic project structure for VeepaAudioTest** so that **I have a working iOS app with Flutter integration ready for audio testing**.

---

## ✅ Acceptance Criteria

1. Xcode project exists and builds successfully (empty app)
2. Flutter module `veepa_audio` exists and can be built
3. Build script `sync-flutter-frameworks.sh` correctly links Flutter frameworks
4. XcodeGen configuration generates project correctly
5. App launches on simulator or device and shows placeholder UI
6. Info.plist includes microphone permission
7. Project uses manual signing (no team ID required yet)

---

## 🔧 Implementation Steps

### Step 1.1: Create Flutter Module (15 minutes)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module

# Create minimal Flutter module
flutter create --template=module veepa_audio

cd veepa_audio
```

**Edit `pubspec.yaml`**:
```yaml
name: veepa_audio
description: Minimal Flutter module for Veepa audio testing
publish_to: 'none'

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # P2P SDK plugin (will copy from SciSymbioLens)
  vsdk:
    path: ios/.symlinks/plugins/vsdk

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0
```

**Create placeholder `lib/main.dart`**:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const AudioTestApp());

class AudioTestApp extends StatefulWidget {
  const AudioTestApp({Key? key}) : super(key: key);

  @override
  State<AudioTestApp> createState() => _AudioTestAppState();
}

class _AudioTestAppState extends State<AudioTestApp> {
  static const platform = MethodChannel('com.veepatest/audio');

  @override
  void initState() {
    super.initState();
    _signalReady();
  }

  Future<void> _signalReady() async {
    try {
      await platform.invokeMethod('flutterReady');
      print('[Flutter] Ready signal sent to iOS');
    } catch (e) {
      print('[Flutter] Error signaling ready: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Veepa Audio Test',
      home: Scaffold(
        appBar: AppBar(title: const Text('Audio Test')),
        body: const Center(child: Text('Flutter Module Ready')),
      ),
    );
  }
}
```

**Test Flutter module builds**:
```bash
# This must succeed before iOS integration
flutter build ios-framework --output=build/ios/framework
```

**Expected Output**:
```
✓ Built Flutter frameworks for ios
  └─ Debug: build/ios/framework/Debug/
  └─ Release: build/ios/framework/Release/
```

---

### Step 1.2: Create XcodeGen Configuration (15 minutes)

Create `ios/VeepaAudioTest/project.yml`:

```yaml
name: VeepaAudioTest
options:
  bundleIdPrefix: com.veepa.audiotest
  deploymentTarget:
    iOS: 17.0

targets:
  VeepaAudioTest:
    type: application
    platform: iOS

    sources:
      - VeepaAudioTest

    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.veepa.audiotest
      INFOPLIST_FILE: VeepaAudioTest/Info.plist
      SWIFT_VERSION: 5.9
      CODE_SIGN_STYLE: Manual
      DEVELOPMENT_TEAM: ""

      # Flutter framework search paths
      FRAMEWORK_SEARCH_PATHS:
        - $(inherited)
        - $(PROJECT_DIR)/Flutter
        - $(PROJECT_DIR)/FlutterPlugins

      # Link Flutter and plugins
      OTHER_LDFLAGS:
        - $(inherited)
        - -framework Flutter
        - -framework vsdk

      # Enable bitcode (required for libVSTC.a)
      ENABLE_BITCODE: NO

    dependencies:
      - framework: Flutter/Flutter.xcframework
        embed: true
      - framework: FlutterPlugins/vsdk.xcframework
        embed: true

    scheme:
      testTargets:
        - VeepaAudioTestTests
      gatherCoverageData: true

  VeepaAudioTestTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - VeepaAudioTestTests
    dependencies:
      - target: VeepaAudioTest
```

---

### Step 1.3: Create Build Script (10 minutes)

Create `ios/VeepaAudioTest/Scripts/sync-flutter-frameworks.sh`:

```bash
#!/bin/bash
set -e

# This script copies Flutter frameworks from the flutter_module build to the iOS project
# It must be run AFTER `flutter build ios-framework`

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
FLUTTER_MODULE="$PROJECT_ROOT/flutter_module/veepa_audio"
IOS_PROJECT="$PROJECT_ROOT/ios/VeepaAudioTest"

echo "📦 Syncing Flutter frameworks..."
echo "   Flutter module: $FLUTTER_MODULE"
echo "   iOS project: $IOS_PROJECT"

# Configuration: Debug or Release
CONFIG="${CONFIGURATION:-Debug}"
echo "   Configuration: $CONFIG"

FLUTTER_BUILD="$FLUTTER_MODULE/build/ios/framework/$CONFIG"

if [ ! -d "$FLUTTER_BUILD" ]; then
    echo "❌ Flutter frameworks not found at: $FLUTTER_BUILD"
    echo "   Run: cd flutter_module/veepa_audio && flutter build ios-framework"
    exit 1
fi

# Create Flutter framework directories
mkdir -p "$IOS_PROJECT/Flutter"
mkdir -p "$IOS_PROJECT/FlutterPlugins"

# Copy Flutter.xcframework
echo "   Copying Flutter.xcframework..."
rsync -av --delete "$FLUTTER_BUILD/Flutter.xcframework" "$IOS_PROJECT/Flutter/"

# Copy plugin frameworks (vsdk)
if [ -d "$FLUTTER_BUILD/vsdk.xcframework" ]; then
    echo "   Copying vsdk.xcframework..."
    rsync -av --delete "$FLUTTER_BUILD/vsdk.xcframework" "$IOS_PROJECT/FlutterPlugins/"
else
    echo "⚠️  vsdk.xcframework not found (will be added in Story 2)"
fi

echo "✅ Flutter frameworks synced successfully"
```

Make it executable:
```bash
chmod +x ios/VeepaAudioTest/Scripts/sync-flutter-frameworks.sh
```

---

### Step 1.4: Create iOS App Structure (15 minutes)

Create `ios/VeepaAudioTest/VeepaAudioTest/VeepaAudioTestApp.swift`:

```swift
import SwiftUI

@main
struct VeepaAudioTestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

Create `ios/VeepaAudioTest/VeepaAudioTest/Views/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @State private var statusMessage = "App Initialized"

    var body: some View {
        VStack(spacing: 20) {
            Text("Veepa Audio Test")
                .font(.largeTitle)
                .padding()

            Text(statusMessage)
                .foregroundColor(.gray)
                .padding()

            Spacer()

            Text("Ready for Flutter Integration")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
```

Create `ios/VeepaAudioTest/VeepaAudioTest/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
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
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <true/>
    </dict>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>

    <!-- IMPORTANT: Microphone permission for audio streaming -->
    <key>NSMicrophoneUsageDescription</key>
    <string>This app needs microphone access to test audio streaming from the camera.</string>
</dict>
</plist>
```

---

### Step 1.5: Generate Xcode Project and Build (10 minutes)

```bash
cd ios/VeepaAudioTest

# Generate Xcode project
xcodegen generate

# Build Flutter frameworks first
cd ../../flutter_module/veepa_audio
flutter build ios-framework --output=build/ios/framework

# Sync frameworks to iOS project
cd ../../ios/VeepaAudioTest
bash Scripts/sync-flutter-frameworks.sh

# Build iOS app
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
```

**Expected Output**:
```
** BUILD SUCCEEDED **
```

---

## 🧪 Testing & Verification

### Test 1: Flutter Module Builds
```bash
cd flutter_module/veepa_audio
flutter build ios-framework
```
✅ **Expected**: Frameworks created in `build/ios/framework/Debug/`

### Test 2: Xcode Project Generates
```bash
cd ios/VeepaAudioTest
xcodegen generate
```
✅ **Expected**: `VeepaAudioTest.xcodeproj` created

### Test 3: Frameworks Sync
```bash
bash Scripts/sync-flutter-frameworks.sh
```
✅ **Expected**:
- `Flutter/Flutter.xcframework` exists
- Console shows "✅ Flutter frameworks synced successfully"

### Test 4: iOS App Builds
```bash
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
```
✅ **Expected**: `** BUILD SUCCEEDED **`

### Test 5: App Launches
Run in Xcode or:
```bash
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  test
```
✅ **Expected**: Simulator shows "Veepa Audio Test" title

---

## 📊 Deliverables

After completing this story:

- [x] `flutter_module/veepa_audio/` - Flutter module with placeholder main.dart
- [x] `ios/VeepaAudioTest/project.yml` - XcodeGen configuration
- [x] `ios/VeepaAudioTest/Scripts/sync-flutter-frameworks.sh` - Build script
- [x] `ios/VeepaAudioTest/VeepaAudioTest/` - iOS app structure
- [x] `ios/VeepaAudioTest/VeepaAudioTest/Info.plist` - With microphone permission
- [x] `ios/VeepaAudioTest/VeepaAudioTest.xcodeproj` - Generated Xcode project
- [x] App builds and launches successfully

---

## 🚨 Common Issues

### Issue 1: Flutter frameworks not found
**Error**: `Flutter.xcframework not found`
**Fix**: Run `flutter build ios-framework` first

### Issue 2: XcodeGen not installed
**Error**: `xcodegen: command not found`
**Fix**: `brew install xcodegen`

### Issue 3: Xcode project won't build
**Error**: `Framework not found Flutter`
**Fix**: Run `bash Scripts/sync-flutter-frameworks.sh`

---

## ⏭️ Next Story

**Story 2**: Copy Flutter SDK Integration and P2P Services

This story adds:
- P2P SDK (libVSTC.a) integration
- FlutterEngineManager and VSTCBridge
- Platform channel communication
