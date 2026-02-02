# Sub-Story 1.3: Create XcodeGen Configuration

**Goal**: Create project.yml that generates a working Xcode project, adapted from SciSymbioLens

**Estimated Time**: 30-40 minutes

---

## 📋 Analysis of Source Code

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

---

## 🛠️ Implementation Steps

### Step 1.3.1: Create Base Configuration (15 min)

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

---

### Step 1.3.2: Create Bridging Header (5 min)

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

---

### Step 1.3.3: Create Info.plist (10 min)

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

## ✅ Sub-Story 1.3 Complete Verification

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

---

## 🎯 Acceptance Criteria

- [ ] project.yml created with correct framework dependencies
- [ ] Bridging header created with VsdkPlugin imports
- [ ] Info.plist has microphone and local network permissions
- [ ] YAML syntax validates
- [ ] Info.plist XML validates

---

## 🔗 Navigation

- ← Previous: [Sub-Story 1.2: SDK Plugin](sub-story-1.2-sdk-plugin.md)
- → Next: [Sub-Story 1.4: Build Scripts](sub-story-1.4-build-scripts.md)
- ↑ Story Overview: [README.md](README.md)
