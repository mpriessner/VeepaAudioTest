# Story 1: Project Setup and Initial Structure (ENHANCED)

**Epic**: VeepaAudioTest - Minimal Audio Testing App
**Story**: Initialize Xcode project and Flutter module with proper build infrastructure
**Total Estimated Time**: 1.5-2 hours

---

## 📋 Story Overview

Create a minimal but properly configured iOS + Flutter project that mirrors the essential build setup from SciSymbioLens, but stripped down to just what's needed for audio testing.

**What We're Building:**
- Flutter module with P2P SDK plugin structure
- XcodeGen-based iOS project
- Build scripts that sync Flutter frameworks
- Proper Info.plist with required permissions
- Working build pipeline

**What We're Adapting from SciSymbioLens:**
- Build infrastructure (`project.yml`, `sync-flutter-frameworks.sh`)
- Flutter plugin structure (vsdk plugin layout)
- Info.plist permissions (only audio-related)
- NOT copying: Supabase, GoogleGenerativeAI, Gemini services, video logic

---

## 📊 Sub-Stories Breakdown

### Sub-Story 1.1: Flutter Module Structure
⏱️ **Estimated Time**: 20-25 minutes

### Sub-Story 1.2: Copy P2P SDK Plugin Structure
⏱️ **Estimated Time**: 15-20 minutes

### Sub-Story 1.3: Create XcodeGen Configuration
⏱️ **Estimated Time**: 30-40 minutes

### Sub-Story 1.4: Create Build Scripts
⏱️ **Estimated Time**: 15-20 minutes

### Sub-Story 1.5: Create iOS App Entry Point
⏱️ **Estimated Time**: 10-15 minutes

### Sub-Story 1.6: Verify Complete Build Pipeline
⏱️ **Estimated Time**: 15-20 minutes

---

## 🔧 Sub-Story 1.1: Flutter Module Structure

**Goal**: Create minimal Flutter module with correct directory layout for P2P SDK plugin

### Analysis of Source Code

From `SciSymbioLens/flutter_module/veepa_camera/`:
- Has `pubspec.yaml` with dependencies
- Has `lib/main.dart` entry point
- Has `lib/sdk/` for P2P bindings
- Has nested plugin structure: `ios/.symlinks/plugins/vsdk/`

**What to adapt:**
- ✅ Copy pubspec structure, but remove video-related dependencies
- ✅ Create method channel setup in main.dart
- ✅ Prepare plugin directory structure
- ❌ Remove: video rendering, discovery, provisioning

### Implementation Steps

#### Step 1.1.1: Create Module (5 min)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest

# Create Flutter module structure
mkdir -p flutter_module
cd flutter_module
flutter create --template=module veepa_audio
cd veepa_audio
```

**✅ Verification:**
```bash
# Should see Flutter module structure
ls -la
# Expected output:
# .android/
# .ios/
# lib/
# pubspec.yaml
# test/
```

#### Step 1.2: Create pubspec.yaml (5 min)

**Adapt from**: `SciSymbioLens/flutter_module/veepa_camera/pubspec.yaml`

Create `flutter_module/veepa_audio/pubspec.yaml`:

```yaml
name: veepa_audio
description: Minimal Flutter module for Veepa camera audio testing
publish_to: 'none'

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # ADAPTED: Only ffi dependency for P2P SDK bindings
  ffi: ^2.0.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0

# ADAPTED: flutter block for plugin configuration
flutter:
  module:
    androidX: true
    androidPackage: com.veepatest.audio
    iosBundleIdentifier: com.veepatest.audio
