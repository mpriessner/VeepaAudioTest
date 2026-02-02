# Alarm Function Development Document (0106)

This document is a translation of `报警功能开发文档0106.pdf`.

---

## Description

1.  The alarm functionality includes motion detection and related settings.
2.  Motion detection is divided into **motion detection** and **human detection**.
    -   **Note:** Low-power devices only have human detection (which is their form of "motion detection"). Corded devices have true motion detection.
3.  Detection-related features include: human detection, person tracking, detection sensitivity/frequency, detection distance, alarm flashing light, activity zone, detection schedule, and alarm sound settings.
    -   Low-power devices support setting human detection and detection distance independently.
    -   Other detection features (except for human framing/tracking) should only be set when motion detection is enabled.

---

### 1. Low-Power Motion Detection (Human Detection)

-   **To determine if a device is low-power:** Get `support_low_power` from `get_status.cgi?`. If the value is `1`, it is a low-power device.
-   **Set Switch State:**
    -   **CGI:** `trans_cmd_string.cgi?cmd=2106&command=9&pirPushSwitch=$pirPushSwitch&pirPushSwitchVideo=$pirPushSwitchVideo&`
    -   **Parameters:**
        -   `pirPushSwitch`: `1` (on), `0` (off)
        -   `pirPushSwitchVideo` (Cloud Recording): `1` (on), `0` (off)
-   **Get Switch State:**
    -   **CGI:** `"trans_cmd_string.cgi?cmd=2106&command=8&"`
    -   **Field to check:** `pirPushSwitch=="1"`

### 2. Low-Power Detection Frequency

-   **Set Detection Frequency:**
    -   **CGI:** `trans_cmd_string.cgi?cmd=2106&command=4&humanDetection=$detection&&mark=123456789&`
    -   **Parameters:**
        -   `detection`: `0` (off), `1-3` (High, Medium, Low)
        -   `mark`: Random number
-   **Get Detection Frequency:**
    -   **CGI:** `trans_cmd_string.cgi?cmd=2106&command=3&mark=12345678&`
    -   **Field to check:** `humanDetection`

### 3. Corded-Electric Motion Detection Switch

-   **To determine if a device is corded:** Get `support_low_power` from `get_status.cgi?`. If it has no value or is `0`, it's a corded device.
-   **Set Switch State:**
    -   **CGI:** `trans_cmd_string.cgi?cmd=2017&command=2&mark=212&` with `motion_push_plan` parameters.
    -   **Parameters:**
        -   `motion_push_plan`: An alarm plan (21 values, -1 for unset).
        -   `enable`: `0` (off), `1` (motion detection), `5` (human detection).
-   **Get Switch State:**
    -   **CGI:** `trans_cmd_string.cgi?cmd=2017&command=11&mark=212&type=2&`
    -   **Field to check:** `motion_push_enable` (`0` off, `1` motion, `5` human).

### 4. Corded-Electric Motion Detection Sensitivity

-   **Set Sensitivity:**
    -   **CGI:** `set_alarm.cgi?enable_alarm_audio=0&motion_armed=$motion_armed&motion_sensitivity=$motion_sensitivity&`
    -   **Parameters:**
        -   `motion_armed`: `1` (on), `0` (off)
        -   `motion_sensitivity`: `1` (High), `5` (Medium), `9` (Low)
-   **Get Sensitivity:**
    -   **CGI:** `get_params.cgi?`
    -   **Field to check:** `alarm_motion_sensitivity`

### 5. Corded-Electric Human Detection Sensitivity

-   **Set Sensitivity:**
    -   **CGI:** `trans_cmd_string.cgi?cmd=2126&command=0&sensitive=$sensitive&&mark=123456789&`
    -   **Parameters:**
        -   `sensitive`: `0` (off), `1-3` (High, Medium, Low)
-   **Get Sensitivity:**
    -   **CGI:** `trans_cmd_string.cgi?cmd=2126&command=1&mark=123456789&`
    -   **Field to check:** `sensitive`

### 6. Human Detection Switch

-   **Note:** Low-power devices can enable human detection without human framing to improve alarm accuracy.
-   **Set Switch State:**
    -   **CGI:** `String cgi = "trans_cmd_string.cgi?cmd=2106&command=4&HumanoidDetection=$value&"`
    -   `value`: `1` (on), `0` (off)
-   **Get Switch State:**
    -   **CGI:** `trans_cmd_string.cgi?cmd=2106&command=3&`
    -   **Field to check:** `HumanoidDetection`

### 7. Detection Distance Setting

-   **Note:** After enabling motion detection, distance can be set if the device supports it. Check `get_status.cgi?` for `support_Pir_Distance_Adjust` > 0.
-   **Set Distance:**
    -   **CGI:** `String cgi ="trans_cmd_string.cgi?cmd=2106&command=4&humanDetection=$pirLevel&DistanceAdjust=$distance&"`
    -   `distance`: `1-3` (Near, Medium, Far)
-   **Get Distance:**
    -   **CGI:** `trans_cmd_string.cgi?cmd=2106&command=3&`
    -   **Field to check:** `DistanceAdjust`
