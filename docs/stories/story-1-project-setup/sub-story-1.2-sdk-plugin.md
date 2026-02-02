# Sub-Story 1.2: Copy P2P SDK Plugin Structure

**Goal**: Copy the vsdk plugin structure from SciSymbioLens (but NOT the binary yet - that comes in Story 2)

**Estimated Time**: 15-20 minutes

---

## 📋 Analysis of Source Code

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

---

## 🛠️ Implementation Steps

### Step 1.2.1: Copy Plugin Source Files (10 min)

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

---

### Step 1.2.2: Create Podspec (5 min)

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

## ✅ Sub-Story 1.2 Complete Verification

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

---

## 🎯 Acceptance Criteria

- [ ] VsdkPlugin header and implementation copied
- [ ] AppP2PApiPlugin header copied
- [ ] AppPlayerPlugin header copied
- [ ] vsdk.podspec created with correct frameworks/libraries
- [ ] Podspec validates (with warnings OK)

---

## 🔗 Navigation

- ← Previous: [Sub-Story 1.1: Flutter Module](sub-story-1.1-flutter-module.md)
- → Next: [Sub-Story 1.3: XcodeGen Config](sub-story-1.3-xcodegen-config.md)
- ↑ Story Overview: [README.md](README.md)