```

**✅ Verification:**
```bash
flutter pub get
# Expected: Resolving dependencies... Got dependencies!
```

#### Step 1.1.3: Create main.dart with Method Channel (10 min)

**Adapt from**: `SciSymbioLens/flutter_module/veepa_camera/lib/main.dart`

Key adaptations:
- Keep: Method channel setup, flutterReady signal
- Remove: Video widgets, state management
- Add: Audio-specific method handlers (startAudio, stopAudio, setMute)

Create `flutter_module/veepa_audio/lib/main.dart`:

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
  // ADAPTED: Match SciSymbioLens channel name pattern
  static const platform = MethodChannel('com.veepatest/audio');

  int? _clientPtr;
  String _statusMessage = 'Flutter module initialized';

  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
    _signalReady();
  }

  /// ADAPTED FROM: SciSymbioLens FlutterEngineManager communication pattern
  void _setupMethodChannel() {
    platform.setMethodCallHandler((call) async {
      print('[Flutter] Method call received: ${call.method}');

      switch (call.method) {
        case 'setClientPtr':
          // Called by iOS when P2P connection succeeds
          final ptr = call.arguments as int;
          setState(() {
            _clientPtr = ptr;
            _statusMessage = 'Connected (clientPtr: $ptr)';
          });
          print('[Flutter] Audio player initialized with clientPtr: $ptr');
          return null;

        case 'startAudio':
          // Will be implemented in Story 2 with actual P2P SDK calls
          print('[Flutter] startAudio called (stub - will implement in Story 2)');
          setState(() => _statusMessage = 'Audio started (stub)');
          return 0; // Success

        case 'stopAudio':
          print('[Flutter] stopAudio called (stub - will implement in Story 2)');
          setState(() => _statusMessage = 'Audio stopped (stub)');
          return 0;

        case 'setMute':
          final muted = call.arguments as bool;
          print('[Flutter] setMute($muted) called (stub)');
          setState(() => _statusMessage = 'Mute: $muted (stub)');
          return 0;

        default:
          print('[Flutter] Unknown method: ${call.method}');
          throw MissingPluginException('Method ${call.method} not implemented');
      }
    });
  }

  /// ADAPTED FROM: SciSymbioLens FlutterEngineManager ready signal
  /// This is critical - iOS waits for this signal before calling methods
  Future<void> _signalReady() async {
    try {
      await platform.invokeMethod('flutterReady');
      print('[Flutter] ✅ Ready signal sent to iOS');
      setState(() => _statusMessage = 'Flutter ready');
    } catch (e) {
      print('[Flutter] ❌ Error signaling ready: $e');
      setState(() => _statusMessage = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Veepa Audio Test',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mic,
                size: 64,
                color: Colors.white70,
              ),
              const SizedBox(height: 20),
              Text(
                'Audio Test Module',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _statusMessage,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              if (_clientPtr != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Client Ptr: $_clientPtr',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'Courier',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

**✅ Verification:**
```bash
# Check for syntax errors
flutter analyze lib/main.dart
# Expected: No issues found!
```

#### Step 1.1.4: Create Plugin Directory Structure (5 min)

The P2P SDK (libVSTC.a) will live in a Flutter plugin structure:

```bash
cd flutter_module/veepa_audio

# Create plugin structure (matching SciSymbioLens layout)
mkdir -p ios/.symlinks/plugins/vsdk/ios/Classes

# Create placeholder file (will copy actual SDK in Story 2)
touch ios/.symlinks/plugins/vsdk/ios/Classes/.gitkeep

# Verify structure
tree ios/.symlinks/plugins/
# Expected:
# ios/.symlinks/plugins/
# └── vsdk/
#     └── ios/
#         └── Classes/
#             └── .gitkeep
```

**✅ Verification:**
```bash
ls -la ios/.symlinks/plugins/vsdk/ios/Classes/
# Should see .gitkeep file
```

---

### ✅ Sub-Story 1.1 Complete Verification

Run all checks:

```bash
cd flutter_module/veepa_audio

# 1. Dependencies resolved
flutter pub get
# ✅ Expected: "Got dependencies!"

# 2. No analysis issues
flutter analyze
# ✅ Expected: "No issues found!"

# 3. Plugin structure exists
ls -la ios/.symlinks/plugins/vsdk/ios/
# ✅ Expected: See Classes/ directory

# 4. Main.dart compiles
flutter build ios-framework --no-codesign --output=build/test
# ✅ Expected: BUILD SUCCEEDED (but no SDK yet, that's ok)
```

**Acceptance Criteria:**
- [ ] Flutter module created with correct structure
- [ ] pubspec.yaml has ffi dependency
- [ ] main.dart implements method channel with flutterReady signal
- [ ] Plugin directory structure created
- [ ] `flutter pub get` succeeds
- [ ] `flutter analyze` shows no issues

---

## 🔧 Sub-Story 1.2: Copy P2P SDK Plugin Structure

**Goal**: Copy the vsdk plugin structure from SciSymbioLens (but NOT the binary yet - that comes in Story 2)

### Analysis of Source Code

From `SciSymbioLens/flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk/`:
```
vsdk/
├── ios/
│   ├── Classes/
│   │   ├── VsdkPlugin.h
│   │   ├── VsdkPlugin.m
│   │   ├── AppP2PApiPlugin.h
│   │   └── AppPlayerPlugin.h
│   ├── libVSTC.a (45MB - will copy in Story 2)
│   └── vsdk.podspec
```

**What to copy NOW:**
- ✅ Plugin header files (.h)
- ✅ Plugin implementation (.m)
- ✅ Podspec configuration
- ❌ NOT copying libVSTC.a yet (Story 2)

### Implementation Steps

#### Step 1.2.1: Copy Plugin Source Files (10 min)

```bash
# From SciSymbioLens root
cd /Users/mpriessner/windsurf_repos/SciSymbioLens

