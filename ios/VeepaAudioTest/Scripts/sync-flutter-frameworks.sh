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

# Note: No 'set -e' to allow graceful handling of missing frameworks

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

# Ensure destination directory exists
mkdir -p "${IOS_FLUTTER_DIR}/${BUILD_CONFIG}"

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
    mkdir -p "${IOS_FLUTTER_DIR}/${BUILD_CONFIG}/App.xcframework"
    rsync -av --delete "${FLUTTER_BUILD_OUTPUT}/${BUILD_CONFIG}/App.xcframework/" "${IOS_FLUTTER_DIR}/${BUILD_CONFIG}/App.xcframework/" || echo "Warning: Failed to sync App.xcframework"
    echo "App.xcframework synced successfully"
else
    echo "Warning: App.xcframework not found in build output"
fi

# Sync FlutterPluginRegistrant.xcframework (plugin registrations)
if [ -d "${FLUTTER_BUILD_OUTPUT}/${BUILD_CONFIG}/FlutterPluginRegistrant.xcframework" ]; then
    echo "Syncing FlutterPluginRegistrant.xcframework..."
    mkdir -p "${IOS_FLUTTER_DIR}/${BUILD_CONFIG}/FlutterPluginRegistrant.xcframework"
    rsync -av --delete "${FLUTTER_BUILD_OUTPUT}/${BUILD_CONFIG}/FlutterPluginRegistrant.xcframework/" "${IOS_FLUTTER_DIR}/${BUILD_CONFIG}/FlutterPluginRegistrant.xcframework/" || echo "Warning: Failed to sync FlutterPluginRegistrant.xcframework"
fi

# ADAPTED: Removed plugin-specific syncs (network_info_plus, shared_preferences_foundation)
# VeepaAudioTest has minimal dependencies

# Flutter.xcframework is the engine - rarely changes, but sync it too
if [ -d "${FLUTTER_BUILD_OUTPUT}/${BUILD_CONFIG}/Flutter.xcframework" ]; then
    echo "Syncing Flutter.xcframework..."
    mkdir -p "${IOS_FLUTTER_DIR}/${BUILD_CONFIG}/Flutter.xcframework"
    rsync -av --delete "${FLUTTER_BUILD_OUTPUT}/${BUILD_CONFIG}/Flutter.xcframework/" "${IOS_FLUTTER_DIR}/${BUILD_CONFIG}/Flutter.xcframework/" || echo "Warning: Failed to sync Flutter.xcframework"
fi

echo "=== Flutter Framework Sync Complete ==="
