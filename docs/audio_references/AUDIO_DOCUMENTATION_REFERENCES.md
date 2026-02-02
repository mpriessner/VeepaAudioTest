# Audio Documentation References

**Purpose**: List of official documentation files that contain audio-related information for the Veepa camera SDK

**Created**: 2026-02-02
**For**: Coding agent to investigate audio transmission capabilities

---

## 🎯 PRIMARY AUDIO REFERENCES

These files contain direct references to audio streaming, codec information, or P2P audio APIs:

### 1. **flutter sdk参数使用说明.pdf** (Flutter SDK Parameter Usage Instructions)
**Path**: `/Users/mpriessner/windsurf_repos/SciSymbioLens/docs/official_documentation/flutter sdk参数使用说明.pdf`
**Size**: 330K
**Markdown Version**: `flutter_sdk_parameter_usage_instructions.md`

**Contains**:
- P2P SDK usage instructions
- Device connection process
- Video/audio streaming setup
- `AppPlayerController` API (used for audio playback)

**Why Important**:
- Official SDK documentation
- May contain P2P audio API details
- Describes how to use the SDK for streaming

**Key Search Terms**: Look for `audio`, `voice`, `startVoice`, `stopVoice`, `audioRate`, `P2P_AUDIO_CHANNEL`

---

### 2. **C系列cgi命令手册_v12_20231223.pdf** (C Series CGI Command Manual v12)
**Path**: `/Users/mpriessner/windsurf_repos/SciSymbioLens/docs/official_documentation/C系列cgi命令手册_v12_20231223.pdf`
**Size**: 902K
**Markdown Version**: `CGI_COMMAND_MANUAL.md` (partial translation)
**English Translation**: `CGI_COMMAND_MANUAL_v12_20231223.md`

**Contains**:
- **`audiostream.cgi`** - Request audio stream communication (mentioned on page 29)
- CGI commands for camera control
- Audio/video-related CGI section (Section II)

**Why Important**:
- Contains `audiostream.cgi` command
- May have audio codec specifications
- May have audio parameters and configuration options

**Key Search Terms**: Look for `audiostream.cgi`, `audio_enable`, `audio_format`, `codec`, `G.711`, `ADPCM`, `sample_rate`

---

### 3. **CGI Documentation0125.pdf**
**Path**: `/Users/mpriessner/windsurf_repos/SciSymbioLens/docs/official_documentation/CGI Documentation0125.pdf`
**Size**: 202K
**Markdown Versions**:
- `CGI Documentation0125.md`
- `CGI_Documentation.md`

**Contains**:
- Extended CGI command documentation
- May have more details on audio stream parameters

**Why Important**: Alternate/updated version of CGI manual

---

### 4. **功能指令文档0125.pdf** (Function Command Document)
**Path**: `/Users/mpriessner/windsurf_repos/SciSymbioLens/docs/official_documentation/02_功能指令文档0125.pdf`
**Size**: 1.4M (largest file - likely most comprehensive)
**English Version**: `Function_Command_Document_0125.md`

**Contains**:
- References to "voice" commands (found in grep results)
- Alarm sound settings
- TF card sound recording switch
- Custom voice alarm settings (cmd=2135)

**Why Important**:
- Largest documentation file
- Contains voice/sound-related commands
- May have comprehensive audio API documentation

**Key Search Terms**: Look for audio streaming APIs, codec settings, sample rates

---

## 🔍 SECONDARY REFERENCES (May Contain Audio Info)

### 5. **CAMERA_APP_DEVELOPMENT_GUIDE.md**
**Path**: `/Users/mpriessner/windsurf_repos/SciSymbioLens/docs/official_documentation/CAMERA_APP_DEVELOPMENT_GUIDE.md`

**Found References**:
- Line 188: "Recommended Codec: H.264 (best compatibility)"
- Line 291: "Audio Levels: Visual audio level meter"
- Line 409: `NSMicrophoneUsageDescription` - iOS permission
- Line 434: `RECORD_AUDIO` - Android permission
- Line 646-651: Audio codec specifications:
  - Audio Codec: AAC
  - Audio Bitrate: 128 kbps
  - Sample Rate: 48 kHz

**Why Important**: Shows general audio expectations for camera apps (but this is for local recording, not P2P streaming)

---

### 6. **GRANT_APPLICATION_TECHNICAL_DOCUMENT.md**
**Path**: `/Users/mpriessner/windsurf_repos/SciSymbioLens/docs/official_documentation/GRANT_APPLICATION_TECHNICAL_DOCUMENT.md`

**Contains**: Audio/microphone permission references

---

## 📄 DOCUMENTS WITHOUT AUDIO REFERENCES

These files were searched but contain no audio-related information:

- `01_Cloud_Video_API_Documentation.md` - Cloud API only
- `03_Open_Platform_API_Documentation.md` - Platform API, no audio
- `04_Alarm_Function_Development_Documentation.md` - Alarms only
- `05_Device_Alarm_Reception_Integration_Process.md` - Alarm reception
- `cloud_info.md` - Cloud service info
- `veepai_device_adding_and_usage_process.md` - Device pairing process

---

## 🎯 RECOMMENDED INVESTIGATION ORDER

For your coding agent, investigate in this order:

### **Priority 1: SDK Documentation**
1. **`flutter sdk参数使用说明.pdf`** or **`flutter_sdk_parameter_usage_instructions.md`**
   - Most likely to contain P2P audio API documentation
   - Look for: `AppPlayerController`, `startVoice()`, `stopVoice()`, `audioRate`, audio channel configuration