SOURCE_PLUGIN="flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk"
DEST_PLUGIN="/Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio/ios/.symlinks/plugins/vsdk"

# Copy plugin header and implementation files
cp "$SOURCE_PLUGIN/ios/Classes/VsdkPlugin.h" "$DEST_PLUGIN/ios/Classes/"
cp "$SOURCE_PLUGIN/ios/Classes/VsdkPlugin.m" "$DEST_PLUGIN/ios/Classes/"
cp "$SOURCE_PLUGIN/ios/Classes/AppP2PApiPlugin.h" "$DEST_PLUGIN/ios/Classes/"
cp "$SOURCE_PLUGIN/ios/Classes/AppPlayerPlugin.h" "$DEST_PLUGIN/ios/Classes/"

# Verify
ls -lh "$DEST_PLUGIN/ios/Classes/"
```

**✅ Verification:**
```bash
ls -la /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio/ios/.symlinks/plugins/vsdk/ios/Classes/
# Expected output:
# VsdkPlugin.h
# VsdkPlugin.m
# AppP2PApiPlugin.h
# AppPlayerPlugin.h
```

#### Step 1.2.2: Create Podspec (5 min)

**Adapt from**: `SciSymbioLens/flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk/ios/vsdk.podspec`

Create `flutter_module/veepa_audio/ios/.symlinks/plugins/vsdk/ios/vsdk.podspec`:

```ruby
#
# ADAPTED FROM: SciSymbioLens vsdk.podspec
# Changes: Simplified description, minimal config
#

Pod::Spec.new do |s|
  s.name             = 'vsdk'
  s.version          = '1.0.0'
  s.summary          = 'Veepa P2P SDK for Flutter (Audio Test)'
  s.description      = 'Native iOS bindings for VStarcam P2P SDK - minimal audio testing version'
  s.homepage         = 'https://veepa.com'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Veepa' => 'support@veepa.com' }
  s.source           = { :path => '.' }

  # Plugin source files
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'

  # P2P SDK static library (will be added in Story 2)
  # s.vendored_libraries = 'libVSTC.a'

  # System dependencies required by P2P SDK
  s.frameworks = 'AVFoundation', 'VideoToolbox', 'AudioToolbox', 'CoreMedia', 'CoreVideo'
  s.libraries = 'z', 'c++', 'iconv', 'bz2'

  # iOS configuration
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    # Disable bitcode (required for libVSTC.a)
    'ENABLE_BITCODE' => 'NO'
  }

  s.swift_version = '5.0'
end
```

**✅ Verification:**
```bash
# Validate podspec syntax
cd flutter_module/veepa_audio/ios/.symlinks/plugins/vsdk/ios
pod spec lint vsdk.podspec --allow-warnings
# Expected: "vsdk.podspec passed validation" (warnings OK, libVSTC.a not present yet)
```

---

### ✅ Sub-Story 1.2 Complete Verification

```bash
# 1. Plugin files copied
ls flutter_module/veepa_audio/ios/.symlinks/plugins/vsdk/ios/Classes/
# ✅ Expected: 4 files (VsdkPlugin.h, VsdkPlugin.m, AppP2PApiPlugin.h, AppPlayerPlugin.h)

# 2. Podspec created
cat flutter_module/veepa_audio/ios/.symlinks/plugins/vsdk/ios/vsdk.podspec
# ✅ Expected: See podspec content

