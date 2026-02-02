# Alarm Function Development Documentation

## Description

1. The alarm function includes motion detection and related feature settings.
2. Motion detection is divided into **motion detection** and **human shape detection**.
   > Note: Low-power devices only have human body detection (motion detection equals human body detection). Long-power devices have motion detection.
3. Detection-related functions include: human shape recognition, human shape tracking, detection sensitivity (frequency), detection distance, alarm flash light, detection area drawing, smart detection timing, and alarm sound switch.
4. Low-power devices support separate settings for human shape recognition and detection distance. Except for human shape framing (recognition) and human shape tracking, other detection-related functions should only be set when motion detection is enabled.

---

## Table of Contents

1. [Low-Power Motion Detection (Human Body Detection)](#1-low-power-motion-detection-human-body-detection)
2. [Low-Power Detection Frequency](#2-low-power-detection-frequency)
3. [Long-Power Motion Detection Switch](#3-long-power-motion-detection-switch)
4. [Long-Power Motion Detection Sensitivity](#4-long-power-motion-detection-sensitivity)
5. [Long-Power Human Shape Detection Sensitivity](#5-long-power-human-shape-detection-sensitivity)
6. [Human Body Detection Switch](#6-human-body-detection-switch)
7. [Detection Distance Settings](#7-detection-distance-settings)

---

## 1. Low-Power Motion Detection (Human Body Detection)

### Check if Device is Low-Power

**Field:** `support_low_power` has a value and equals 1

**Command to get field:** `get_status.cgi?`

### Set Switch

**Command:** `trans_cmd_string.cgi?cmd=2106&command=9&pirPushSwitch=$pirPushSwitch&pirPushSwitchVideo=$pirPushSwitchVideo&`

| Parameter | Type | Description |
|-----------|------|-------------|
| pirPushSwitch | int | 1: Enable, 0: Disable |
| pirPushSwitchVideo | int | Cloud recording switch: 1: Enable, 0: Disable |

### Get Switch Status

**Command:** `trans_cmd_string.cgi?cmd=2106&command=8&`

**Judgment field:** `pirPushSwitch == "1"`

---

## 2. Low-Power Detection Frequency

### Set Command

**Command:** `trans_cmd_string.cgi?cmd=2106&command=4&humanDetection=$detection&&mark=123456789&`

| Parameter | Type | Description |
|-----------|------|-------------|
| detection | int | 0-3, where 0: Disabled, 1-3: High/Medium/Low |
| mark | int | Marker: Random number |

### Get Initial Value

**Command:** `trans_cmd_string.cgi?cmd=2106&command=3&mark=12345678&`

**Judgment field:** `humanDetection`

---

## 3. Long-Power Motion Detection Switch

### Check if Device is Long-Power

**Field:** `support_low_power` has no value or equals 0

**Command to get field:** `get_status.cgi?`

### CGI Command

```dart
String cgi = "trans_cmd_string.cgi?cmd=2017&command=2&mark=212&"
"motion_push_plan1=-1&"
"motion_push_plan2=-1&"
"motion_push_plan3=-1&"
"motion_push_plan4=-1&"
"motion_push_plan5=-1&"
"motion_push_plan6=-1&"
"motion_push_plan7=-1&"
"motion_push_plan8=-1&"
"motion_push_plan9=-1&"
"motion_push_plan10=-1&"
"motion_push_plan11=-1&"
"motion_push_plan12=-1&"
"motion_push_plan13=-1&"
"motion_push_plan14=-1&"
"motion_push_plan15=-1&"
"motion_push_plan16=-1&"
"motion_push_plan17=-1&"
"motion_push_plan18=-1&"
"motion_push_plan19=-1&"
"motion_push_plan20=-1&"
"motion_push_plan21=-1&"
"motion_push_plan_enable=$enable&";
```

| Parameter | Type | Description |
|-----------|------|-------------|
| motion_push_plan | int | Alarm plan, 21 items, -1: Not set |
| enable | int | 0: Disabled, 1: Motion detection, 5: Human shape detection |

### Get Motion Detection Switch Status

**Command:** `trans_cmd_string.cgi?cmd=2017&command=11&mark=212&type=2&`

**Judgment field:** `motion_push_enable`
- 0: Disabled
- 1: Motion detection
- 5: Human shape detection

---

## 4. Long-Power Motion Detection Sensitivity

### Set Command

**Command:** `set_alarm.cgi?enable_alarm_audio=0&motion_armed=$motion_armed&motion_sensitivity=$motion_sensitivity&`

| Parameter | Type | Description |
|-----------|------|-------------|
| motion_armed | int | 1: Enable, 0: Disable |
| motion_sensitivity | int | 1: High, 5: Medium, 9: Low |

### Get Sensitivity Level

**Command:** `get_params.cgi?`

**Judgment field:** `alarm_motion_sensitivity`

---

## 5. Long-Power Human Shape Detection Sensitivity

### Set Command

**Command:** `trans_cmd_string.cgi?cmd=2126&command=0&sensitive=$sensitive&&mark=123456789&`

| Parameter | Type | Description |
|-----------|------|-------------|
| sensitive | int | 0-3, where 0: Disabled, 1-3: High/Medium/Low |
| mark | int | Marker: Random number |

### Get Sensitivity

**Command:** `trans_cmd_string.cgi?cmd=2126&command=1&mark=123456789&`

**Judgment field:** `sensitive`

---

## 6. Human Body Detection Switch

Low-power devices can enable human body detection without enabling human shape framing (only triggers alarm when a person appears, which improves alarm accuracy).

- `value == 1`: Enable
- `value == 0`: Disable

### CGI Command

**Command:** `trans_cmd_string.cgi?cmd=2106&command=4&HumanoidDetection=$value&`

| Parameter | Type | Description |
|-----------|------|-------------|
| value | int | 0: Disable, 1: Enable |

### Get Human Body Detection Switch Status

**Command:** `trans_cmd_string.cgi?cmd=2106&command=3&`

**Judgment field:** `HumanoidDetection`

---

## 7. Detection Distance Settings

Detection distance can be set after enabling motion detection, but you need to check if the device supports this feature.

### Check Support

Use `get_status.cgi?` to get the `support_Pir_Distance_Adjust` parameter. When this parameter is > 0, the device supports this feature.

```dart
if (result.support_Pir_Distance_Adjust != null) {
  DeviceManager.getInstance()
      .getDeviceModel()!
      .supportPirDistanceAdjust
      .value = int.tryParse(result.support_Pir_Distance_Adjust!) ?? 0;
}
```

### Distance Values

- 1: Near
- 2: Medium
- 3: Far

### CGI Command

**Command:** `trans_cmd_string.cgi?cmd=2106&command=4&humanDetection=$pirLevel&DistanceAdjust=$distance&`

| Parameter | Type | Description |
|-----------|------|-------------|
| distance | int | Detection distance: 1-3 (Near/Medium/Far) |

### Get Detection Distance

**Command:** `trans_cmd_string.cgi?cmd=2106&command=3&`

**Judgment field:** `DistanceAdjust`