### **Priority 2: CGI Audio Commands**
2. **`C系列cgi命令手册_v12_20231223.pdf`** (page 29 specifically)
   - Contains `audiostream.cgi` definition
   - May reveal camera audio capabilities
   - Look for: Audio codec format, sample rate, channel count

3. **`功能指令文档0125.pdf`** (Function Command Document)
   - Largest file, most comprehensive
   - Contains voice/sound command references
   - Look for: Audio streaming parameters, codec configuration

### **Priority 3: Additional CGI Docs**
4. **`CGI Documentation0125.pdf`**
   - Supplement to CGI manual
   - May have additional audio parameters

---

## 🔍 SPECIFIC QUESTIONS TO ANSWER

When reviewing these documents, look for answers to:

### **1. P2P Audio API**
- [ ] Does the SDK expose `startVoice()` / `stopVoice()` methods?
- [ ] What parameters does `AppPlayerController.create()` accept?
  - [ ] `audioRate` parameter documented?
  - [ ] Audio channel selection (P2P_AUDIO_CHANNEL)?
- [ ] Does SDK expose raw audio data callback?
- [ ] Are there audio configuration flags or options?

### **2. Camera Audio Capabilities**
- [ ] What audio codecs does the camera support?
  - [ ] G.711 A-law?
  - [ ] G.711 μ-law?
  - [ ] ADPCM?
  - [ ] PCM?
- [ ] What sample rates are supported?
  - [ ] 8000 Hz?
  - [ ] 16000 Hz?
- [ ] Is audio mono or stereo?
- [ ] How to check if camera supports audio? (CGI command?)

### **3. Audio Streaming via CGI**
- [ ] What parameters does `audiostream.cgi` accept?
- [ ] Is `audiostream.cgi` used for HTTP streaming or P2P?
- [ ] Are there audio enable/disable parameters in `get_params.cgi`?
  - [ ] `audio_enable=1` parameter?
  - [ ] `audio_support=1` flag?

### **4. SDK Audio Session Management**
- [ ] Does SDK documentation mention AVAudioSession configuration?
- [ ] Are there iOS-specific audio initialization instructions?
- [ ] Any known iOS 17+ compatibility notes?
- [ ] Any troubleshooting section for audio issues?

### **5. Known Limitations**
- [ ] Does documentation mention "no audio streaming on some models"?
- [ ] Are there camera model lists with audio capabilities?
- [ ] Any warnings about audio not working?

---

## 📊 EXTRACTION TEMPLATE

When reading the PDFs, extract information in this format:

```markdown
### Document: [filename]
### Section: [page number or section name]

**Audio API Found:**
- Method: `startVoice()`
- Parameters: `audioRate: 8000`
- Description: [what the doc says]

**Audio Codec Info:**
- Supported Codecs: G.711 A-law, ADPCM
- Sample Rate: 8000 Hz
- Channels: Mono

**Configuration:**
- CGI Command: `audiostream.cgi?user=admin&pwd=`
- Parameters: [list parameters]

**Known Issues:**
- [any warnings or limitations mentioned]
```

---

## 🔧 TOOLS TO USE

### For PDF Files:
```bash
# Option 1: Use pdfgrep (if installed)
pdfgrep -i "audio\|voice\|codec" "flutter sdk参数使用说明.pdf"

# Option 2: Convert PDF to text first
pdftotext "flutter sdk参数使用说明.pdf" - | grep -i "audio\|voice"

# Option 3: Open in Preview/Adobe and search
# Search terms: audio, voice, startVoice, stopVoice, audioRate, codec, G.711, ADPCM, 8000
```

### For Markdown Files:
```bash
# Search all markdown documentation
grep -r -i "audio\|voice\|codec\|startVoice" /Users/mpriessner/windsurf_repos/SciSymbioLens/docs/official_documentation/*.md
```

---

## 🎯 EXPECTED OUTCOMES

After reviewing these documents, you should be able to answer:

1. **Does the Veepa P2P SDK support audio playback on iOS?**
   - If yes: What's the correct API usage?
   - If no: Is this a known limitation?

2. **What audio codec does camera OKB0379853SNLJ use?**
   - Format: G.711 A-law / G.711 μ-law / ADPCM / PCM
   - Sample Rate: 8000 Hz / 16000 Hz
   - Channels: Mono / Stereo

3. **How to check if a camera supports audio?**
   - CGI command: `get_params.cgi` with specific parameter?
   - SDK method: Some capability check?

4. **Why is error -50 occurring?**
   - Does documentation mention iOS audio session requirements?
   - Are there known iOS compatibility issues?

5. **Is there a workaround or alternative method?**
   - Raw audio data access?
   - Different initialization sequence?
   - Configuration flags to enable audio?

---

## 📝 REPORT BACK FORMAT

After investigation, provide:

```markdown
## Audio Documentation Findings

### SDK Audio API
- **Status**: [Found / Not Found / Partially Documented]
- **Methods**: [list methods found]
- **Parameters**: [list parameters]
- **Example Usage**: [code example if available]

### Camera Audio Capabilities
- **Codec**: [G.711 A-law / unknown]
- **Sample Rate**: [8000 Hz / unknown]
- **Detection Method**: [CGI command or SDK method]

### Known Issues
- [List any warnings, limitations, or compatibility notes]

### Recommendations
- [What should we try next based on documentation findings]
```

---

**Last Updated**: 2026-02-02
**Status**: Ready for agent investigation
**Priority**: High - blocking audio feature implementation