# 3. Podspec validates
cd flutter_module/veepa_audio/ios/.symlinks/plugins/vsdk/ios
pod spec lint vsdk.podspec --allow-warnings
# ✅ Expected: Passed validation
```

**Acceptance Criteria:**
- [ ] VsdkPlugin header and implementation copied
- [ ] AppP2PApiPlugin header copied
- [ ] AppPlayerPlugin header copied
- [ ] vsdk.podspec created with correct frameworks/libraries
- [ ] Podspec validates (with warnings OK)

---

## 🔧 Sub-Story 1.3: Create XcodeGen Configuration

**Goal**: Create project.yml that generates a working Xcode project, adapted from SciSymbioLens

### Analysis of Source Code

From `SciSymbioLens/ios/SciSymbioLens/project.yml`:
- Uses XcodeGen for reproducible builds
- Has preBuildScripts to sync Flutter frameworks
- Links to Flutter frameworks (Debug/Release)
- Links libVSTC.a static library
- Links system frameworks (AVFoundation, AudioToolbox, etc.)
- Has proper Swift/ObjC bridging header

**What to adapt:**
- ✅ Keep: Framework linking, build scripts, system dependencies
- ✅ Simplify: Remove Supabase, GoogleGenerativeAI packages
- ✅ Simplify: Remove test targets (for now)
- ❌ Remove: Video-specific settings, Gemini dependencies

### Implementation Steps

#### Step 1.3.1: Create Base Configuration (15 min)

Create `ios/VeepaAudioTest/project.yml`:

```yaml
#
# ADAPTED FROM: SciSymbioLens/ios/SciSymbioLens/project.yml
# Changes: Removed Supabase, GoogleGenerativeAI, simplified for audio testing
#

name: VeepaAudioTest
options:
  bundleIdPrefix: com.veepatest
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "15.0"
  developmentLanguage: en

# ADAPTED: No external Swift packages needed
# (SciSymbioLens had Supabase and GoogleGenerativeAI)
packages: {}

settings:
  base:
    SWIFT_VERSION: "5.9"
    TARGETED_DEVICE_FAMILY: "1"  # iPhone only
    INFOPLIST_FILE: VeepaAudioTest/Resources/Info.plist
    GENERATE_INFOPLIST_FILE: NO
    ENABLE_PREVIEWS: YES
    ENABLE_USER_SCRIPT_SANDBOXING: NO  # Required for build scripts

targets:
  VeepaAudioTest:
    type: application
    platform: iOS

    # ADAPTED: Pre-build script to sync Flutter frameworks
    # This is CRITICAL - must run before Xcode tries to link frameworks
    preBuildScripts:
      - name: Sync Flutter Frameworks
        script: |
          "${SRCROOT}/Scripts/sync-flutter-frameworks.sh"
        basedOnDependencyAnalysis: false

    sources:
      - path: VeepaAudioTest
        excludes:
          - "**/.DS_Store"

      # ADAPTED: Include Veepa SDK plugin files
      # (SciSymbioLens has this in VeepaSDK/ folder)
      - path: VeepaSDK/VsdkPlugin.h
      - path: VeepaSDK/VsdkPlugin.m
      - path: VeepaSDK/AppP2PApiPlugin.h
      - path: VeepaSDK/AppPlayerPlugin.h

    dependencies:
      # ADAPTED: Flutter frameworks (Debug build - will add Release later)
      # These paths are synced by the pre-build script
      - framework: Flutter/Debug/Flutter.xcframework
        embed: true
      - framework: Flutter/Debug/App.xcframework
        embed: true
      - framework: Flutter/Debug/FlutterPluginRegistrant.xcframework
        embed: true

      # ADAPTED: P2P SDK static library (will be added in Story 2)
      # - framework: VeepaSDK/libVSTC.a
      #   embed: false

      # ADAPTED: System libraries required by P2P SDK
      - sdk: libz.tbd
      - sdk: libc++.tbd
      - sdk: libiconv.tbd
      - sdk: libbz2.tbd

      # ADAPTED: System frameworks required for audio streaming
      - sdk: AVFoundation.framework
      - sdk: AudioToolbox.framework
      - sdk: CoreMedia.framework
      - sdk: CoreVideo.framework
      # VideoToolbox will be needed when we add video in future (not needed for audio-only)

    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.veepatest.audio
        MARKETING_VERSION: "1.0.0"
        CURRENT_PROJECT_VERSION: "1"
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        CODE_SIGN_STYLE: Manual
        CODE_SIGN_IDENTITY: ""
        DEVELOPMENT_TEAM: ""
        ENABLE_PREVIEWS: YES
        CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES: YES

        # ADAPTED: Bridging header for Swift <-> ObjC interop
        SWIFT_OBJC_BRIDGING_HEADER: VeepaAudioTest/App/VeepaAudioTest-Bridging-Header.h

        # ADAPTED: Search paths for VeepaSDK headers and Flutter
        HEADER_SEARCH_PATHS: "$(inherited) $(SRCROOT)/VeepaSDK $(SRCROOT)/Flutter"
        LIBRARY_SEARCH_PATHS: "$(inherited) $(SRCROOT)/VeepaSDK"

        # ADAPTED: Disable bitcode (required for libVSTC.a)
        ENABLE_BITCODE: NO

