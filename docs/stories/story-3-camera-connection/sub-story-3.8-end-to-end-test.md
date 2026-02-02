# Sub-Story 3.8: End-to-End Connection and Audio Test

**Goal**: Test complete flow: connect to camera, start audio, verify logging, handle errors

**Estimated Time**: 25-30 minutes

---

## 📋 Test Overview

This sub-story validates the entire Story 3 implementation by:
1. Obtaining real camera credentials
2. Connecting to a physical Veepa camera
3. Attempting to start audio playback
4. Verifying comprehensive debug logging
5. Documenting the outcome (success or error -50)

**Two Possible Outcomes:**
- ✅ **Success**: Audio plays, proceed to document solution
- ❌ **Error -50**: Expected failure, proceed to Story 4 for testing solutions

---

## 🛠️ Test Procedure

### Step 3.8.1: Obtain Camera Credentials (10 min)

**Prerequisites:**
- Physical Veepa camera powered on
- Camera connected to WiFi network
- iPhone on same WiFi network
- Camera UID available (from camera label or provisioning)

**Get Service Parameter:**

```bash
# Extract first 4 characters of UID
# Example: If UID is "ABCD-123456-ABCDE", use "ABCD"

# Call authentication API
curl -X POST https://authentication.eye4.cn/getInitstring \
  -H "Content-Type: application/json" \
  -d '{"uid": ["ABCD"]}' \
  -o credentials.json

# View response
cat credentials.json
# Expected output:
# ["eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."] (base64 string)

# Extract serviceParam (the string inside the array)
SERVICE_PARAM=$(cat credentials.json | jq -r '.[0]')
echo "ServiceParam: $SERVICE_PARAM"
```

**Save credentials for testing:**
```bash
echo "UID: ABCD-123456-ABCDE" > test_credentials.txt
echo "ServiceParam: $SERVICE_PARAM" >> test_credentials.txt
cat test_credentials.txt
```

**✅ Verification:**
```bash
# Check credentials file
cat test_credentials.txt
# ✅ Expected: UID and ServiceParam present
# ✅ ServiceParam should be ~200-500 characters (base64 encoded JWT)
```

---

### Step 3.8.2: Test Connection Flow (10 min)

```bash
cd ios/VeepaAudioTest

# Build and run app
open VeepaAudioTest.xcodeproj
# In Xcode: Select physical iPhone device (not simulator)
# Press Cmd+R to build and run
```

**Manual Test Steps:**

1. **Enter Credentials:**
   - Paste full UID into "Camera UID" field
   - Paste ServiceParam into "Service Param" field
   - ✅ Verify: Connect button becomes enabled (blue)

2. **Initiate Connection:**
   - Tap "Connect" button
   - ✅ Verify: Button shows spinner and turns orange
   - ✅ Verify: Status shows "Connecting..."
   - ✅ Verify: Debug log shows connection progress

3. **Verify Connection Success:**
   - Wait 5-15 seconds
   - ✅ Verify: Status changes to "Connected" (green indicator)
   - ✅ Verify: Debug log shows:
     ```
     [HH:MM:SS] 🔌 Connecting to camera...
     [HH:MM:SS]    UID: ABCD-123456-ABCDE
     [HH:MM:SS]    ServiceParam: eyJhbGci...
     [HH:MM:SS]    Initializing Flutter engine...
     [HH:MM:SS]    ✅ Flutter ready
     [HH:MM:SS]    Establishing P2P connection...
     [HH:MM:SS]    ✅ Connected! clientPtr: [number]
     [HH:MM:SS]    ✅ Flutter notified of clientPtr
     ```
   - ✅ Verify: "Start Audio" button becomes enabled (green)

**If connection fails:**
- Check camera is powered on
- Verify both devices on same WiFi network
- Ensure serviceParam is fresh (expires after ~10 minutes)
- Check debug logs for specific error message

---

### Step 3.8.3: Test Audio Playback (10 min)

**Test Audio Start:**

1. **Start Audio Attempt:**
   - Tap "Start Audio" button
   - ✅ Verify: Debug log shows AVAudioSession configuration
   - ✅ Verify: startVoice() is called

2. **Observe Outcome:**

   **Outcome A - Success (Audio Plays):**
   ```
   [HH:MM:SS] 🎵 Starting audio...
   [HH:MM:SS]    Configuring AVAudioSession...
   [HH:MM:SS]    ✅ AVAudioSession configured
   [HH:MM:SS]       Category: AVAudioSessionCategoryPlayAndRecord
   [HH:MM:SS]       Mode: AVAudioSessionModeVideoChat
   [HH:MM:SS]       SampleRate: 48000.0 Hz
   [HH:MM:SS]       IOBufferDuration: 10.0 ms
   [HH:MM:SS]    startVoice result: 0
   [HH:MM:SS]    ✅ Audio started
   ```
   - ✅ Hear audio from camera through iPhone speaker
   - ✅ Audio status shows "Playing" (green icon)
   - ✅ "Stop Audio" button is active
   - ✅ "Mute" button becomes enabled

   **Outcome B - Error -50 (Expected Failure):**
   ```
   [HH:MM:SS] 🎵 Starting audio...
   [HH:MM:SS]    Configuring AVAudioSession...
   [HH:MM:SS]    ✅ AVAudioSession configured
   [HH:MM:SS]       Category: AVAudioSessionCategoryPlayAndRecord
   [HH:MM:SS]       Mode: AVAudioSessionModeVideoChat
   [HH:MM:SS]       SampleRate: 48000.0 Hz
   [HH:MM:SS]       IOBufferDuration: 10.0 ms
   [HH:MM:SS]    ❌ startAudio failed: Error -50 (kAudioUnitErr_FormatNotSupported)
   ```
   - ❌ No audio heard
   - ❌ Error alert appears with error message
   - ✅ App doesn't crash
   - ✅ Can try again or disconnect

