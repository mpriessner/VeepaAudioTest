# Story 1: Project Setup and Initial Structure

**Epic**: VeepaAudioTest - Minimal Audio Testing App
**Total Estimated Time**: 1.5-2 hours
**Status**: 🚧 In Progress

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

## 📊 Sub-Stories

Work through these sequentially. Each sub-story is a separate file with detailed instructions.

### ✅ Sub-Story 1.1: Flutter Module Structure
⏱️ **20-25 minutes** | 📄 [sub-story-1.1-flutter-module.md](sub-story-1.1-flutter-module.md)

Create minimal Flutter module with correct directory layout for P2P SDK plugin.

**Acceptance Criteria:**
- [ ] Flutter module created at `flutter_module/veepa_audio/`
- [ ] pubspec.yaml has ffi: ^2.0.1 dependency
- [ ] lib/main.dart placeholder created
- [ ] ios/.symlinks/plugins/vsdk/ structure created
- [ ] `flutter pub get` succeeds
- [ ] `flutter analyze` shows no issues

---

### ✅ Sub-Story 1.2: Copy P2P SDK Plugin Structure
⏱️ **15-20 minutes** | 📄 [sub-story-1.2-sdk-plugin.md](sub-story-1.2-sdk-plugin.md)

Copy vsdk plugin directory structure from SciSymbioLens (without the binary yet).

**Acceptance Criteria:**
- [ ] Plugin directory structure created
- [ ] Plugin pubspec.yaml created
- [ ] Plugin podspec template created
- [ ] Directory structure matches SciSymbioLens pattern

---

### ✅ Sub-Story 1.3: Create XcodeGen Configuration
⏱️ **30-40 minutes** | 📄 [sub-story-1.3-xcodegen-config.md](sub-story-1.3-xcodegen-config.md)

Adapt project.yml from SciSymbioLens with only essential dependencies.

**Acceptance Criteria:**
- [ ] project.yml created with framework dependencies
- [ ] Bridging header created with VsdkPlugin imports
- [ ] Info.plist has microphone + network permissions
- [ ] YAML syntax validates
- [ ] Info.plist XML validates

---

### ✅ Sub-Story 1.4: Create Build Scripts
⏱️ **15-20 minutes** | 📄 [sub-story-1.4-build-scripts.md](sub-story-1.4-build-scripts.md)

Adapt sync-flutter-frameworks.sh script for VeepaAudioTest.

**Acceptance Criteria:**
- [ ] Scripts directory created
- [ ] sync-flutter-frameworks.sh created
- [ ] Script is executable (chmod +x)
- [ ] Script references veepa_audio (not veepa_camera)
- [ ] Script runs without errors
- [ ] Plugin-specific syncs removed

---

### ✅ Sub-Story 1.5: Create iOS App Entry Point
⏱️ **10-15 minutes** | 📄 [sub-story-1.5-ios-app-entry.md](sub-story-1.5-ios-app-entry.md)

Create minimal SwiftUI app structure.

**Acceptance Criteria:**
- [ ] App directory created
- [ ] VeepaAudioTestApp.swift created with @main
- [ ] ContentView.swift created with placeholder UI
- [ ] Files contain correct struct names

---

### ✅ Sub-Story 1.6: Verify Complete Build Pipeline
⏱️ **15-20 minutes** | 📄 [sub-story-1.6-verify-pipeline.md](sub-story-1.6-verify-pipeline.md)

Test entire build pipeline end-to-end.

**Acceptance Criteria:**
- [ ] Flutter frameworks build successfully
- [ ] Frameworks sync to iOS project
- [ ] `xcodegen generate` creates .xcodeproj
- [ ] Xcode project compiles without errors
- [ ] App launches on iOS Simulator
- [ ] Placeholder UI displays correctly

---

## 🎯 Story 1 Complete Checklist

**Check all before proceeding to Story 2:**

### Flutter Module
- [ ] Module created and dependencies installed
- [ ] Flutter analyze passes
- [ ] Plugin structure in place

### iOS Project
- [ ] XcodeGen configuration valid
- [ ] Bridging header and Info.plist created
- [ ] Build scripts executable

### Build Pipeline
- [ ] End-to-end build succeeds
- [ ] App launches on simulator
- [ ] All 6 sub-stories completed

---

## 🎉 Story 1 Deliverables

Once complete, you will have:
- ✅ Working Flutter module with method channel structure
- ✅ iOS project with XcodeGen configuration
- ✅ Build scripts for framework synchronization
- ✅ App that compiles and launches with placeholder UI
- ✅ Project structure ready for SDK integration

**Next**: Proceed to [Story 2: SDK Integration](../story-2-sdk-integration/README.md)

---

**Created**: 2026-02-02
**Based on**: DEEP_CODE_ANALYSIS.md (4,000+ lines analyzed)
**Source**: SciSymbioLens codebase