schemes:
  VeepaAudioTest:
    build:
      targets:
        VeepaAudioTest: all
    run:
      config: Debug
    profile:
      config: Release
    analyze:
      config: Debug
    archive:
      config: Release
```

**✅ Verification:**
```bash
# Check YAML syntax
python3 -c "import yaml; yaml.safe_load(open('ios/VeepaAudioTest/project.yml'))"
# ✅ Expected: No output (syntax valid)
```

#### Step 1.3.2: Create Bridging Header (5 min)

**Purpose**: Allows Swift code to call Objective-C plugin code

Create `ios/VeepaAudioTest/VeepaAudioTest/App/VeepaAudioTest-Bridging-Header.h`:

```objective-c
//
// ADAPTED FROM: SciSymbioLens-Bridging-Header.h
// Enables Swift code to call Objective-C VsdkPlugin methods
//

#ifndef VeepaAudioTest_Bridging_Header_h
#define VeepaAudioTest_Bridging_Header_h

// Import Veepa SDK plugin headers
#import "VsdkPlugin.h"
#import "AppP2PApiPlugin.h"
#import "AppPlayerPlugin.h"

#endif /* VeepaAudioTest_Bridging_Header_h */
```

#### Step 1.3.3: Create Info.plist (10 min)

**Adapt from**: `SciSymbioLens/ios/SciSymbioLens/SciSymbioLens/Resources/Info.plist`

Key adaptations:
- Keep: Microphone, local network permissions
- Remove: Camera, speech recognition, location, Supabase config

Create `ios/VeepaAudioTest/VeepaAudioTest/Resources/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<!--
ADAPTED FROM: SciSymbioLens Info.plist
Changes: Removed camera, location, Supabase keys - kept only audio/network permissions
-->
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
    <string>$(MARKETING_VERSION)</string>
    <key>CFBundleVersion</key>
    <string>$(CURRENT_PROJECT_VERSION)</string>

    <key>LSRequiresIPhoneOS</key>
    <true/>

    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <false/>
    </dict>

    <key>UILaunchScreen</key>
    <dict/>

    <!-- ADAPTED: Microphone permission for audio streaming -->
    <key>NSMicrophoneUsageDescription</key>
    <string>VeepaAudioTest needs microphone access to test audio streaming from the camera.</string>

    <!-- ADAPTED: Local network permission for P2P camera discovery -->
    <key>NSLocalNetworkUsageDescription</key>
    <string>VeepaAudioTest needs local network access to connect to your Veepa camera via P2P.</string>

    <!-- ADAPTED: Allow local networking and arbitrary loads for P2P connections -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>

    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
</dict>
</plist>
```

---

### ✅ Sub-Story 1.3 Complete Verification

```bash
# 1. project.yml syntax valid
cd ios/VeepaAudioTest
python3 -c "import yaml; yaml.safe_load(open('project.yml'))"
# ✅ Expected: No errors

# 2. Bridging header exists
cat VeepaAudioTest/App/VeepaAudioTest-Bridging-Header.h
# ✅ Expected: See #import statements

# 3. Info.plist valid XML
plutil -lint VeepaAudioTest/Resources/Info.plist
# ✅ Expected: "OK"

# 4. Required permissions present
grep "NSMicrophoneUsageDescription" VeepaAudioTest/Resources/Info.plist
grep "NSLocalNetworkUsageDescription" VeepaAudioTest/Resources/Info.plist
# ✅ Expected: Both found
```

**Acceptance Criteria:**
- [ ] project.yml created with correct framework dependencies
- [ ] Bridging header created with VsdkPlugin imports
- [ ] Info.plist has microphone and local network permissions
- [ ] YAML syntax validates
- [ ] Info.plist XML validates

---

## 🔧 Sub-Story 1.4: Create Build Scripts

**Goal**: Create sync script to copy Flutter frameworks from build output to Xcode project

⏱️ **Estimated Time**: 15-20 minutes

### Analysis of Source Code

From `SciSymbioLens/ios/SciSymbioLens/Scripts/sync-flutter-frameworks.sh` (69 lines):

**Key patterns discovered**:
- Lines 19-21: Path calculations using SRCROOT environment variable
- Lines 32-36: Checks if build output exists before syncing
- Lines 40-45: Syncs App.xcframework (contains Dart code)
- Lines 48-52: Syncs FlutterPluginRegistrant.xcframework
- Lines 55-60: Syncs plugin-specific frameworks (network_info_plus, shared_preferences_foundation)
- Lines 63-66: Syncs Flutter.xcframework (engine)

**What to adapt:**
- ✅ Keep: Core sync logic for App.xcframework, FlutterPluginRegistrant, Flutter.xcframework
- ✏️ Adapt: Change module path from veepa_camera → veepa_audio
- ❌ Remove: Plugin-specific sync (network_info_plus, shared_preferences_foundation) - we don't use these packages
- ✅ Keep: Error handling (exit 0 if no build output)

### Implementation Steps

#### Step 1.4.1: Create Scripts Directory (2 min)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest
mkdir -p Scripts
```

