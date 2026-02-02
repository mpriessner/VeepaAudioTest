# Function Command Documentation

## Table of Contents

1. [Low Power Mode](#1-low-power-mode)
2. [Device Volume](#2-device-volume)
3. [Hide Indicator Light](#3-hide-indicator-light)
4. [PTZ (Pan-Tilt-Zoom)](#4-ptz-pan-tilt-zoom)
5. [Detection Area Drawing](#5-detection-area-drawing)
6. [Image Quality](#6-image-quality)
7. [Night Vision Mode](#7-night-vision-mode)
8. [Cloud Video Recording Switch](#8-cloud-video-recording-switch)
9. [Zoom](#9-zoom)
10. [Siren Command](#10-siren-command)
11. [White Light Command](#11-white-light-command)
12. [Human Shape Frame Command](#12-human-shape-frame-command)
13. [Human Shape Detection Command](#13-human-shape-detection-command)
14. [Get TF Card Playback Data Command](#14-get-tf-card-playback-data-command)
15. [Human Shape Tracking](#15-human-shape-tracking)
16. [Red-Blue Light](#16-red-blue-light)
17. [Alarm Flash Light](#17-alarm-flash-light)
18. [Control Joystick](#18-control-joystick)
19. [Video Recording Duration](#19-video-recording-duration)
20. [Smart Detection Timing](#20-smart-detection-timing)
21. [Alarm Sound Settings](#21-alarm-sound-settings)
22. [TF Card Audio Recording Switch](#22-tf-card-audio-recording-switch)
23. [TF Card Recording Mode](#23-tf-card-recording-mode)
24. [TF Card Recording Time](#24-tf-card-recording-time)
25. [TF Card Formatting](#25-tf-card-formatting)
26. [Linkage Calibration (Dual-lens)](#26-linkage-calibration-dual-lens)
27. [Dual/Triple Lens Judgment Conditions](#27-dualtriple-lens-judgment-conditions)
28. [Human Shape Zoom Tracking](#28-human-shape-zoom-tracking)
29. [Screenshot Command](#29-screenshot-command)
30. [Video Flip](#30-video-flip)
31. [Light Anti-interference](#31-light-anti-interference)
32. [Video Time Display](#32-video-time-display)
33. [Remote Power On/Off](#33-remote-power-onoff)
34. [WiFi QR Code Network Configuration](#34-wifi-qr-code-network-configuration)
35. [Bluetooth Network Configuration](#35-bluetooth-network-configuration)
36. [Firmware Version Update](#36-firmware-version-update)
37. [Switch Device WiFi](#37-switch-device-wifi)
38. [AI Smart Services](#38-ai-smart-services)

---

## 1. Low Power Mode

> Note: Long-power devices do not have low power mode.

### Set Power Mode

**CGI Command:** `trans_cmd_string.cgi?cmd=2106&command=2&lowPower=$value`

| Parameter | Type | Description |
|-----------|------|-------------|
| value | int | 0: Continuous work mode, 30: Power saving mode, 10000: Super power saving mode |

### Get Current Power Mode

**Command:** `trans_cmd_string.cgi?cmd=2106&command=1&`

**Response field:** `data["lowPower"]` → 0, 30, 1000

> Note: Use `get_status.cgi?` to get the `supportSmartElectricitySleep` field. If it equals 1, micro-power mode is supported. When switching to other modes, micro-power mode should be turned off.

### Set Micro-Power Mode (Smart Power Saving Mode)

**Command:** `trans_cmd_string.cgi?cmd=2106&command=18&Smart_Electricity_Sleep_Switch=$enable&Smart_Electricity_Threshold=$electricityThreshold&`

| Parameter | Type | Description |
|-----------|------|-------------|
| enable | int | Micro-power on: 1, off: 0 |
| electricityThreshold | int | Micro-power mode battery threshold, e.g., 30 |

### Get Micro-Power Mode

**Command:** `trans_cmd_string.cgi?cmd=2106&command=17&`

**Fields:** `Smart_Electricity_Sleep_Switch`, `Smart_Electricity_Threshold`

---

## 2. Device Volume

### Set Volume

**CGI Command:** `camera_control.cgi?param=$param&value=$value&`

| Parameter | Type | Description |
|-----------|------|-------------|
| param | int | 24: Microphone, 25: Speaker |
| value | int | Volume range: 0-31 |

### Get Volume Information

**File:** `video_command.dart`, **Method:** `getCameraParams()`

**Command:** `get_camera_params.cgi?`

- Microphone: `involume = int.tryParse(data["involume"] ?? "") ?? 0;`
- Speaker: `outvolume = int.tryParse(data["outvolume"] ?? "") ?? 0;`

### Check if Device Has Speaker

Get from device status listener callback: `haveHorn = result.haveHorn == "1" ? true : false;`

---

## 3. Hide Indicator Light

### Set Switch

**Command:** `trans_cmd_string.cgi?cmd=2125&command=0&hide_led_disable=${hide == true ? 1 : 0}&`

| Parameter | Type | Description |
|-----------|------|-------------|
| hide_led_disable | int | 1: Hide, 0: Show |

### Get Status

**Command:** `trans_cmd_string.cgi?cmd=2125&command=1&`

**Judgment:** `hideLed = data["hide_led_disable"] == "1"`

---

## 4. PTZ (Pan-Tilt-Zoom)

### 4.1 Vertical Cruise

- **Enable:** `decoder_control.cgi?command=26&onestep=0&`
- **Disable:** `decoder_control.cgi?command=27&onestep=0&`
- **Status field:** `preset_cruise_status_v` (1: on, 0: off)

### 4.2 Horizontal Cruise

- **Enable:** `decoder_control.cgi?command=28&onestep=0&`
- **Disable:** `decoder_control.cgi?command=29&onestep=0&`
- **Status field:** `preset_cruise_status_h` (1: on, 0: off)

### 4.3 Watch Position Cruise

- **Enable:** `decoder_control.cgi?command=22&onestep=0&`
- **Disable:** `decoder_control.cgi?command=23&onestep=0&`
- **Status field:** `preset_cruise_status` (1: on, 0: off) | `preset_cruise_curpos` (-1: off, 0-4: corresponds to watch position)

### 4.4 PTZ Calibration

> Note: Feature not available when battery is below 20%

**Command:** `decoder_control.cgi?command=25&onestep=0&`

**Status field:** `center_status`

### 4.5 Watch Positions (5 positions)

**Command:** `decoder_control.cgi?command=$cmd&onestep=0&`

| Action | Commands |
|--------|----------|
| Set | 30, 32, 34, 36, 38 |
| Cruise | 31, 33, 35, 37, 39 |
| Delete | 62, 63, 64, 65, 66 |

> Tip: It's recommended to save watch position images to your own server and retrieve them from there.

### 4.6 Guard Position

**Set:** `set_sensor_preset.cgi?sensorid=255&presetid=$index&` (index 1-5, 0 to disable)

> Note: You must set a watch position before setting a guard position. Guard position should be selected from watch positions.

### 4.7 Get Watch Position Settings

**StatusResult** → `result.preset_value` (convert to list)

```dart
var list = presetValue
    .toRadixString(2)
    .padLeft(16, '0')
    .substring(0, 5)
    .split('')
    .toList();
```

Convert the value to a binary string, pad with 0s to 16 characters, take the first 5 characters, then convert to a list. Result 1 means set, 0 means not set.

### 4.8 Get Set Preset Positions

**Command:** `trans_cmd_string.cgi?cmd=2161&command=0&`

There are 16 preset positions in total; the app uses the first 5. A result of 1 indicates the position is set.

---

## 5. Detection Area Drawing

> Note: Drawing is only effective when motion detection is enabled; otherwise, it has no effect.

### Set Command

```
trans_cmd_string.cgi?cmd=2123&command=$command&sensor=${sensor}&
${reignString}reign0=${records[0]}&
${reignString}reign1=${records[1]}&
...
${reignString}reign17=${records[17]}&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| records | List | Drawing area data. List values correspond to each row's painted area converted from binary to decimal |
| command | int | 0: Motion detection, 2: Human detection, 4: Absence detection, 6: Face detection, 8: Face recognition area |
| sensor | int | 0: Single lens, 1: Dual lens, 2: Triple lens, 3: Quad lens |
| reignString | String | `"md_"`: Motion detection, `"pd_"`: Human detection, `"depart_"`: Absence detection area, `"face_detect_"`: Face detection area, `"face_recognition_"`: Face recognition area |

### Records Calculation Reference

Initialize a 2D list of size 18x22, fill with 1s, then change elements to 0 based on the painted area. Then treat each row as a binary number and convert to decimal using the pow function.

```dart
var data = [];
// Drawing area matrix 18 * 22
for (int i = 0; i < 18; i++) {
  List element = [];
  for (int j = 0; j < 22; j++) {
    element.add(1);
  }
  data.add(element);
}

// Painted area values are 0
state.saveRectModels.forEach((element) {
  data[element.row][element.colum] = 0;
});

List records = [];
for (int i = 0; i < data.length; i++) {
  int total = 0;
  int length = data[i].length;
  List list = data[i];
  list = list.reversed.toList();
  for (int j = 0; j < length; j++) {
    total = total + list[j] * pow(2, j);
  }
  records.add(total);
}
```

### Get Detection Area

**Command:** `trans_cmd_string.cgi?cmd=2123&command=$command&sensor=$sensor&`

| Parameter | Type | Description |
|-----------|------|-------------|
| command | int | 1: Motion detection, 3: Human detection |
| sensor | int | 0: Single lens, 1: Dual lens, 2: Triple lens, 3: Quad lens |

---

## 6. Image Quality

> Note: `support_pixel_shift == "1"` is required to support super high definition settings.

**Set Command:** `camera_control.cgi?param=16&value=$index&`

| Parameter | Type | Description |
|-----------|------|-------------|
| index | int | 4: Low, 2: General, 1: High, 100: Super HD |

**Notes:**
1. Settings are saved locally; initialize by retrieving from local storage. There is no command or field to get image quality.
2. If `(pixel == 200 && resolution == VideoResolution.superHD)` or `(pixel == 300 && resolution == VideoResolution.high)`, the device needs to restart for the image quality change to take effect.

---

## 7. Night Vision Mode

### Set Night Vision Mode

**Command:** `camera_control.cgi?param=33&value=$value&`

| Parameter | Type | Description |
|-----------|------|-------------|
| value | int | 0: Black & white mode, 1: Full color night vision, 2: Smart night vision |

> Note: When switching to full color night vision or smart night vision, black & white mode needs to be changed to black & white night vision.

**Command:** `camera_control.cgi?param=14&value=$value&`

| Parameter | Type | Description |
|-----------|------|-------------|
| value | int | 0: Starlight night vision, 1: Black & white night vision |

> Note: Before setting starlight night vision or black & white night vision, you must first switch to black & white mode.

### Get Night Vision Mode Status

**Command:** `get_camera_params.cgi?`

- `ircut`: 1 = Black & white, 0 = Starlight
- `night_vision_mode`: 0 = Black & white, 1 = Full color, 2 = Smart

---

## 8. Cloud Video Recording Switch

**Set Command:** `trans_cmd_string.cgi?cmd=2106&command=9&pirPushSwitch=1&pirPushSwitchVideo=1&`

> Note: Only low-power motion detection has this feature. If this feature is disabled, after triggering an alarm, only images can be seen in cloud playback, no video.

```dart
String cgi = "trans_cmd_string.cgi?cmd=2106&command=9&pirPushSwitch=${pushEnable ? 1 : 0}&pirPushSwitchVideo=${videoEnable ? 1 : 0}&";

if (videoDuration != -1) {
  cgi = "trans_cmd_string.cgi?cmd=2106&command=9&pirPushSwitch=${pushEnable ? 1 : 0}&pirPushSwitchVideo=${videoEnable ? 1 : 0}&CloudVideoDuration=${videoDuration ?? 15}&autoRecordMode=${autoRecordMode ?? 0}&";
}
```

| Parameter | Type | Description |
|-----------|------|-------------|
| pirPushSwitch | int | Push notification switch, default 1: on, 0: off |
| pirPushSwitchVideo | int | Cloud video recording switch: default 1: on, 0: off |
| CloudVideoDuration | int | Cloud video recording duration, default 15 seconds |
| autoRecordMode | int | Auto record mode, default 0 |

### Get Switch Status

**Command:** `trans_cmd_string.cgi?cmd=2106&command=8&`

Parse: `pirPushVideoEnable = data["pirPushSwitchVideo"] == "1";`

---

## 9. Zoom

### Check if Device Supports Zoom

Condition: `support_focus > 0` or `MaxZoomMultiple > 0` or `is4XDeviceByFirmware() == true`

```dart
// Device status listener callback, result => StatusResult
if (result.support_focus != null) {
  deviceModel.support_focus.value = int.tryParse(result.support_focus);
}
if (result.MaxZoomMultiple != null) {
  deviceModel.MaxZoomMultiple.value = int.tryParse(result.MaxZoomMultiple);
}
deviceModel.currentSystemVer.value = result.sys_ver;

bool is4XDeviceByFirmware() {
  List array = deviceModel?.currentSystemVer?.value != null
      ? deviceModel?.currentSystemVer?.value?.split(".")
      : null;
  if (array == null || array.length < 4) {
    array = ['0', '0', '0', '0'];
  }
  String second = array[1];
  if (second == '81' && array[2] != '176') {
    return true;
  }
  return false;
}
```

### Zoom Command

- If `MaxZoomMultiple > 0`: `decoder_control.cgi?command=84&param=$scale&`
- Otherwise: `decoder_control.cgi?command=${scale + 20}&onestep=0&`

| Parameter | Type | Description |
|-----------|------|-------------|
| scale | int | Default 1-4. If `MaxZoomMultiple > 0`, then 1 to `MaxZoomMultiple` |

### Get Initial Zoom Value

Use `CurZoomMultiple` field from device status listener callback.

---

## 10. Siren Command

> Note: Siren turns off automatically after 10 seconds. Cannot be enabled when battery is below 20%.

**Siren Switch:** `trans_cmd_string.cgi?cmd=2109&command=0&siren=$siren&`

| Parameter | Type | Description |
|-----------|------|-------------|
| siren | int | 1: On, 0: Off |

---

## 11. White Light Command

> Note: `hardwareTestFunc` indicates if the device supports white light. `support_manual_light` indicates if user manual control is supported (supported if no value or equals 1).

**Switch Setting:** `trans_cmd_string.cgi?cmd=2109&command=0&light=$light&`

| Parameter | Type | Description |
|-----------|------|-------------|
| light | int | 1: On, 0: Off |

> Note: Cannot be enabled when physical cover is on or battery is below 20%.

### Get White Light Switch Status

**Command:** `trans_cmd_string.cgi?cmd=2109&command=2&`

`lightSwitch = data["lightStatus"] == "1"`

---

## 12. Human Shape Frame Command

> Notes:
> 1. If `result.support_PeopleDetection` has a value, you need to disable human shape framing before disabling human detection, and enable human detection before enabling human shape framing.
> 2. Human shape framing is unavailable when physical cover is enabled.

**Switch Setting:** `trans_cmd_string.cgi?cmd=2126&command=0&bHumanoidFrame=$enable&`

| Parameter | Type | Description |
|-----------|------|-------------|
| enable | int | 1: Enable, 0: Disable |

### Get Human Shape Frame Switch Status

**Command:** `trans_cmd_string.cgi?cmd=2126&command=1&`

`humanFrameEnable = int.tryParse(data["bHumanoidFrame"] ?? "0")`

---

## 13. Human Shape Detection Command

**Switch Setting:** `trans_cmd_string.cgi?cmd=2106&command=4&humanDetection=$pirLevel&DistanceAdjust=$distanceAdjust&HumanoidDetection=$value&`

| Parameter | Type | Description |
|-----------|------|-------------|
| pirLevel | int | Human detection sensitivity 1-3 (should match the setting value) |
| distanceAdjust | int | Human detection distance 1-3 (should match the setting value) |
| value | int | Human detection switch, 1: On, 0: Off |

---

## 14. Get TF Card Playback Data Command

### Get Data for Specific Date

**Command:** `get_record_file.cgi?GetType=file&dirname=$dirname&`

| Parameter | Type | Description |
|-----------|------|-------------|
| dirname | String | Date YYYYMMDD, e.g., `20230322` |

### Paginated Data Retrieval

**Command:** `get_record_file.cgi?PageSize=$pageSize&PageIndex=$pageIndex&`

| Parameter | Type | Description |
|-----------|------|-------------|
| pageSize | int | Data amount per page |
| pageIndex | int | Page number, starting from 0 |

### Timeline Segmented Data Retrieval

**Command:** `get_record_idx.cgi?dirname=$date&offset=$offset`

| Parameter | Type | Description |
|-----------|------|-------------|
| date | String | Date YYYYMMDD, e.g., `20230322` |
| offset | int | Start from 0; when data byte length equals 60012, increment by 1 |

### List Video Download (Play Download)

**Command:** `livestream.cgi?streamid=4&filename=$recordName&offset=0&download=1&`

| Parameter | Type | Description |
|-----------|------|-------------|
| recordName | String | Recording file name |

### Timeline Video Download (Play Download)

**Command:** `livestream.cgi?streamid=5&ntsamp=$timestamp&event=$event&framenum=$frameNo&recch=$channel&key=$key&`

| Parameter | Type | Description |
|-----------|------|-------------|
| timestamp | int | Recording timestamp, corresponds to `RecordTimeLineModel.recordTime` |
| event | int | Event: 0 = Real-time recording, 1 = Alarm recording, 2 = Human alarm. Corresponds to `RecordTimeLineModel.recordAlarm` |
| frameNo | int | Keyframe sequence number |
| channel | int | 2 or 3, default 4 |
| key | int | Random number: `Random().nextInt(9999)` |

### Stop Recording File Download

**Command:** `livestream.cgi?streamid=17&`

### Timeline File Download

**Command:** `record_fastplay.cgi?ctrl=1&playlist=${jsonEncode(data)}&`

| Parameter | Type | Description |
|-----------|------|-------------|
| data | Map | `data["download"] = filesList`. Example: `filesList = [{"f": name, "s": start, "e": end}, ...]` where `name` is filename, `start` is start time, `end` is end time |

### Stop Timeline File Download

**Command:** `record_fastplay.cgi?ctrl=0&`

### Delete Specific File

**Command:** `del_file.cgi?name=$recordName&`

| Parameter | Type | Description |
|-----------|------|-------------|
| recordName | String | Recording file name |

### Get Recording Video Dates

**Command:** `get_record_file.cgi?GetType=date&`

---

## 15. Human Shape Tracking

> Note: If human detection is supported, human shape tracking is also supported.

**Set Command:** `trans_cmd_string.cgi?cmd=2127&command=0&enable=$enable&`

| Parameter | Type | Description |
|-----------|------|-------------|
| enable | int | 1: Enable, 0: Disable |

### Get Switch Status

**Command:** `trans_cmd_string.cgi?cmd=2127&command=1&`

`humanTrackingEnable = int.tryParse(data["enable"] ?? "0")`

---

## 16. Red-Blue Light

**Support Condition:** `hardwareTestFunc & 0x200 != 0`

### Switch Setting

**Command:** `trans_cmd_string.cgi?cmd=2109&command=0&alarmLed=$value&`

| Parameter | Type | Description |
|-----------|------|-------------|
| value | int | 1: Enable, 0: Disable |

### Get Switch Status

**Command:** `trans_cmd_string.cgi?cmd=2109&command=2&`

### Mode Setting

**Command:** `trans_cmd_string.cgi?cmd=2108&command=1&alarmLedMode=$mode&`

| Parameter | Type | Description |
|-----------|------|-------------|
| mode | int | 1: Linked with alarm, 0: Not linked |

### Get Mode

**Command:** `trans_cmd_string.cgi?cmd=2108&command=0&`

---

## 17. Alarm Flash Light

> Note: `hardwareTestFunc` indicates if the device supports white light. If supported, alarm flash light can be enabled.

**Switch Command:** `trans_cmd_string.cgi?cmd=2108&command=1&lightMode=$light&`

| Parameter | Type | Description |
|-----------|------|-------------|
| light | int | 0: Off, 1: On without flashing (white light), 2: On with flashing |

### Get Switch Status

**Command:** `trans_cmd_string.cgi?cmd=2108&command=0&`

---

## 18. Control Joystick

### Direction Commands

- **Left:** `decoder_control.cgi?command=4&onestep=0&`
- **Right:** `decoder_control.cgi?command=6&onestep=0&`
- **Up:** `decoder_control.cgi?command=0&onestep=0&`
- **Down:** `decoder_control.cgi?command=2&onestep=0&`

```dart
if (currBinocular != null) {
  _cgi = _cgi + "curr_binocular=$currBinocular&";
}
if (motorSpeed != null) {
  _cgi = _cgi + "motor_speed=$motorSpeed&";
}
```

| Parameter | Type | Description |
|-----------|------|-------------|
| command | int | 0: Up, 2: Down, 4: Left, 6: Right |
| currBinocular | int | 0: First lens, 1: Second lens |
| motorSpeed | int | 1-10, where 1 is slowest, 10 is fastest |

### Stop Commands

- **Stop Left:** `decoder_control.cgi?command=5&onestep=0&`
- **Stop Right:** `decoder_control.cgi?command=7&onestep=0&`
- **Stop Up:** `decoder_control.cgi?command=1&onestep=0&`
- **Stop Down:** `decoder_control.cgi?command=3&onestep=0&`

---

## 19. Video Recording Duration

### Long-Power Device Command

```dart
cgi = "set_alarm.cgi?enable_alarm_audio=0&motion_armed=${enable ? 1 : 0}&motion_sensitivity=$level&CloudVideoDuration=$videoDuration&"
"input_armed=1&ioin_level=0&iolinkage=0&ioout_level=0&preset=0&mail=0&snapshot=1&"
"record=1&upload_interval=0&schedule_enable=1&schedule_sun_0=$plan&schedule_sun_1=$plan&"
"schedule_sun_2=$plan&schedule_mon_0=$plan&schedule_mon_1=$plan&schedule_mon_2=$plan&"
"schedule_tue_0=$plan&schedule_tue_1=$plan&schedule_tue_2=$plan&schedule_wed_0=$plan&"
"schedule_wed_1=$plan&schedule_wed_2=$plan&schedule_thu_0=$plan&schedule_thu_1=$plan&"
"schedule_thu_2=$plan&schedule_fri_0=$plan&schedule_fri_1=$plan&schedule_fri_2=$plan&"
"schedule_sat_0=$plan&schedule_sat_1=$plan&schedule_sat_2=$plan&defense_plan1=0&"
"defense_plan2=0&defense_plan3=0&...&defense_plan21=0&";
```

| Parameter | Type | Description |
|-----------|------|-------------|
| enable | bool | true: Enable, false: Disable |
| level | int | Detection sensitivity value |
| videoDuration | int | Video duration: -1 (not set), 5, 10, 15, 30 |
| plan | int | When `enable == true`: -1, otherwise: 0 |

### Low-Power Device Command

```dart
cgi = "trans_cmd_string.cgi?cmd=2106&command=9&pirPushSwitch=${pushEnable ? 1 : 0}&pirPushSwitchVideo=${videoEnable ? 1 : 0}&CloudVideoDuration=${videoDuration ?? 15}&autoRecordMode=${autoRecordMode ?? 0}&";
```

| Parameter | Type | Description |
|-----------|------|-------------|
| pushEnable | bool | true: Enable, false: Disable |
| videoEnable | bool | true: Enable, false: Disable |
| videoDuration | int | Video duration: 5, 10, 15, 30 |
| autoRecordMode | int | Auto: 1, otherwise: 0 |

### Get Status

1. **Command:** `get_params.cgi?` to get `CloudVideoDuration`
2. **Command:** `trans_cmd_string.cgi?cmd=2106&command=8&` to get `autoRecordMode`

- `videoDuration = int.tryParse(data["CloudVideoDuration"] ?? "15");`
- `autoRecordVideoMode = int.tryParse(data["autoRecordMode"] ?? "0");`

---

## 20. Smart Detection Timing

### Set Command

```dart
"trans_cmd_string.cgi?cmd=2017&command=2&mark=212&"
"motion_push_plan1=${records[0]}&"
"motion_push_plan2=${records[1]}&"
...
"motion_push_plan21=${records[20]}&"
"motion_push_plan_enable=$enable&"
```

| Parameter | Type | Description |
|-----------|------|-------------|
| records | List\<int\> | Length must be 21, default value -1. Set value is the weighted sum of corresponding times |
| enable | int | 1: Motion, 5: Human shape |

**All-day Detection:** No need to set, use default values

### Daytime Only Detection

From 8:00 AM to 8:00 PM

```dart
int startTime = 480;
int endTime = 1200;
List weeks = [7, 1, 2, 3, 4, 5, 6];
PlanModel model = PlanModel.fromPlans(startTime, endTime, weeks, state.deviceModel.id);
var actionPlans = <PlanModel>[];
actionPlans.add(model);
List records = [];
actionPlans.forEach((element) {
  records.add(element.sum);
});
if (records.length < 21) {
  int num = 21 - records.length;
  for (int i = 0; i < num; i++) {
    records.add(-1);
  }
}
```

### Nighttime Only Detection

From 8:00 PM to 8:00 AM next day

```dart
int startTime = 1200;
int endTime = 480;
// ... same logic as daytime
```

### Custom Detection

Same logic as daytime/nighttime detection, based on user-selected `startTime`, `endTime`, and `weeks`.

### Get Alarm Plan

**Command:** `trans_cmd_string.cgi?cmd=2017&command=11&mark=212&type=2&`

---

## 21. Alarm Sound Settings

> Notes:
> 1. Audio format requirements: `.wav` suffix, single channel, 16bit, 8000Hz, g711a
> 2. Alarm sound is unavailable when battery is below 20%

### Set Command

```dart
String cgi = "trans_cmd_string.cgi?cmd=2135&command=0&urlJson=$urlJson&filename=$voiceName&switch=$switch&voicetype=$voicetype&"

if (playInDevice == true) {
  cgi = cgi + "play=1&" + "playtimes=$playTimes&";
} else {
  cgi = cgi + "playtimes=$playTimes&";
}
```

| Parameter | Type | Description |
|-----------|------|-------------|
| switch | int | 1: On, 0: Off |
| voicetype | int | 0: Face detection alarm, 1: Human detection alarm, 2: Smoke alarm, 3: Motion detection alarm, 4: Absence detection, 5: Cry detection, 6: Presence monitoring, 7: Smoke camera flame, 8: Smoke camera smoke |
| urlJson | String | `var dic = {"url": voiceUrl}; urlJson = json.encode(dic);` |
| voiceName | String | Filename |
| play | int | 1: Play |
| playtimes | String | Recommended: "3" |

### Disable Command

`trans_cmd_string.cgi?cmd=2135&command=0&switch=$switch&voicetype=$voicetype&`

### Get Sound Type

**Command:** `trans_cmd_string.cgi?cmd=2135&command=1&voicetype=$voiceType&`

---

## 22. TF Card Audio Recording Switch

**Set Command:** `set_recordsch.cgi?record_audio=1&`

| Parameter | Type | Description |
|-----------|------|-------------|
| record_audio | int | 1: On, 0: Off |

### Get Status

**Command:** `get_record.cgi?`

---

## 23. TF Card Recording Mode

> Notes:
> 1. Only long-power devices support this, and TF status must be 1 or 2
> 2. When not recording, scheduled recording, all-day recording, and motion detection recording should all be disabled
> 3. Scheduled, all-day, and motion detection recording cannot coexist; enabling one requires disabling the others

### Scheduled Recording

```dart
"trans_cmd_string.cgi?cmd=2017&command=3&mark=212&"
"record_plan1=${records[0]}&"
...
"record_plan21=${records[20]}&"
"record_plan_enable=$enable&"
```

`enable` → 1: Record, 0: Don't record. `records` values reference Smart Detection Timing.

### Motion Detection Recording

```dart
"trans_cmd_string.cgi?cmd=2017&command=1&mark=212&"
"motion_record_plan1=${records[0]}&"
...
"motion_record_plan21=${records[20]}&"
"motion_record_plan_enable=$enable&"
```

`enable` → 1: Record, 0: Don't record. `records` values are -1, or can be scheduled plan values.

### All-Day (24-hour) Recording

```dart
var value = enable == 1 ? -1 : 0;
"set_recordsch.cgi?record_cover=1&"
"record_timer=$record_timer&"
"time_schedule_enable=$enable&"
"schedule_sun_0=$value&"
...
"schedule_sat_2=$value&"
"record_audio=$record_audio&"
```

| Parameter | Type | Description |
|-----------|------|-------------|
| enable | int | 1: Enable, 0: Disable |
| record_timer | String | Recording duration |
| record_audio | String | "1": Record audio, "0": Don't record |
| value | int | -1 when enabled, 0 when disabled |

### Get Recording Status

- **Scheduled:** `trans_cmd_string.cgi?cmd=2017&command=11&mark=212&type=3&` → `record_plan_enable`
- **Motion Detection:** `trans_cmd_string.cgi?cmd=2017&command=11&mark=212&type=1&` → `motion_record_enable`
- **All-Day:** `get_record.cgi?` → `record_time_enable`

---

## 24. TF Card Recording Time

**Set Command:** `trans_cmd_string.cgi?cmd=2204&command=2&record_resolution=$resolution&`

| Parameter | Type | Description |
|-----------|------|-------------|
| resolution | int | 0: Main stream (Super HD) - shortest recording time, 1: Main stream (HD) - short recording time, 2: Sub stream (SD) - long recording time |

### Get Status

**Command:** `trans_cmd_string.cgi?cmd=2204&command=1&`

---

## 25. TF Card Formatting

**Set Command:** `set_formatsd.cgi?`

### Get Status

**Command:** `get_status.cgi?`

**Field:** `sdstatus`
- 1, 2: Normal
- 3: File system error
- 4: Formatting
- 5: Not mounted

---

## 26. Linkage Calibration (Dual-lens)

> Note: Supported when `support_pininpic == 1` (supports multi-lens) or `support_mutil_sensor_stream == 1` or `== 2` (dual-lens)

### 1. Linkage Calibration Switch

**Command:** `trans_cmd_string.cgi?cmd=4101&command=1&gblinkage_enable=$enable&`

| Parameter | Type | Description |
|-----------|------|-------------|
| enable | int | 1: Enable, 0: Disable |

### Get Switch Status

**Command:** `trans_cmd_string.cgi?cmd=4101&command=0&`

`gblinkage_enable`: 0 = Don't display, 1 = Enabled, 2 = Disabled

### 2. Linkage Calibration - PTZ Reset

**Reset Command:** `trans_cmd_string.cgi?cmd=4100&command=0&`

**Query Reset Completion:** `trans_cmd_string.cgi?cmd=4100&command=1&`

### 3. Linkage Calibration - Image Correction

**Command:** `camera_control.cgi?param=40&value=0&x_percent=${x_percent}&y_percent=${y_percent}`

| Parameter | Type | Description |
|-----------|------|-------------|
| x_percent | int | Correction position X-axis ratio: 1-100 |
| y_percent | int | Correction position Y-axis ratio: 1-100 |

### 4. Linkage Calibration - Linkage Coordinate Setting

**Command:** `camera_control.cgi?param=39&value=0&x_percent=${x_percent}&y_percent=${y_percent}`

---

## 27. Dual/Triple Lens Judgment Conditions

1. If `splitScreen` is null and `support_mutil_sensor_stream` has value 1 or 2: **Dual-lens**
2. If both `support_mutil_sensor_stream` and `splitScreen` have values (split screen): **Triple-lens**

### Creating Bullet Camera Player

```dart
// First
var subController = AppPlayerController();
var result = await subController.create();
result = await subController.setVideoSource(SubPlayerSource());
await subController.start();
result = await controller!.enableSubPlayer(subController);

// Second
var sub2Controller = AppPlayerController();
var result = await sub2Controller.create();
result = await sub2Controller.setVideoSource(SubPlayerSource());
await sub2Controller.start();
result = await controller!.enableSub2Player(sub2Controller);
```

---

## 28. Human Shape Zoom Tracking

**Support Check Field:** `support_humanoid_zoom`

### Get Switch Status

**Command:** `trans_cmd_string.cgi?cmd=2126&command=1&`

### Set Switch

**Command:** `trans_cmd_string.cgi?cmd=2126&command=0&humanoid_zoom=$enable&`

| Parameter | Type | Description |
|-----------|------|-------------|
| enable | int | 1: On, 0: Off |

---

## 29. Screenshot Command

- **Single-lens:** `snapshot.cgi?res=1&`
- **Dual-lens:** `snapshot.cgi?sensor=$sensor&` (sensor=0: PTZ camera, 1: Bullet camera)

---

## 30. Video Flip

**Set Command:** `camera_control.cgi?param=5&value=$value&`

| Parameter | Type | Description |
|-----------|------|-------------|
| value | int | 0: No flip, 3: Vertical flip |

### Get Status

**Command:** `get_camera_params.cgi?`

**Field:** `flip` (no value means 0)

---

## 31. Light Anti-interference

**Set Command:** `camera_control.cgi?param=3&value=$value&`

| Parameter | Type | Description |
|-----------|------|-------------|
| value | int | 0: 50Hz, 1: 60Hz |

### Get Status

**Command:** `get_camera_params.cgi?`

**Field:** `mode` (no value means 0)

---

## 32. Video Time Display

**Set Command:** `set_misc.cgi?osdenable=$value&`

| Parameter | Type | Description |
|-----------|------|-------------|
| value | int | 1: Display, 0: Hide |

### Get Status

**Command:** `get_status.cgi?`

**Field:** `osdenable`

---

## 33. Remote Power On/Off

> Notes:
> - Not supported when device is in deep sleep
> - Ensure connection before remote shutdown; actively disconnect after successful shutdown
> - For remote power on: First wake up the device, connect, then call the command

### Check Support

**Command:** `get_status.cgi?`

**Field:** `support_Remote_PowerOnOff_Switch`

### Set Command

`trans_cmd_string.cgi?cmd=2106&command=13&PowerSwitch=$open&`

| Parameter | Type | Description |
|-----------|------|-------------|
| open | int | 1: Power off, 0: Power on |

### Get Power Status

**Command:** `trans_cmd_string.cgi?cmd=2106&command=14&`

**Field:** `PowerSwitch`

---

## 34. WiFi QR Code Network Configuration

### QR Code Format

> Note: Append `-OEM` after userId

```dart
qrContent = '{"BS":"$bssid","P":"$pwd","U":"${userId}-OEM","RS":"$ssid"}';
```

| Parameter | Type | Description |
|-----------|------|-------------|
| bssid | String | WiFi BSSID information |
| pwd | String | WiFi password |
| ssid | String | WiFi SSID information (WiFi name) |
| userId | String | User unique identifier, e.g., "2384782" |

### Query Successfully Connected Devices

**Request Method:** POST

**Request URL:** `https://api.eye4.cn/hello/query`

**Request Parameters:** `{"key": key}`

| Parameter | Type | Description |
|-----------|------|-------------|
| key | String | `${userId}-OEM_binding` (userId = user unique identifier) |

**Success Response:** `{"value":"VE0005622QHOW"}`

**Failure Response:** `{"msg":"Not found","code":404}`

### Delete Server-Saved Connected Device

**Request Method:** POST

**Request URL:** `https://api.eye4.cn/hello/confirm`

**Request Parameters:** `{"key": key}`

### Check if Device is Our Camera

```dart
bool isBlueDev(String name) {
  if (name.startsWith("IPC-")) {
    name = name.replaceAll('IPC-', '');
  } else if (name.startsWith("MC-")) {
    name = name.replaceAll('MC-', '');
  } else if (name.startsWith("VP-")) {
    name = name.replaceAll('VP-', '');
  } else {
    return false;
  }
  RegExp exp = RegExp(r'^[a-zA-Z]{1,}\d{7,}.*[a-zA-Z]$');
  bool isVirtualId = exp.hasMatch(name);
  return isVirtualId;
}
```

---

## 35. Bluetooth Network Configuration

**Service UUID:** `0000FFF0-0000-1000-8000-00805F9B34FB` → 1800

**Characteristics UUID:** `0000FFF1-0000-1000-8000-00805F9B34FB` → 1801

### 1. Get WiFi List Protocol

- **Send:** `0xFF 0xFF`
- **Receive:** `0xF0 0xF3` (one packet length 40)
- **Reply:** `0xFF index`
- **End:** `index = 10000`

### 2. Bluetooth Network Configuration Protocol

| Packet | Send | Receive |
|--------|------|---------|
| First | `[0xF0, 0xF0]` + 118 | `[0xF0, 0xF0]` |
| Second | `[0xF0, 0xF1]` + 36 | `[0xF0, 0xF1]` |
| Third (result) | - | `[0xF0, 0xF2]` + status |

**Status Codes:**
- 0: Network connection successful
- 1: Wrong password
- 2: Connection timeout
- 3: DHCP failed
- 4: Gateway configuration failed

---

## 36. Firmware Version Update

### 1. Get Latest Version by Current Version

First get current version using `get_status.cgi` (field: `sys_ver`)

**Request URL:** `http://api4.eye4.cn:808/firmware/${currentVersion}/cn`

**Response:**

```json
{
  "name": "47.1.8.14",
  "MD5": "0DB3C057ADC28FBA46C63D89BF55ED89",
  "en": "",
  "zh": "",
  "download_file": "/firmware_47.1.8.14_1582342675.bin",
  "Size": "1255424",
  "download_server": "doraemon.ipcam.so"
}
```

### 2. Update Firmware

**Command:** `auto_download_file.cgi?server=$server&file=$file&type=0&resevered1=&resevered2=&resevered3=&resevered4=&`

| Parameter | Type | Description |
|-----------|------|-------------|
| file | String | Corresponds to `download_file` |
| server | String | Corresponds to `download_server` |

---

## 37. Switch Device WiFi

### 1. Get Device WiFi List

1. `wifi_scan.cgi?`
2. `get_wifi_scan_result.cgi?`

### 2. Switch Device WiFi

**Domestic:**
```
set_wifi.cgi?ssid=${Uri.encodeQueryComponent(info.ssid)}&channel=${info.channel}&authtype=${info.security}&wpa_psk=${Uri.encodeQueryComponent(password)}&enable=1&
```

**International:**
```
set_wifi.cgi?ssid=${Uri.encodeQueryComponent(info.ssid)}&channel=${info.channel}&authtype=${info.security}&wpa_psk=${Uri.encodeQueryComponent(password)}&enable=1&$area&
```

---

## 38. AI Smart Services

### Get AI Service Status Data

**Command:** `trans_cmd_string.cgi?cmd=2400&command=1&AiType=$aiType&`

### Set AI Service Data

**Command:** `trans_cmd_string.cgi?cmd=2400&command=0&AiType=$aiType&AiCfg=$aiConfigString&`

| Parameter | Type | Description |
|-----------|------|-------------|
| aiType | int | 0: Area intrusion, 1: Person loitering, 2: Illegal parking, 3: Line crossing, 4: Absence, 5: Wrong-way driving, 6: Package detection, 7: Fire/smoke detection |
| aiConfigString | String | JSON string corresponding to each type's model data |

### AI Service Data Types

#### 1. Area Intrusion

```json
{
  "enable": 0,
  "object": 1,
  "region": [{"point": [{"x": "0.126563", "y": "0.225"}, ...]}],
  "sensitive": 2,
  "lightLed": 0,
  "areaframe": 1
}
```

| Field | Type | Description |
|-------|------|-------------|
| enable | int | 0: Disable, 1: Enable |
| object | int | Target type: 1=Person, 2=Vehicle, 3=Person+Vehicle, 4=Pet, 5=Person+Pet, 6=Vehicle+Pet, 7=Person+Vehicle+Pet |
| region | list | Alert area |
| sensitive | int | Sensitivity: 1-3 |
| lightLed | int | Flash light: 0=Off, 1=On |
| areaframe | int | Target frame and detection rules: 0=Off, 1=On |

#### 2. Person Loitering

| Field | Type | Description |
|-------|------|-------------|
| enable | int | 0: Disable, 1: Enable |
| staytime | int | Maximum stay time: 30-3600 seconds |
| region | list | Alert area |
| sensitive | int | Sensitivity: 1-3 |
| lightLed | int | Flash light: 0=Off, 1=On |
| areaframe | int | Target frame and detection rules: 0=Off, 1=On |

#### 3. Illegal Parking

Same structure as Person Loitering.

#### 4. Line Crossing Detection

| Field | Type | Description |
|-------|------|-------------|
| enable | int | 0: Disable, 1: Enable |
| object | int | Target type (same as Area Intrusion) |
| crosslineArr | list | Line crossing area array with direction |
| sensitive | int | Sensitivity: 1-3 |
| lightLed | int | Flash light: 0=Off, 1=On |
| areaframe | int | Target frame and detection rules: 0=Off, 1=On |

#### 5. Absence Detection

| Field | Type | Description |
|-------|------|-------------|
| enable | int | 0: Disable, 1: Enable |
| leavetime | int | Maximum leave time: 30-3600 seconds |
| sumperson | int | Number of people on duty: 1, 2, 3 |
| region | list | Alert area |
| sensitive | int | Sensitivity: 1-3 |
| lightLed | int | Flash light: 0=Off, 1=On |
| areaframe | int | Target frame and detection rules: 0=Off, 1=On |

#### 6. Wrong-Way Driving

Similar structure to Line Crossing with direction-based detection.

#### 7. Package Detection

| Field | Type | Description |
|-------|------|-------------|
| appearEnable | int | Package appearance: 0=Off, 1=On |
| disappearEnable | int | Package disappearance: 0=Off, 1=On |
| stayEnable | int | Package loitering: 0=Off, 1=On |
| region | list | Alert area |
| stayTime | int | Loitering time in seconds (10min, 30min, 1hr, 6hr, 12hr, 24hr, 48hr, 72hr) |
| sensitive | int | Sensitivity: 1-3 |
| appearLightLed | int | Package appear flash: 0=Off, 1=On |
| disappearLightLed | int | Package disappear flash: 0=Off, 1=On |
| stayLightLed | int | Package loiter flash: 0=Off, 1=On |
| areaframe | int | Target frame and detection rules: 0=Off, 1=On |

#### 8. Fire Detection

| Field | Type | Description |
|-------|------|-------------|
| fireEnable | int | Fire detection switch: 0=Off, 1=On |
| smokeEnable | int | Smoke detection switch: 0=Off, 1=On |
| sensitive | int | Sensitivity: 1-3 |
| fireLightLed | int | Fire flash light: 0=Off, 1=On |
| smokeLightLed | int | Smoke flash light: 0=Off, 1=On |
| firePlace | int | Use scenario: 0=Indoor, 1=Outdoor |
| areaframe | int | Target frame and detection rules: 0=Off, 1=On |

### Set AI Detection Plan

**Command:**

```dart
"trans_cmd_string.cgi?cmd=2017&command=$type&mark=1&"
"${typeString}_plan1=${records[0]}&"
...
"${typeString}_plan21=${records[20]}&"
"${typeString}_plan_enable=$enable&"
```

| type | typeString |
|------|------------|
| 12 | fire |
| 14 | region_entry |
| 15 | person_stay |
| 16 | car_stay |
| 17 | line_cross |
| 18 | person_onduty |
| 19 | car_retrograde |
| 20 | package_detect |

### Get Detection Plan

**Command:** `trans_cmd_string.cgi?cmd=2017&command=11&mark=1&type=$type&`

| type | Description |
|------|-------------|
| 12 | Fire detection |
| 14 | Area intrusion |
| 15 | Person loitering |
| 16 | Illegal parking |
| 17 | Line crossing |
| 18 | Absence detection |
| 19 | Wrong-way driving |
| 20 | Package detection |
