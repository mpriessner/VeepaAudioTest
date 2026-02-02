# Story 4: Testing Audio Session Solutions

**Epic**: VeepaAudioTest - Minimal Audio Testing App
**Total Estimated Time**: 2-3 hours
**Status**: 🚧 In Progress

---

## 📋 Story Overview

Implement and test multiple audio session configuration strategies to resolve AudioUnit error -50. This story creates a systematic testing framework to identify which approach successfully enables audio playback from Veepa cameras.

**What We're Building:**
- AudioSessionStrategy protocol for swappable configurations
- 4 different strategy implementations:
  1. **Baseline**: Standard AVAudioSession setup (current approach)
  2. **Pre-Initialize**: Configure audio BEFORE Flutter engine starts
  3. **Swizzled**: Method swizzling to force 8kHz format
  4. **Locked**: Lock audio session to prevent SDK changes
- UI picker for selecting strategies
- Comprehensive diagnostic logging
- Test results documentation

**What We're Adapting from SciSymbioLens:**
- AVAudioSession configuration patterns
- Strategy pattern for testing variations
- Diagnostic logging approach
- NOT copying: Video audio routing, multi-device audio

---

## 📊 Sub-Stories

Work through these sequentially. Each sub-story is a separate file with detailed instructions.

### ✅ Sub-Story 4.1: Audio Session Strategy Protocol
⏱️ **20-25 minutes** | 📄 [sub-story-4.1-audio-session-protocol.md](sub-story-4.1-audio-session-protocol.md)

Create protocol and manager for audio session strategies.

**Acceptance Criteria:**
- [ ] AudioSessionStrategy protocol defined
- [ ] Protocol methods: prepareAudioSession(), cleanupAudioSession()
- [ ] Protocol properties: name, description
- [ ] AudioSessionStrategyManager created (if needed)
- [ ] File compiles without errors

---

### ✅ Sub-Story 4.2: Baseline Strategy Implementation
⏱️ **15-20 minutes** | 📄 [sub-story-4.2-baseline-strategy.md](sub-story-4.2-baseline-strategy.md)

Implement baseline strategy (current approach that produces error -50).

**Acceptance Criteria:**
- [ ] BaselineStrategy class created
- [ ] Implements AudioSessionStrategy protocol
- [ ] Standard AVAudioSession configuration
- [ ] Comprehensive logging of session state
- [ ] Expected to produce error -50
- [ ] File compiles without errors

---

### ✅ Sub-Story 4.3: Pre-Initialize Strategy Implementation
⏱️ **20-25 minutes** | 📄 [sub-story-4.3-pre-initialize-strategy.md](sub-story-4.3-pre-initialize-strategy.md)

Implement strategy that configures audio session BEFORE Flutter engine starts.

**Acceptance Criteria:**
- [ ] PreInitializeStrategy class created
- [ ] Sets preferred sample rate to 8000 Hz early
- [ ] Sets preferred buffer duration
- [ ] Initialization guard (only configure once)
- [ ] Logging shows early vs late configuration
- [ ] File compiles without errors

---

### ✅ Sub-Story 4.4: Swizzled Strategy Implementation
⏱️ **25-30 minutes** | 📄 [sub-story-4.4-swizzled-strategy.md](sub-story-4.4-swizzled-strategy.md)

Implement method swizzling strategy to intercept and force 8kHz audio format.

**Acceptance Criteria:**
- [ ] SwizzledStrategy class created
- [ ] Method swizzling for setPreferredSampleRate
- [ ] Forces 8000 Hz regardless of SDK requests
- [ ] Swizzle guard (only swizzle once)
- [ ] AVAudioSession extension with swizzled methods
- [ ] Comprehensive logging of interceptions
- [ ] File compiles without errors

---

### ✅ Sub-Story 4.5: Locked Session Strategy Implementation
⏱️ **20-25 minutes** | 📄 [sub-story-4.5-locked-session-strategy.md](sub-story-4.5-locked-session-strategy.md)

Implement strategy that locks audio session configuration to prevent SDK changes.