**✅ Verification:**
```bash
ls -la Scripts/
# Expected: Empty directory created
```

#### Step 1.4.2: Create Sync Script (10 min)

**Adapt from**: `SciSymbioLens/ios/SciSymbioLens/Scripts/sync-flutter-frameworks.sh`

Create `ios/VeepaAudioTest/Scripts/sync-flutter-frameworks.sh`:

```bash
#!/bin/bash

# ADAPTED FROM: SciSymbioLens/Scripts/sync-flutter-frameworks.sh
# Changes: Updated module name (veepa_camera → veepa_audio), removed plugin syncs
#
# sync-flutter-frameworks.sh
# This script syncs Flutter frameworks from the Flutter module build output
# to the iOS project's Flutter folder before each Xcode build.
#
# Why is this needed?
# - Flutter compiles Dart code into native frameworks (App.xcframework)
# - The build output goes to: flutter_module/veepa_audio/build/ios/framework/
# - Xcode looks for frameworks in: ios/VeepaAudioTest/Flutter/
# - Without syncing, Xcode would use stale compiled code
#
# This script runs as a pre-build phase, ensuring Xcode always uses
# the latest Flutter code.

set -e

# Paths (ADAPTED: veepa_camera → veepa_audio)
FLUTTER_MODULE_DIR="${SRCROOT}/../../flutter_module/veepa_audio"
FLUTTER_BUILD_OUTPUT="${FLUTTER_MODULE_DIR}/build/ios/framework"
IOS_FLUTTER_DIR="${SRCROOT}/Flutter"

# Determine build configuration (Debug, Release, Profile)
BUILD_CONFIG="${CONFIGURATION:-Debug}"

echo "=== Flutter Framework Sync (VeepaAudioTest) ==="
echo "Build config: ${BUILD_CONFIG}"
echo "Source: ${FLUTTER_BUILD_OUTPUT}/${BUILD_CONFIG}"
echo "Destination: ${IOS_FLUTTER_DIR}/${BUILD_CONFIG}"

# Check if Flutter build output exists
if [ ! -d "${FLUTTER_BUILD_OUTPUT}/${BUILD_CONFIG}" ]; then
    echo "Warning: Flutter build output not found at ${FLUTTER_BUILD_OUTPUT}/${BUILD_CONFIG}"
    echo "Run 'flutter build ios-framework' in the Flutter module first."
    echo "Skipping sync - using existing frameworks."
    exit 0
fi

# Sync App.xcframework (contains our Dart code - most important)
if [ -d "${FLUTTER_BUILD_OUTPUT}/${BUILD_CONFIG}/App.xcframework" ]; then
    echo "Syncing App.xcframework..."
    rsync -av --delete "${FLUTTER_BUILD_OUTPUT}/${BUILD_CONFIG}/App.xcframework/" "${IOS_FLUTTER_DIR}/${BUILD_CONFIG}/App.xcframework/"
    echo "App.xcframework synced successfully"
else
    echo "Warning: App.xcframework not found in build output"
fi

# Sync FlutterPluginRegistrant.xcframework (plugin registrations)
if [ -d "${FLUTTER_BUILD_OUTPUT}/${BUILD_CONFIG}/FlutterPluginRegistrant.xcframework" ]; then
    echo "Syncing FlutterPluginRegistrant.xcframework..."
    rsync -av --delete "${FLUTTER_BUILD_OUTPUT}/${BUILD_CONFIG}/FlutterPluginRegistrant.xcframework/" "${IOS_FLUTTER_DIR}/${BUILD_CONFIG}/FlutterPluginRegistrant.xcframework/"
fi

# ADAPTED: Removed plugin-specific syncs (network_info_plus, shared_preferences_foundation)
# VeepaAudioTest has minimal dependencies

# Flutter.xcframework is the engine - rarely changes, but sync it too
if [ -d "${FLUTTER_BUILD_OUTPUT}/${BUILD_CONFIG}/Flutter.xcframework" ]; then
    echo "Syncing Flutter.xcframework..."
    rsync -av --delete "${FLUTTER_BUILD_OUTPUT}/${BUILD_CONFIG}/Flutter.xcframework/" "${IOS_FLUTTER_DIR}/${BUILD_CONFIG}/Flutter.xcframework/"
fi

echo "=== Flutter Framework Sync Complete ==="
```

