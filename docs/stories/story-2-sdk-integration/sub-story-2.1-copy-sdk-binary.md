# Sub-Story 2.1: Copy P2P SDK Binary and Plugin

**Goal**: Copy libVSTC.a and VsdkPlugin from SciSymbioLens to VeepaAudioTest

**Estimated Time**: 15-20 minutes

---

## 📋 Analysis of Source Code

From `SciSymbioLens/flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk/ios/`:

**Directory structure discovered**:
```
vsdk/ios/
├── Classes/
│   ├── VsdkPlugin.h          # Main plugin header (16 lines)
│   ├── VsdkPlugin.m          # Plugin registration (48 lines)
│   ├── AppP2PApiPlugin.h     # P2P API declarations (203 lines)
│   ├── AppPlayerPlugin.h     # Player API declarations (150 lines)
│   └── libVSTC.a             # Binary SDK (45MB, arm64 only)
└── vsdk.podspec              # Pod specification (23 lines)
```

**Critical details**:
- libVSTC.a is **45MB** static library
- Architecture: **arm64 only** (no simulator support - will fail on Intel Macs/simulators)
- Plugin uses **Objective-C** (not Swift) for C interop
- Headers define C function prototypes for FFI

**What to adapt:**
- ✅ Copy all headers exactly - cannot modify C function signatures
- ✅ Copy libVSTC.a exactly - binary cannot be modified
- ✏️ Adapt vsdk.podspec - update paths and dependencies

---

## 🛠️ Implementation Steps

### Step 2.1.1: Create Plugin Directory Structure (3 min)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio

# Create plugin structure
mkdir -p ios/.symlinks/plugins/vsdk/ios/Classes
```

**✅ Verification:**
```bash
ls -la ios/.symlinks/plugins/vsdk/ios/
# Expected: Classes/ directory created
```

---

### Step 2.1.2: Copy Plugin Headers and Binary (5 min)

**Copy from**: `SciSymbioLens/flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk/ios/Classes/`

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio

# Copy all plugin files
cp /Users/mpriessner/windsurf_repos/SciSymbioLens/flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk/ios/Classes/VsdkPlugin.h \
   ios/.symlinks/plugins/vsdk/ios/Classes/

cp /Users/mpriessner/windsurf_repos/SciSymbioLens/flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk/ios/Classes/VsdkPlugin.m \
   ios/.symlinks/plugins/vsdk/ios/Classes/

cp /Users/mpriessner/windsurf_repos/SciSymbioLens/flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk/ios/Classes/AppP2PApiPlugin.h \
   ios/.symlinks/plugins/vsdk/ios/Classes/

cp /Users/mpriessner/windsurf_repos/SciSymbioLens/flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk/ios/Classes/AppPlayerPlugin.h \
   ios/.symlinks/plugins/vsdk/ios/Classes/

# Copy binary SDK (45MB - may take 10-15 seconds)
echo "Copying libVSTC.a (45MB)..."
cp /Users/mpriessner/windsurf_repos/SciSymbioLens/flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk/ios/Classes/libVSTC.a \
   ios/.symlinks/plugins/vsdk/ios/Classes/

echo "✅ Plugin files copied"
```

**✅ Verification:**
```bash
cd ios/.symlinks/plugins/vsdk/ios/Classes

# Verify all files present
ls -lh
# Expected:
# VsdkPlugin.h         (~1KB)
# VsdkPlugin.m         (~2KB)
# AppP2PApiPlugin.h    (~8KB)
# AppPlayerPlugin.h    (~6KB)
# libVSTC.a            (45MB)

# Verify binary is correct architecture
lipo -info libVSTC.a
# Expected: "Non-fat file: libVSTC.a is architecture: arm64"
```

---

### Step 2.1.3: Create Adapted Podspec (7 min)

**Adapt from**: `SciSymbioLens/flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk/ios/vsdk.podspec`

Create `flutter_module/veepa_audio/ios/.symlinks/plugins/vsdk/ios/vsdk.podspec`:

```ruby
# ADAPTED FROM: SciSymbioLens vsdk.podspec
# Changes: Minimal - just package metadata updates
#
Pod::Spec.new do |s|
  s.name             = 'vsdk'
  s.version          = '0.0.1'
  s.summary          = 'Veepa P2P SDK Flutter plugin'
  s.description      = <<-DESC
Flutter plugin wrapping the Veepa P2P SDK (libVSTC.a) for camera communication.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Veepa' => 'sdk@veepa.com' }
  s.source           = { :path => '.' }

  # Source files
  s.source_files = 'Classes/**/*'

  # Public headers
  s.public_header_files = 'Classes/**/*.h'

  # Platform requirements
  s.platform = :ios, '12.0'

  # Link the static library
  s.vendored_libraries = 'Classes/libVSTC.a'

  # System frameworks required by libVSTC.a
  s.frameworks = [
    'AVFoundation',      # Audio/video capture
    'AudioToolbox',      # Audio processing (CRITICAL for audio)
    'VideoToolbox',      # Video decoding (SDK may still use internally)
    'CoreMedia',         # Media pipeline
    'CoreVideo'          # Video buffers
  ]

  # System libraries required by libVSTC.a
  s.libraries = [
    'z',                 # Compression
    'c++',               # C++ standard library
    'iconv',             # Character encoding
    'bz2'                # Compression
  ]

  # Dependencies
  s.dependency 'Flutter'
end
```

**✅ Verification:**
```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio

# Verify podspec syntax (requires CocoaPods)
pod spec lint ios/.symlinks/plugins/vsdk/ios/vsdk.podspec --allow-warnings
# Expected: "vsdk.podspec passed validation."
# (Warnings about source being :path are OK)
```

---

## ✅ Sub-Story 2.1 Complete Verification

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio/ios/.symlinks/plugins/vsdk/ios

# 1. All plugin files present
test -f Classes/VsdkPlugin.h && echo "✅ VsdkPlugin.h"
test -f Classes/VsdkPlugin.m && echo "✅ VsdkPlugin.m"
test -f Classes/AppP2PApiPlugin.h && echo "✅ AppP2PApiPlugin.h"
test -f Classes/AppPlayerPlugin.h && echo "✅ AppPlayerPlugin.h"
test -f Classes/libVSTC.a && echo "✅ libVSTC.a"

# 2. Binary is correct size and architecture
LIBSIZE=$(stat -f%z Classes/libVSTC.a)
if [ $LIBSIZE -gt 40000000 ]; then
  echo "✅ libVSTC.a size: $LIBSIZE bytes (correct)"
else
  echo "❌ libVSTC.a size: $LIBSIZE bytes (too small - copy failed?)"
fi

lipo -info Classes/libVSTC.a
# Expected: arm64 architecture

# 3. Podspec exists
test -f vsdk.podspec && echo "✅ vsdk.podspec"
```

---

## 🎯 Acceptance Criteria

- [ ] Plugin directory structure created
- [ ] VsdkPlugin.h and .m copied
- [ ] AppP2PApiPlugin.h and AppPlayerPlugin.h copied
- [ ] libVSTC.a copied (45MB)
- [ ] Binary is arm64 architecture
- [ ] vsdk.podspec created with correct dependencies
- [ ] Podspec validates (if CocoaPods installed)

---

## 🔗 Navigation

- → Next: [Sub-Story 2.2: Dart Bindings](sub-story-2.2-dart-bindings.md)
- ↑ Story Overview: [README.md](README.md)
- ← Previous Story: [Story 1: Project Setup](../story-1-project-setup/README.md)