**Acceptance Criteria:**
- [ ] LockedSessionStrategy class created
- [ ] Pre-configures with G.711-compatible settings
- [ ] Sets all audio preferences (sample rate, channels, buffer)
- [ ] Activates with high priority
- [ ] Logs hardware configuration details
- [ ] File compiles without errors

---

### ✅ Sub-Story 4.6: Comprehensive Testing and Documentation
⏱️ **30-40 minutes** | 📄 [sub-story-4.6-comprehensive-testing.md](sub-story-4.6-comprehensive-testing.md)

Test all strategies systematically and document results.

**Acceptance Criteria:**
- [ ] Updated AudioStreamService with strategy selection
- [ ] Updated ContentView with strategy picker UI
- [ ] All 4 strategies tested with real camera
- [ ] TEST_RESULTS.md created with detailed findings
- [ ] Console logs captured for each strategy
- [ ] AVAudioSession state documented for each strategy
- [ ] Clear recommendation for SciSymbioLens implementation
- [ ] If none work: Minimal reproducible case for SDK vendor

---

## 🎯 Story 4 Complete Checklist

**Check all before completing project:**

### Strategy Implementation
- [ ] All 4 strategies implemented
- [ ] Each strategy has unique approach
- [ ] All strategies follow protocol pattern
- [ ] Comprehensive logging in each

### Testing Infrastructure
- [ ] Strategy picker in UI
- [ ] Can switch between strategies
- [ ] Each strategy tested with real camera
- [ ] Test results documented

### Documentation
- [ ] TEST_RESULTS.md complete
- [ ] Console logs captured
- [ ] Clear winner identified (or none)
- [ ] Recommendation for SciSymbioLens
- [ ] Next steps documented

---

## 🎉 Story 4 Deliverables

Once complete, you will have:
- ✅ 4 different audio session strategies implemented
- ✅ Systematic testing framework
- ✅ Comprehensive test results with all outcomes
- ✅ Clear path forward for SciSymbioLens implementation
- ✅ Minimal reproducible case (if all strategies fail)

**Result**: Either a working audio solution OR definitive proof that SDK audio is incompatible

---

## 🎯 Expected Outcomes

### Scenario A: One Strategy Works ✅
- Audio plays successfully with one or more strategies
- Error -50 is resolved
- **Action**: Document winning strategy, implement in SciSymbioLens
- **Time to Solution**: 15-30 minutes to adapt to main app

### Scenario B: All Strategies Fail ❌
- Error -50 persists across all configurations
- Comprehensive diagnostic data collected
- **Action**: Contact SDK vendor with minimal reproducible case
- **Alternative**: Implement custom AudioUnit decoder OR ship video-only mode

---

## 📊 Test Results Matrix Template

After testing, your matrix should look like:

| Strategy | Audio Plays? | Error Code | Sample Rate | Notes |
|----------|--------------|------------|-------------|-------|
| Baseline | ❌ | -50 | 48000 Hz | Standard config |
| Pre-Initialize | ✅/❌ | - / -50 | 8000 Hz | Set before Flutter |
| Swizzled | ✅/❌ | - / -50 | 8000 Hz | Force via swizzling |
| Locked | ✅/❌ | - / -50 | 8000 Hz | Lock session |

**Goal**: At least one ✅ in "Audio Plays?" column

---

## 🚨 Important Notes

### Testing Best Practices
1. **Restart app between strategies** to clear any audio session state
2. **Test on physical device** (simulator audio behaves differently)
3. **Document EVERYTHING** - logs are critical if vendor support needed
4. **Capture full console output** for each test

### Time Management
- Don't spend more than 10 minutes per strategy test
- If all fail quickly, move to documentation
- The test results are valuable even if audio doesn't work

### Success Criteria
- **Primary**: Audio works in at least one configuration
- **Secondary**: Complete diagnostic data for all strategies
- **Minimum**: Clear proof of issue for vendor escalation

---

**Created**: 2026-02-02
**Based on**: story-4-testing-audio-solutions.md original story
**Source**: AVAudioSession documentation + SciSymbioLens patterns