#### Step 1.4.3: Make Script Executable (1 min)

```bash
chmod +x Scripts/sync-flutter-frameworks.sh
```

**✅ Verification:**
```bash
ls -l Scripts/sync-flutter-frameworks.sh
# Expected: -rwxr-xr-x (executable bit set)
```

#### Step 1.4.4: Test Script Execution (5 min)

```bash
# Set environment variables the script expects
export SRCROOT="$(pwd)"
export CONFIGURATION="Debug"

# Run script (should warn that Flutter build output doesn't exist yet - that's expected)
bash Scripts/sync-flutter-frameworks.sh
```

**✅ Expected output:**
```
=== Flutter Framework Sync (VeepaAudioTest) ===
Build config: Debug
Source: /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio/build/ios/framework/Debug
Destination: /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest/Flutter/Debug
Warning: Flutter build output not found at /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio/build/ios/framework/Debug
Run 'flutter build ios-framework' in the Flutter module first.
Skipping sync - using existing frameworks.
```

This is correct! The script detects that Flutter frameworks haven't been built yet and exits gracefully.

---

### ✅ Sub-Story 1.4 Complete Verification

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest

# 1. Script exists and is executable
test -x Scripts/sync-flutter-frameworks.sh && echo "✅ Script is executable"

# 2. Script contains correct module path
grep "veepa_audio" Scripts/sync-flutter-frameworks.sh
# ✅ Expected: See "veepa_audio" (not "veepa_camera")

# 3. Script runs without errors (even though no frameworks exist yet)
SRCROOT="$(pwd)" CONFIGURATION="Debug" bash Scripts/sync-flutter-frameworks.sh
# ✅ Expected: Warning message, exit 0
```

**Acceptance Criteria:**
- [ ] Scripts directory created
- [ ] sync-flutter-frameworks.sh created with adapted paths
- [ ] Script is executable (chmod +x)
- [ ] Script references veepa_audio (not veepa_camera)
- [ ] Script runs without errors (exits gracefully if no build output)
- [ ] Plugin-specific syncs removed (network_info_plus, shared_preferences)

---

## 🔧 Sub-Story 1.5: Create iOS App Entry Point

**Goal**: Create minimal SwiftUI app structure to launch the project

⏱️ **Estimated Time**: 10-15 minutes

### Analysis of Source Code

From `SciSymbioLens/ios/SciSymbioLens/SciSymbioLens/App/SciSymbioLensApp.swift` (14 lines):

**Key patterns discovered**:
- Lines 1: SwiftUI import
- Lines 4-5: @main struct with App protocol
- Line 6: @UIApplicationDelegateAdaptor for Flutter engine initialization
- Lines 8-12: WindowGroup with ContentView

**What to adapt:**
- ✅ Keep: Basic SwiftUI App structure
- ✅ Keep: UIApplicationDelegateAdaptor pattern (we'll need AppDelegate for Flutter)
- ✏️ Adapt: Change struct name to VeepaAudioTestApp
- ✏️ Adapt: Change ContentView to simple placeholder (will be enhanced in Story 3)

### Implementation Steps

#### Step 1.5.1: Create App Directory (2 min)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest/VeepaAudioTest
mkdir -p App
```

**✅ Verification:**
```bash
ls -la App/
# Expected: Empty directory created
```

#### Step 1.5.2: Create Main App Entry Point (5 min)

**Adapt from**: `SciSymbioLens/App/SciSymbioLensApp.swift`

Create `ios/VeepaAudioTest/VeepaAudioTest/App/VeepaAudioTestApp.swift`:

