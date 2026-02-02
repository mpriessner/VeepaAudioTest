# Sub-Story 1.4: Create Build Scripts

**Goal**: Create sync script to copy Flutter frameworks from build output to Xcode project

**Estimated Time**: 15-20 minutes

---

## 📋 Analysis of Source Code

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

---

## 🛠️ Implementation Steps

### Step 1.4.1: Create Scripts Directory (2 min)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest
mkdir -p Scripts
```

**✅ Verification:**
```bash
ls -la Scripts/
# Expected: Empty directory created
```

---

### Step 1.4.2: Create Sync Script (10 min)

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

---

### Step 1.4.3: Make Script Executable (1 min)

```bash
chmod +x Scripts/sync-flutter-frameworks.sh
```

**✅ Verification:**
```bash
ls -l Scripts/sync-flutter-frameworks.sh
# Expected: -rwxr-xr-x (executable bit set)
```

---

### Step 1.4.4: Test Script Execution (5 min)

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

## ✅ Sub-Story 1.4 Complete Verification

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

---

## 🎯 Acceptance Criteria

- [ ] Scripts directory created
- [ ] sync-flutter-frameworks.sh created with adapted paths
- [ ] Script is executable (chmod +x)
- [ ] Script references veepa_audio (not veepa_camera)
- [ ] Script runs without errors (exits gracefully if no build output)
- [ ] Plugin-specific syncs removed (network_info_plus, shared_preferences)

---

## 🔗 Navigation

- ← Previous: [Sub-Story 1.3: XcodeGen Config](sub-story-1.3-xcodegen-config.md)
- → Next: [Sub-Story 1.5: iOS App Entry](sub-story-1.5-ios-app-entry.md)
- ↑ Story Overview: [README.md](README.md)