**Test Mute (if audio is playing):**

1. Tap "Mute" button
2. ✅ Verify: Button changes to "Unmute"
3. ✅ Verify: Debug log shows setMute(true) result
4. ✅ Verify: Audio volume changes (or mutes completely)

**Test Audio Stop:**

1. Tap "Stop Audio" button
2. ✅ Verify: Debug log shows:
   ```
   [HH:MM:SS] 🛑 Stopping audio...
   [HH:MM:SS]    stopVoice result: 0
   [HH:MM:SS]    ✅ Audio stopped
   [HH:MM:SS]    Deactivating AVAudioSession...
   [HH:MM:SS]    ✅ AVAudioSession deactivated
   ```
3. ✅ Verify: Audio status shows "Stopped"
4. ✅ Verify: "Mute" button becomes disabled

**Test Disconnect:**

1. Tap "Disconnect" button
2. ✅ Verify: Debug log shows:
   ```
   [HH:MM:SS] 🔌 Disconnecting...
   [HH:MM:SS]    ✅ Disconnected
   ```
3. ✅ Verify: Status shows "Disconnected"
4. ✅ Verify: Input fields become enabled again

---

### Step 3.8.4: Document Test Results (5 min)

Create `ios/VeepaAudioTest/TEST_RESULTS_STORY3.md`:

```markdown
# Story 3 Test Results

**Date**: [Current Date]
**Device**: [iPhone model]
**iOS Version**: [Version]
**Camera**: Veepa [Model]
**Camera UID**: [UID]

---

## Test 1: Connection

**Status**: ✅ PASS / ❌ FAIL

**Connection Time**: [seconds]

**ClientPtr**: [value]

**Debug Logs**:
```
[Paste connection logs here]
```

---

## Test 2: Audio Playback

**Status**: ✅ PASS / ❌ FAIL (Error -50)

**Error Code**: [if applicable]

**Audio Session Configuration**:
- Category: [value]
- Mode: [value]
- Sample Rate: [Hz]
- IO Buffer Duration: [ms]

**Debug Logs**:
```
[Paste audio start logs here]
```

**Outcome**:
- [ ] Audio heard from camera
- [ ] Error -50 received
- [ ] Other error: [describe]

---

## Test 3: Audio Controls

**Mute Test**: ✅ PASS / ❌ FAIL / ⏭️ SKIP

**Stop Audio Test**: ✅ PASS / ❌ FAIL / ⏭️ SKIP

**Observations**:
[Describe behavior]

---

## Conclusion

**Overall Result**:
- ✅ Audio works - ready to document solution
- ❌ Error -50 - proceed to Story 4 for testing strategies

**Next Steps**:
[If success: document solution for SciSymbioLens]
[If error -50: proceed to Story 4]
```

**✅ Verification:**
```bash
# Save test results
ls -la ios/VeepaAudioTest/TEST_RESULTS_STORY3.md
# ✅ Expected: File created with complete test documentation
```

---

## ✅ Sub-Story 3.8 Complete Verification

All checks must pass:

```bash
cd ios/VeepaAudioTest

# 1. Credentials obtained
cat test_credentials.txt
# ✅ Expected: UID and ServiceParam present

# 2. App builds successfully
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphoneos \
  build
# ✅ Expected: BUILD SUCCEEDED

# 3. Connection test passed
# ✅ Expected: Can connect to camera and get clientPtr

# 4. Audio test attempted
# ✅ Expected: startVoice() called, outcome logged

# 5. Test results documented
cat ios/VeepaAudioTest/TEST_RESULTS_STORY3.md
# ✅ Expected: Complete test documentation
```

---

## 🎯 Acceptance Criteria

- [ ] Can retrieve camera credentials (UID + serviceParam)
- [ ] Can enter credentials in UI
- [ ] Connection succeeds and shows "Connected" status
- [ ] ClientPtr is logged
- [ ] Start Audio button becomes enabled
- [ ] Can call startVoice() and see result logged
- [ ] Error -50 OR audio playback captured in logs
- [ ] Can stop audio and disconnect
- [ ] All debug logs are comprehensive and useful
- [ ] Test results documented in TEST_RESULTS_STORY3.md

---

## 🎉 Story 3 Complete!

**If audio works:**
- 🎉 Congratulations! You've solved the audio issue
- Document the solution for SciSymbioLens
- Skip Story 4 and implement in main app

**If error -50 occurs:**
- ✅ This is expected - you've successfully reproduced the issue
- Debug logs provide valuable diagnostic information
- Proceed to Story 4 to test alternative audio session strategies

---

## 🔗 Navigation

- ← Previous: [Sub-Story 3.7: Integrate Services](sub-story-3.7-integrate-services.md)
- → Next: [Story 4: Testing Audio Strategies](../story-4-testing-strategies/README.md)
- ↑ Story Overview: [README.md](README.md)