```swift
// ADAPTED FROM: SciSymbioLens/App/SciSymbioLensApp.swift
// Changes: Simplified for audio-only testing, renamed to VeepaAudioTestApp
//
import SwiftUI

@main
struct VeepaAudioTestApp: App {
    // AppDelegate will handle Flutter engine initialization
    // (Will be implemented in Story 2)
    // @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**Note**: The @UIApplicationDelegateAdaptor line is commented out because we haven't created AppDelegate yet. It will be added in Story 2 when we integrate Flutter.

#### Step 1.5.3: Create Placeholder ContentView (5 min)

Create `ios/VeepaAudioTest/VeepaAudioTest/App/ContentView.swift`:

```swift
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
```

---

### ✅ Sub-Story 1.5 Complete Verification

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest/VeepaAudioTest

# 1. App directory exists
test -d App && echo "✅ App directory exists"

# 2. VeepaAudioTestApp.swift exists
test -f App/VeepaAudioTestApp.swift && echo "✅ Main app file exists"

# 3. ContentView.swift exists
test -f App/ContentView.swift && echo "✅ ContentView exists"

# 4. Files contain correct struct names
grep "struct VeepaAudioTestApp" App/VeepaAudioTestApp.swift
grep "struct ContentView" App/ContentView.swift
# ✅ Expected: Both structs found
```

**Acceptance Criteria:**
- [ ] App directory created
- [ ] VeepaAudioTestApp.swift created with @main attribute
- [ ] ContentView.swift created with placeholder UI
- [ ] App compiles (will verify in Sub-Story 1.6)

---

## 🔧 Sub-Story 1.6: Verify Complete Build Pipeline

**Goal**: Test entire build pipeline end-to-end (Flutter → sync → Xcode → app launch)

⏱️ **Estimated Time**: 15-20 minutes

### What We're Testing

This sub-story verifies the **complete build pipeline** works:

1. ✅ Flutter module builds → App.xcframework created
2. ✅ Frameworks sync to iOS project
3. ✅ XcodeGen generates .xcodeproj
4. ✅ iOS app compiles
5. ✅ App launches on simulator

**Why This Matters**: If any step fails, the entire project is broken. This is the most critical verification.

### Implementation Steps

#### Step 1.6.1: Build Flutter Frameworks (5 min)

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

#### Step 1.6.2: Sync Frameworks to iOS Project (2 min)

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

#### Step 1.6.3: Generate Xcode Project (2 min)

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

#### Step 1.6.4: Build iOS App (5 min)

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

#### Step 1.6.5: Launch App on Simulator (3 min)

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

### ✅ Sub-Story 1.6 Complete Verification (ALL TESTS)

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

## 🎯 Story 1 Final Acceptance Criteria

**Check off each item before proceeding to Story 2:**

### Flutter Module
- [ ] Flutter module created at `flutter_module/veepa_audio/`
- [ ] pubspec.yaml has ffi: ^2.0.1 dependency
- [ ] lib/main.dart implements method channel handler
- [ ] ios/.symlinks/plugins/vsdk/ directory structure created
- [ ] `flutter pub get` succeeds
- [ ] `flutter analyze` shows no issues
- [ ] `flutter build ios-framework` succeeds
- [ ] App.xcframework created in build/ios/framework/

### iOS Project Structure
- [ ] XcodeGen project.yml created with all required frameworks
- [ ] Bridging header created with VsdkPlugin imports
- [ ] Info.plist created with microphone + network permissions
- [ ] sync-flutter-frameworks.sh script created and executable
- [ ] VeepaAudioTestApp.swift created with @main attribute
- [ ] ContentView.swift created with placeholder UI
- [ ] Scripts/sync-flutter-frameworks.sh runs without errors

### Build Pipeline
- [ ] Frameworks sync from Flutter build to iOS project
- [ ] `xcodegen generate` creates .xcodeproj
- [ ] Xcode project compiles without errors
- [ ] App launches on iOS Simulator
- [ ] Placeholder UI displays correctly

### Documentation
- [ ] All code includes adaptation comments (ADAPTED FROM)
- [ ] Sub-story verification steps documented
- [ ] All acceptance criteria met

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

**Next Step:** Proceed to [STORY-2-ENHANCED.md](STORY-2-ENHANCED.md) for P2P SDK integration.

---

**Story 1 Created**: 2026-02-02
**Based on Analysis**: DEEP_CODE_ANALYSIS.md (4,000+ lines analyzed)
**Source Code**: SciSymbioLens codebase

(Due to length, continuing in next response)