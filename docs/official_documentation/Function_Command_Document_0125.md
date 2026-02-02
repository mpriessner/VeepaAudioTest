# Function Command Document (0125)

This is a translation of `功能指令文档0125.pdf`.

## Table of Contents
1.  Low Power Mode
2.  Device Volume
3.  Hide Indicator Light
4.  PTZ (Pan-Tilt-Zoom)
5.  Activity Zone
6.  Resolution
7.  Night Vision Setting
8.  Cloud Video Recording Switch
9.  Zoom
10. Alarm Siren
11. White Light
12. Humanoid Frame
13. Humanoid Detection
14. TF Card Playback Data
15. Person Tracking
16. Red & Blue Lights
17. Alarm Flashing Light
18. Virtual Joystick
19. Recording Duration
20. Smart Detection Schedule
21. Alarm Sound Settings
22. TF Card Sound Recording Switch
23. TF Card Recording Mode
24. TF Card Recording Time
25. TF Card Format
26. Linkage Correction (Dual Lens)
27. Dual/Triple Lens Conditions
28. Humanoid Zoom Tracking
29. Screenshot Command
30. Video Flipping
31. Light Anti-interference
32. Video Time Display
33. Remote Power On/Off
34. WiFi QR Code Networking
35. Bluetooth Network Connection
36. Update Firmware Version
37. Switch Device WiFi
38. AI Smart Services

---

### 1. Low Power Mode
**Note:** Not available for corded cameras.
-   **Set Power Mode:** `trans_cmd_string.cgi?cmd=2106&command=2&lowPower=$value`
    -   `value`: `0` (Keep Working), `30` (Power Saving), `10000` (Super Power Saving)
-   **Get Power Mode:** `trans_cmd_string.cgi?cmd=2106&command=1&`
-   **Set Smart Sleep Mode:** `trans_cmd_string.cgi?cmd=2106&command=18&...`

### 2. Device Volume
-   **Set Volume:** `camera_control.cgi?param=$param&value=$value`
    -   `param`: `24` (Microphone), `25` (Horn)
    -   `value`: 0-31
-   **Get Volume:** `get_camera_params.cgi?` (Fields: `involume`, `outvolume`)

### 3. Hide Indicator Light
-   **Set Hide Light:** `trans_cmd_string.cgi?cmd=2125&command=0&hide_led_disable=$value` (`1` hide, `0` show)
-   **Get Hide Light Status:** `trans_cmd_string.cgi?cmd=2125&command=1&`

### 4. PTZ (Pan-Tilt-Zoom)
-   **Vertical/Horizontal Cruise:** `decoder_control.cgi` with commands `26-29`.
-   **Preset Cruise:** `decoder_control.cgi` with commands `22`, `23`.
-   **PTZ Correction:** `decoder_control.cgi?command=25&onestep=0&` (Not available below 20% battery).
-   **Presets (5 positions):** `decoder_control.cgi?command=$cmd&onestep=0&` where `cmd` is `30, 32, 34, 36, 38` for setting, `31, 33, 35, 37, 39` for cruising, and `62-66` for deleting.
-   **Caretaker Position:** `set_sensor_preset.cgi?sensorid=255&presetid=$index&`

*(This is a partial summary. The full document provides detailed CGI commands for all 38 features listed in the table of contents.)*
