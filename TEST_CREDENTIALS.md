# VeepaAudioTest - Test Credentials

**Last Updated**: 2026-02-03

## Camera Credentials

These are hard-coded into the app for convenience during testing.

### Test Camera (from SciSymbioLens)
- **UID**: `OKB0379853SNLJ`
- **Password**: `888888`
- **Status**: Known working test camera

### Camera Admin (if needed)
- **Default admin password**: `admin`

## WiFi Credentials

### Development WiFi Network
- **SSID**: *(Auto-detected by iOS)*
- **Password**: `6wKe727e`
- **Source**: SciSymbioLens provisioning view

## Router Access (if needed)

### Typical Router Settings
- **Gateway IP**: `192.168.32.1` (or `192.168.1.1`)
- **Admin Username**: `admin` (typical default)
- **Admin Password**: *(Check router label or use default)*

**Note**: Router access typically not needed for P2P camera testing.

## Camera Network Info (from logs)

- **Local IP**: `192.168.32.6` (example from SciSymbioLens logs)
- **WAN IP**: `90.144.254.38` (example)
- **NAT Type**: 2 (moderate, suitable for P2P)

## How Credentials Are Used

### In VeepaAudioTest App
1. **Camera UID** and **Password** are pre-filled in the connection form
2. Just tap **"Connect"** to start testing
3. WiFi password only needed for camera provisioning (not implemented yet)

### Physical Camera Verification
1. Check the label on your physical camera
2. Verify the UID matches `OKB0379853SNLJ`
3. If different, update `ContentView.swift` line 18:
   ```swift
   @State private var uid = "YOUR_CAMERA_UID_HERE"
   ```

## Troubleshooting

### If Connection Fails
1. Verify camera is powered on
2. Verify camera is on the same WiFi network
3. Check camera UID matches exactly (case-sensitive)
4. Try default password: `888888` or `admin`

### Camera Network Requirements
- Camera must be connected to WiFi
- Phone must be on same network (for initial testing)
- P2P connection works across different networks (after initial setup)

## References

- **SciSymbioLens Project**: `/Users/mpriessner/windsurf_repos/SciSymbioLens`
- **Audio Test Instructions**: `SciSymbioLens/docs/stories/epic-20-camera-audio/MINIMAL_AUDIO_TEST_APP_INSTRUCTIONS.md`
- **Camera Documentation**: `SciSymbioLens/docs/official_documentation/`

---

**Security Note**: These are test credentials only. Do not use in production.
