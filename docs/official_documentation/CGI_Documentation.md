# CGI Documentation

## Table of Contents

1. [Power Mode](#1-power-mode)
2. [Device Volume](#2-device-volume)
3. [Hide Indicator Light](#3-hide-indicator-light)
4. [PTZ](#4-ptz)
5. [Activity Zone](#5-activity-zone)
6. [Resolution](#6-resolution)
7. [Night Vision Setting](#7-night-vision-setting)
8. [Cloud Video Recording Switch](#8-cloud-video-recording-switch)
9. [Zoom](#9-zoom)
10. [Alarm](#10-alarm)
11. [White Light](#11-white-light)
12. [Human Frame](#12-human-frame)
13. [Human Detection](#13-human-detection)
14. [TF Playback Data](#14-tf-playback-data)
15. [Person Tracking](#15-person-tracking)
16. [Red & Blue Lights](#16-red--blue-lights)
17. [Alarm Flashing Light](#17-alarm-flashing-light)
18. [Virtual Joystick](#18-virtual-joystick)
19. [Recording Duration](#19-recording-duration)
20. [Detection Schedule](#20-detection-schedule)
21. [Alarm Sound](#21-alarm-sound)
22. [TF Card Sound Recording](#22-tf-card-sound-recording)
23. [TF Card Recording Mode](#23-tf-card-recording-mode)
24. [TF Card Recording Time](#24-tf-card-recording-time)
25. [TF Card Format](#25-tf-card-format)
26. [Linkage Correction (Two Sensors)](#26-linkage-correction-two-sensors)
27. [Multi Sensor Camera](#27-multi-sensor-camera)
28. [Humanoid Zoom Tracking](#28-humanoid-zoom-tracking)
29. [Screenshot](#29-screenshot)
30. [Video Flipping](#30-video-flipping)
31. [Light Anti-interference](#31-light-anti-interference)
32. [Video Time Display](#32-video-time-display)
33. [Remote Power On/Off](#33-remote-power-onoff)
34. [QR Code Network Connection](#34-qr-code-network-connection)
35. [Bluetooth Network Connection](#35-bluetooth-network-connection)
36. [Update Firmware Version](#36-update-firmware-version)
37. [Switching Device WiFi](#37-switching-device-wifi)
38. [AI Smart Service](#38-ai-smart-service)

---

## 1. Power Mode

> **Note:** Electric corded cameras do not have this functionality.

### Setting Power Mode

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2106&command=2&lowPower=$value
```

| Parameter | Type | Description |
|-----------|------|-------------|
| value | int | 0: Keep working mode, 30: Power saving mode, 10000: Super power saving mode |

### Getting Current Power Mode

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2106&command=1&
```

**Response:** `data["lowPower"]` => 0, 30, or 10000

### Smart Sleep Mode

> **Note:** Use `get_status.cgi?` to get the `supportSmartElectricitySleep` value. If value == 1, the device supports smart sleep mode. You should turn off smart sleep mode when switching to other modes.

#### Setting Smart Sleep Mode

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2106&command=18&Smart_Electricity_Sleep_Switch=$enable&Smart_Electricity_Threshold=$electricityThreshold&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| enable | int | 1: Turn on, 0: Turn off |
| electricityThreshold | int | Battery threshold (e.g., 30) |

#### Getting Smart Sleep Mode

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2106&command=17&
```

**Response Fields:** `Smart_Electricity_Sleep_Switch`, `Smart_Electricity_Threshold`

---

## 2. Device Volume

### Setting Volume

**CGI Command:**
```
camera_control.cgi?param=$param&value=$value&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| param | int | 24: Microphone, 25: Horn |
| value | int | 0-31: Volume range value |

### Getting Volume Value

**CGI Command:**
```
get_camera_params.cgi?
```

**Response Fields:**
- Microphone: `involume`
- Horn: `outvolume`

### Checking Horn Support

**CGI Command:**
```
get_status.cgi?
```

**Response:** `haveHorn` == "1" means horn is supported

---

## 3. Hide Indicator Light

### Setting Indicator Light

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2125&command=0&hide_led_disable=${hide == true ? 1 : 0}&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| hide_led_disable | int | 1: Hide, 0: Unhide |

### Getting Indicator Light Status

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2125&command=1&
```

**Response:** `hideLed = data["hide_led_disable"] == "1"`

---

## 4. PTZ

### 4.1 Vertical Cruise

**Turn On:**
```
decoder_control.cgi?command=26&onestep=0&
```

**Turn Off:**
```
decoder_control.cgi?command=27&onestep=0&
```

**Status Field:** `preset_cruise_status_v` => 1: On, 0: Off

### 4.2 Horizontal Cruise

**Turn On:**
```
decoder_control.cgi?command=28&onestep=0&
```

**Turn Off:**
```
decoder_control.cgi?command=29&onestep=0&
```

**Status Field:** `preset_cruise_status_h` => 1: On, 0: Off

### 4.3 Pre-position Cruise

**Turn On:**
```
decoder_control.cgi?command=22&onestep=0&
```

**Turn Off:**
```
decoder_control.cgi?command=23&onestep=0&
```

**Status Fields:**
- `preset_cruise_status` => 1: On, 0: Off
- `preset_cruise_curpos` => -1: Off, 0-4: Position

### 4.4 PTZ Correction

> **Note:** This feature is not available if the device's battery level is below 20%.

**Turn On:**
```
decoder_control.cgi?command=25&onestep=0&
```

**Status Field:** `center_status`

### 4.5 Pre-position (Five Positions)

**CGI Command:**
```
decoder_control.cgi?command=$cmd&onestep=0&
```

| Operation | Command Values |
|-----------|----------------|
| Setting | 30, 32, 34, 36, 38 |
| Cruising | 31, 33, 35, 37, 39 |
| Deleting | 62, 63, 64, 65, 66 |

> **Note:** It is recommended to save frequently viewed images to your own server and retrieve them when needed.

### 4.6 Caretaker

**CGI Command:**
```
set_sensor_preset.cgi?sensorid=255&presetid=$index&
```

- `index`: 1-5 (0 is turn off)

> **Note:** You need to set up pre-position before setting up caretaker position. The caretaker position should be selected from the pre-positions.

### 4.7 Get Pre-position Index Value (Method 1)

**CGI Command:**
```
get_status.cgi?
```

**Field:** `preset_value`

```dart
var list = presetValue
    .toRadixString(2)
    .padLeft(16, '0')
    .substring(0, 5)
    .split('')
    .toList();
```

Convert the value to binary characters, fill with 0 to 16 characters, take the first 5 characters, then convert to a list. Value 1 = set, 0 = unset.

### 4.8 Get Pre-position Index Value (Method 2)

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2161&command=0&
```

> **Note:** There are 16 preset position values total, with the first 5 being selected. Result of 1 indicates this index is set.

---

## 5. Activity Zone

> **Note:** Can only be set when motion detection is enabled.

### Setting Activity Zone

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2123&command=$command&sensor=${sensor}&
${reignString}reign0=${records[0]}&
${reignString}reign1=${records[1]}&
...
${reignString}reign17=${records[17]}&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| records | List | Area data values - binary to decimal conversion for each row |
| command | int | 0: Motion detection, 2: Human detection, 4: Off duty detection, 6: Face detection, 8: Facial recognition zone |
| sensor | int | 0: First sensor, 1: Second sensor, 2: Third sensor, 3: Fourth sensor |
| reignString | String | `md_`: Motion detection, `pd_`: Human detection, `depart_`: Off duty detection, `face_detect_`: Face detection, `face_recognition_`: Facial recognition |

#### Records Value Calculation

Initialize a 2D list (18×22) filled with 1s, then modify elements to 0 based on the applied area. Treat rows as binary numbers and convert to decimal:

```dart
var data = [];
// Create 18x22 matrix
for (int i = 0; i < 18; i++) {
    List elemen = [];
    for (int j = 0; j < 22; j++) {
        elemen.add(1);
    }
    data.add(elemen);
}

// Set drawn area values to 0
state.saveRectModels.forEach((element) {
    data[element.row][element.colum] = 0;
});

// Calculate decimal values
List records = [];
for (int i = 0; i < data.length; i++) {
    int total = 0;
    int length = data[i].length;
    List list = data[i].reversed.toList();
    for (int j = 0; j < length; j++) {
        total = total + list[j] * pow(2, j);
    }
    records.add(total);
}
```

### Getting Activity Zone Data

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2123&command=$command&sensor=$sensor&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| command | int | 1: Motion detection, 3: Human detection |
| sensor | int | 0: First sensor, 1: Second sensor, 2: Third sensor, 3: Fourth sensor |

---

## 6. Resolution

> **Note:** Use `get_status.cgi?` to get the `support_pixel_shift` value. If `support_pixel_shift == "1"`, the camera supports Super HD.

### Setting Resolution

**CGI Command:**
```
camera_control.cgi?param=16&value=$index&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| index | int | 4: Low, 2: General, 1: High, 100: Super HD |

> **Note:** 
> 1. Use `get_status.cgi?` to get the `pixel` value
> 2. If `(pixel == 200 && resolution == VideoResolution.superHD)` or `(pixel == 300 && resolution == VideoResolution.high)`, switching image quality requires restarting the device

---

## 7. Night Vision Setting

### Setting Night Vision

#### Color Mode Selection

**CGI Command:**
```
camera_control.cgi?param=33&value=$value&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| value | int | 0: Black and white mode, 1: Full color night vision, 2: Smart night vision |

> **Note:** When switching to full color or smart night vision, the black and white mode needs to be changed to black and white night vision first.

#### Starlight/Black & White Selection

**CGI Command:**
```
camera_control.cgi?param=14&value=$value&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| value | int | 0: Starlight night vision, 1: Black and white night vision |

> **Note:** Before setting starlight or black and white night vision, switch to black and white mode first.

### Getting Night Vision Settings

**CGI Command:**
```
get_camera_params.cgi?
```

**Response Fields:**
- `ircut` => 1: Black and white night vision (if night_vision_mode == 0), 0: Starlight night vision
- `night_vision_mode` => 0: Starlight/Black and white (check ircut), 1: Full color, 2: Smart night vision

---

## 8. Cloud Video Recording Switch

### Setting Cloud Video Recording

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2106&command=9&pirPushSwitch=1&pirPushSwitchVideo=1&
```

Full command with options:
```
trans_cmd_string.cgi?cmd=2106&command=9&pirPushSwitch=${pushEnable ? 1 : 0}&pirPushSwitchVideo=${videoEnable ? 1 : 0}&CloudVideoDuration=${videoDuration ?? 15}&autoRecordMode=${autoRecordMode ?? 0}&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| pirPushSwitch | int | Push switch: 1: On, 0: Off |
| pirPushSwitchVideo | int | Cloud video recording: 1: On, 0: Off |
| CloudVideoDuration | int | Cloud video time: 5s, 10s, 15s, 30s |
| autoRecordMode | int | Auto record mode: 0: Off |

> **Note:** Only low-power devices have this functionality when motion detection is enabled. If turned off, cloud playback shows only images, no videos after an alarm.

### Getting Cloud Video Recording Status

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2106&command=8&
```

**Response:** `pirPushVideoEnable = data["pirPushSwitchVideo"] == "1"`

---

## 9. Zoom

### Checking Zoom Support

**CGI Command:**
```
get_status.cgi?
```

The camera supports zoom if:
- `support_focus > 0`, OR
- `MaxZoomMultiple > 0`, OR
- `is4XDeviceByFirmware() == true`

```dart
bool is4XDeviceByFirmware() {
    List array = deviceModel?.currentSystemVer?.value?.split(".") ?? ['0', '0', '0', '0'];
    if (array.length < 4) array = ['0', '0', '0', '0'];
    String second = array[1];
    if (second == '81' && array[2] != '176') return true;
    return false;
}
```

### Setting Zoom

**CGI Command:**

If `MaxZoomMultiple > 0`:
```
decoder_control.cgi?command=84&param=$scale&
```

Otherwise:
```
decoder_control.cgi?command=${scale + 20}&onestep=0&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| scale | int | Default: 1-4. If MaxZoomMultiple > 0: 1 to MaxZoomMultiple |

### Getting Initial Zoom Value

**Field:** `CurZoomMultiple`

---

## 10. Alarm

> **Note:** The alarm automatically turns off after 10 seconds. Alarm cannot be turned on when battery level is below 20%.

### Setting Alarm

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2109&command=0&siren=$siren&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| siren | int | 1: Turn on, 0: Turn off |

---

## 11. White Light

> **Note:** 
> - If `hardwareTestFunc` indicates white light support, white light can be turned on
> - If `support_manual_light` has no value or equals 1, manual white light is supported
> - Cannot turn on when battery level is below 20%

### Setting White Light

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2109&command=0&light=$light&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| light | int | 1: Turn on, 0: Turn off |

### Getting White Light Status

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2109&command=2&
```

**Response:** `lightSwitch = data["lightStatus"] == "1"`

---

## 12. Human Frame

> **Notes:**
> 1. If `result.support_PeopleDetection` has a value: To close human frame, turn off human detection first. To open human frame, turn on human detection first.
> 2. Human framing is not available after enabling physical occlusion.

### Setting Human Frame

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2126&command=0&bHumanoidFrame=$enable&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| enable | int | 1: Turn on, 0: Turn off |

### Getting Human Frame Status

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2126&command=1&
```

**Response:** `humanFrameEnable = int.tryParse(data["bHumanoidFrame"] ?? "0")`

---

## 13. Human Detection

### Setting Human Detection

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2106&command=4&humanDetection=$pirLevel&DistanceAdjust=$distanceAdjust&HumanoidDetection=$value&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| pirLevel | int | Motion detection frequency: 1-3 |
| distanceAdjust | int | Detection distance: 1-3 |
| value | int | Human detection: 1: Turn on, 0: Turn off |

---

## 14. TF Playback Data

### Getting Data for Specified Date

**CGI Command:**
```
get_record_file.cgi?GetType=file&dirname=$dirname&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| dirname | String | Date string (e.g., "20230322") |

### Paging Data Retrieval

**CGI Command:**
```
get_record_file.cgi?PageSize=$pageSize&PageIndex=$pageIndex&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| pageSize | int | Data size per page |
| pageIndex | int | Page index (starts from 0) |

### Segmenting Data by Timeline

**CGI Command:**
```
get_record_idx.cgi?dirname=$date&offset=$offset
```

| Parameter | Type | Description |
|-----------|------|-------------|
| date | String | Date (e.g., "20230322") |
| offset | int | Starts from 0. When data byte length == 60012, increment by 1 |

### Downloading Video from List

**CGI Command:**
```
livestream.cgi?streamid=4&filename=$recordName&offset=0&download=1&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| recordName | String | File name |

### Downloading Video by Timeline

**CGI Command:**
```
livestream.cgi?streamid=5&ntsamp=$timestamp&event=$event&framenum=$frameNo&recch=$channel&key=$key&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| timestamp | int | Recording timestamp (corresponds to recordTime) |
| event | int | Record type: 0: Real-time, 1: Alarm, 2: Humanoid |
| frameNo | int | Keyframe number |
| channel | int | 2 or 3 (default 4) |
| key | int | Random number (0-9999) |

### Stop Video Download

**CGI Command:**
```
livestream.cgi?streamid=17&
```

### Timeline File Download

**CGI Command:**
```
record_fastplay.cgi?ctrl=1&playlist=${jsonEncode(data)}&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| data | Map | `data["download"] = filesList` where filesList = `[{"f": name, "s": start, "e": end}, ...]` |

### Stop Timeline File Download

**CGI Command:**
```
record_fastplay.cgi?ctrl=0&
```

### Delete File

**CGI Command:**
```
del_file.cgi?name=$recordName&
```

### Getting Recorded Video Dates

**CGI Command:**
```
get_record_file.cgi?GetType=date&
```

---

## 15. Person Tracking

> **Note:** If the camera supports human detection, it supports person tracking.

### Setting Person Tracking

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2127&command=0&enable=$enable&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| enable | int | 1: Turn on, 0: Turn off |

### Getting Person Tracking Status

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2127&command=1&
```

**Response:** `humanTrackingEnable = int.tryParse(data["enable"] ?? "0")`

---

## 16. Red & Blue Lights

> **Note:** Use `get_status.cgi?` to get `hardwareTestFunc` value. If `hardwareTestFunc & 0x200 != 0`, the camera supports Red & Blue lights.

### Setting Red & Blue Lights

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2109&command=0&alarmLed=$value&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| value | int | 1: Turn on, 0: Turn off |

### Getting Red & Blue Lights Status

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2109&command=2&
```

### Setting Red & Blue Lights Mode

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2108&command=1&alarmLedMode=$mode&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| mode | int | 1: Linkage with alarms, 0: Unlink with alarms |

### Getting Red & Blue Lights Mode

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2108&command=0&
```

---

## 17. Alarm Flashing Light

> **Note:** If `hardwareTestFunc` indicates white light support, alarm flashing light is supported.

### Setting Alarm Flashing Light

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2108&command=1&lightMode=$light&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| light | int | 0: Turn off, 1: Turn on (no flashing/white light), 2: Turn on with flash |

### Getting Alarm Flashing Light Status

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2108&command=0&
```

---

## 18. Virtual Joystick

### Movement Commands

| Direction | CGI Command |
|-----------|-------------|
| Move Left | `decoder_control.cgi?command=4&onestep=0&` |
| Move Right | `decoder_control.cgi?command=6&onestep=0&` |
| Move Up | `decoder_control.cgi?command=0&onestep=0&` |
| Move Down | `decoder_control.cgi?command=2&onestep=0&` |

Optional parameters can be appended:
- `curr_binocular=$currBinocular&` (0: First lens, 1: Second lens)
- `motor_speed=$motorSpeed&` (1-10, where 1 = Slowest, 10 = Fastest)

### Stop Commands

| Direction | CGI Command |
|-----------|-------------|
| Stop Left | `decoder_control.cgi?command=5&onestep=0&` |
| Stop Right | `decoder_control.cgi?command=7&onestep=0&` |
| Stop Up | `decoder_control.cgi?command=1&onestep=0&` |
| Stop Down | `decoder_control.cgi?command=3&onestep=0&` |

---

## 19. Recording Duration

### Setting Recording Duration (Corded Electric Device)

**CGI Command:**
```
set_alarm.cgi?enable_alarm_audio=0&motion_armed=${enable ? 1 : 0}&motion_sensitivity=$level&CloudVideoDuration=$videoDuration&input_armed=1&ioin_level=0&iolinkage=0&ioout_level=0&preset=0&mail=0&snapshot=1&record=1&upload_interval=0&schedule_enable=1&schedule_sun_0=$plan&schedule_sun_1=$plan&schedule_sun_2=$plan&schedule_mon_0=$plan&schedule_mon_1=$plan&schedule_mon_2=$plan&schedule_tue_0=$plan&schedule_tue_1=$plan&schedule_tue_2=$plan&schedule_wed_0=$plan&schedule_wed_1=$plan&schedule_wed_2=$plan&schedule_thu_0=$plan&schedule_thu_1=$plan&schedule_thu_2=$plan&schedule_fri_0=$plan&schedule_fri_1=$plan&schedule_fri_2=$plan&schedule_sat_0=$plan&schedule_sat_1=$plan&schedule_sat_2=$plan&defense_plan1=0&defense_plan2=0&...&defense_plan21=0&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| enable | bool | true: Turn on, false: Turn off |
| level | int | Detection sensitivity value |
| videoDuration | int | Recording duration: -1 (unset), or 5, 10, 15, 30 seconds |
| plan | int | If enable == true: plan = -1, else plan = 0 |

### Setting Recording Duration (Low-Power Device)

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2106&command=9&pirPushSwitch=${pushEnable ? 1 : 0}&pirPushSwitchVideo=${videoEnable ? 1 : 0}&CloudVideoDuration=${videoDuration ?? 15}&autoRecordMode=${autoRecordMode ?? 0}&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| pushEnable | bool | true: Turn on, false: Turn off |
| videoEnable | bool | true: Turn on, false: Turn off |
| videoDuration | int | Recording duration: 5, 10, 15, 30 seconds |
| autoRecordMode | int | 1: Auto record, 0: Else |

### Getting Recording Duration

**Corded Electric Device:**
```
get_params.cgi?
```

**Low-Power Device:**
```
trans_cmd_string.cgi?cmd=2106&command=8&
```

**Response:**
- `videoDuration = int.tryParse(data["CloudVideoDuration"] ?? "15")`
- `autoRecordVideoMode = int.tryParse(data["autoRecordMode"] ?? "0")`

---

## 20. Detection Schedule

> **Note:** This functionality uses the PlanModel class. Please check the demo for implementation details.

### Setting Detection Schedule

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2017&command=2&mark=212&motion_push_plan1=${records[0]}&motion_push_plan2=${records[1]}&...&motion_push_plan21=${records[20]}&motion_push_plan_enable=$enable&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| records | List\<int\> | Length: 21, default value: -1. Set value: weighted sum of corresponding time |
| enable | int | 1: Motion detection, 5: Human detection (use 5 for low-power devices) |

### Detection Modes

**All Day Detection:** No need to set, uses default values.

**Daytime Detection Only (8:00 AM - 8:00 PM):**
```dart
int startTime = 480;  // 8:00 AM in minutes
int endTime = 1200;   // 8:00 PM in minutes
List weeks = [7, 1, 2, 3, 4, 5, 6];
PlanModel model = PlanModel.fromPlans(startTime, endTime, weeks, state.deviceModel.id);
```

**Nighttime Detection Only (8:00 PM - 8:00 AM):**
```dart
int startTime = 1200; // 8:00 PM in minutes
int endTime = 480;    // 8:00 AM in minutes
List weeks = [7, 1, 2, 3, 4, 5, 6];
PlanModel model = PlanModel.fromPlans(startTime, endTime, weeks, state.deviceModel.id);
```

**Custom Detection:** Calculate records values based on user-selected startTime, endTime, and weeks.

### Getting Detection Schedule

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2017&command=11&mark=212&type=2&
```

---

## 21. Alarm Sound

> **Notes:**
> 1. Audio format requirements: .wav suffix, single channel, 16-bit, 8000Hz, g711a
> 2. If battery level is below 20%, alarm sound will not work

### Setting Alarm Sound

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2135&command=0&urlJson=$urlJson&filename=$voiceName&switch=$switch&voicetype=$voicetype&
```

With playback options:
```
trans_cmd_string.cgi?cmd=2135&command=0&urlJson=$urlJson&filename=$voiceName&switch=$switch&voicetype=$voicetype&play=1&playtimes=$playTimes&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| switch | int | 1: Turn on, 0: Turn off |
| voicetype | int | 0: Face detection, 1: Human detection, 2: Smoke alarm, 3: Motion detection, 4: Off duty, 5: Cry detection, 6: On duty, 7: Flame warning, 8: Smoke warning |
| urlJson | String | JSON encoded URL: `{"url": voiceUrl}` |
| voiceName | String | Filename |
| play | int | 1: Play on set |
| playtimes | String | Play count (AI devices support) |

### Turning Off Alarm Sound

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2135&command=0&switch=$switch&voicetype=$voicetype&
```

### Getting Alarm Sound Settings

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2135&command=1&voicetype=$voiceType&
```

---

## 22. TF Card Sound Recording

### Setting Sound Recording

**CGI Command:**
```
set_recordsch.cgi?record_audio=1&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| record_audio | int | 1: Turn on, 0: Turn off |

### Getting Sound Recording Status

**CGI Command:**
```
get_record.cgi?
```

---

## 23. TF Card Recording Mode

> **Notes:**
> 1. Only supported by corded electric cameras with TF status 1 or 2
> 2. When not recording: schedule recording, 24h recording, and motion detection video should be off
> 3. Schedule, 24h, and motion detection recording cannot exist simultaneously

### Setting Schedule Recording

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2017&command=3&mark=212&record_plan1=${records[0]}&...&record_plan21=${records[20]}&record_plan_enable=$enable&
```

> **Note:** `enable` => 1: Recording, 0: Not recording. Records value refers to smart timing detection.

### Setting Motion Detection Video Record

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2017&command=1&mark=212&motion_record_plan1=${records[0]}&...&motion_record_plan21=${records[20]}&motion_record_plan_enable=$enable&
```

> **Note:** `enable` => 1: Recording, 0: Not recording. Records list values should be -1.

### Setting 24h Recording

**CGI Command:**
```
set_recordsch.cgi?record_cover=1&record_timer=$record_timer&time_schedule_enable=$enable&schedule_sun_0=$value&schedule_sun_1=$value&schedule_sun_2=$value&schedule_mon_0=$value&...&schedule_sat_2=$value&record_audio=$record_audio&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| enable | int | 1: Turn on, 0: Turn off |
| record_timer | String | Record time: 5, 10, 15, 30 |
| record_audio | String | "1": Record audio, "0": No audio |
| value | int | Turn on: -1, Turn off: 0 |

### Getting Recording Modes

**Schedule Recording:**
```
trans_cmd_string.cgi?cmd=2017&command=11&mark=212&type=3&
```
**Field:** `record_plan_enable`

**Motion Detection Video:**
```
trans_cmd_string.cgi?cmd=2017&command=11&mark=212&type=1&
```
**Field:** `motion_record_enable`

**24h Recording:**
```
get_record.cgi?
```
**Field:** `record_time_enable`

---

## 24. TF Card Recording Time

### Setting Recording Time

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2204&command=2&record_resolution=$resolution&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| resolution | int | 0: Ultra short (Ultra HD), 1: Short (HD), 2: Long (SD) |

### Getting Recording Time

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2204&command=1&
```

---

## 25. TF Card Format

### Formatting TF Card

**CGI Command:**
```
set_formatsd.cgi?
```

### Getting TF Card Status

**CGI Command:**
```
get_status.cgi?
```

**Field:** `sdstatus`
- 1 or 2: Normal
- 3: File system error
- 4: Formatting
- 5: Unmounted

---

## 26. Linkage Correction (Two Sensors)

> **Note:** Use `get_status.cgi?` to get `support_pininpic` and `support_mutil_sensor_stream` values. If `support_pininpic == 1` or `support_mutil_sensor_stream == 1` or `== 2`, the device supports linkage correction.

### 26.1 Linkage Correction Switch

**Setting:**
```
trans_cmd_string.cgi?cmd=4101&command=1&gblinkage_enable=$enable&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| enable | int | 1: Turn on, 0: Turn off |

**Getting Status:**
```
trans_cmd_string.cgi?cmd=4101&command=0&
```

**Response:** `gblinkage_enable`: 0 = Invisible, 1 = On, 2 = Off

### 26.2 PTZ Reset

**Setting:**
```
trans_cmd_string.cgi?cmd=4100&command=0&
```

**Getting Status:**
```
trans_cmd_string.cgi?cmd=4100&command=1&
```

### 26.3 Image Correction

**CGI Command:**
```
camera_control.cgi?param=40&value=0&x_percent=${x_percent}&y_percent=${y_percent}
```

| Parameter | Type | Description |
|-----------|------|-------------|
| x_percent | int | X-axis scale: 1-100 |
| y_percent | int | Y-axis scale: 1-100 |

### 26.4 Linkage Coordinate Setting

**CGI Command:**
```
camera_control.cgi?param=39&value=0&x_percent=${x_percent}&y_percent=${y_percent}
```

| Parameter | Type | Description |
|-----------|------|-------------|
| x_percent | int | X-axis scale: 1-100 |
| y_percent | int | Y-axis scale: 1-100 |

---

## 27. Multi Sensor Camera

> **Note:** Use `get_status.cgi?` to get `splitScreen` and `support_mutil_sensor_stream` values.
> - If `splitScreen == null` and `support_mutil_sensor_stream == 1` or `== 2`: Two sensor camera
> - If both `support_mutil_sensor_stream` and `splitScreen` have values: (Fake) three sensor camera

### Creating Player Controllers

```dart
// First controller
var subController = AppPlayerController();
var result = await subController.create();
result = await subController.setVideoSource(SubPlayerSource());
await subController.start();
result = await controller!.enableSubPlayer(subController);

// Second controller
var sub2Controller = AppPlayerController();
var result = await sub2Controller.create();
result = await sub2Controller.setVideoSource(SubPlayerSource());
await sub2Controller.start();
result = await controller!.enableSub2Player(sub2Controller);
```

---

## 28. Humanoid Zoom Tracking

> **Note:** Use `get_status.cgi?` to get `support_humanoid_zoom` value. If `support_humanoid_zoom == "1"`, the camera supports this functionality.

### Setting Humanoid Zoom Tracking

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2126&command=1&
```

### Getting Humanoid Zoom Tracking Status

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2126&command=0&humanoid_zoom=$enable&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| enable | int | 1: Turn on, 0: Turn off |

---

## 29. Screenshot

### Single Sensor

**CGI Command:**
```
snapshot.cgi?res=1&
```

### Two Sensors

**CGI Command:**
```
snapshot.cgi?sensor=$sensor&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| sensor | int | 0: Tracking Camera, 1: Panorama Camera |

---

## 30. Video Flipping

### Setting Video Flipping

**CGI Command:**
```
camera_control.cgi?param=5&value=$value&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| value | int | 0: Do not flip, 3: Flip upside down |

### Getting Video Flipping Status

**CGI Command:**
```
get_camera_params.cgi?
```

**Field:** `flip`

---

## 31. Light Anti-interference

### Setting Light Anti-interference

**CGI Command:**
```
camera_control.cgi?param=3&value=$value&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| value | int | 0: 50Hz, 1: 60Hz |

### Getting Light Anti-interference Status

**CGI Command:**
```
get_camera_params.cgi?
```

**Field:** `mode`

---

## 32. Video Time Display

### Setting Video Time Display

**CGI Command:**
```
set_misc.cgi?osdenable=$value&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| value | int | 1: Display, 0: Do not display |

### Getting Video Time Display Status

**CGI Command:**
```
get_status.cgi?
```

**Field:** `osdenable`

---

## 33. Remote Power On/Off

> **Notes:**
> - When device is in deep sleep, remote power on/off is not supported
> - For remote shutdown: Ensure device is connected. After successful shutdown, actively disconnect
> - For remote startup: Wake up the device first, connect, then call CGI

> **Note:** Use `get_status.cgi?` to get `support_Remote_PowerOnOff_Switch` value. If value == "1", the device supports this functionality.

### Setting Remote Power On/Off

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2106&command=13&PowerSwitch=$open&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| open | int | 1: Turn off, 0: Turn on |

### Getting Remote Power On/Off Status

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2106&command=14&
```

**Field:** `PowerSwitch`

---

## 34. QR Code Network Connection

### QR Code Data Format

```
qrContent = '{"BS":"$bssid","P":"$pwd","U":"${userId}-OEM","RS":"$ssid"}'
```

| Parameter | Type | Description |
|-----------|------|-------------|
| bssid | String | WiFi BSSID |
| pwd | String | WiFi password |
| ssid | String | WiFi SSID (name) |
| userId | String | User unique identifier (e.g., "2384782") |

### Query Devices Connected to Network API

**Request Method:** POST

**Request URL:** `https://api.eye4.cn/hello/query`

**Request Parameter:**
```json
{"key": "${userId}-OEM_binding"}
```

**Success Response:**
```json
{"value": "VE0005622QHOW"}
```

**Failure Response:**
```json
{"msg": "未搜索到", "code": 404}
```

### Delete Devices Connected to Network API

**Request Method:** POST

**Request URL:** `https://api.eye4.cn/hello/confirm`

**Request Parameter:**
```json
{"key": "${userId}-OEM_binding"}
```

### Determine if ID is a Valid Camera ID

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
    return exp.hasMatch(name);
}
```

---

## 35. Bluetooth Network Connection

### Service and Characteristic UUIDs

- **Service UUID:** `0000FFF0-0000-1000-8000-00805F9B34FB`
- **Characteristics UUID:** `0000FFF1-0000-1000-8000-00805F9B34FB`

### Get WiFi List Protocol

| Step | Send | Receive |
|------|------|---------|
| Request | 0xFF 0xFF | 0xF0 0xF3 (packet length: 40) |
| Reply | 0xFF index | - |
| End | index = 10000 | - |

### Bluetooth Network Connection Protocol

| Package | Send | Receive |
|---------|------|---------|
| First | [0xF0, 0xF0] + 118 | [0xF0, 0xF0] |
| Second | [0xF0, 0xF1] + 36 | [0xF0, 0xF1] |
| Third | - | [0xF0, 0xF2] + status |

**Status Codes:**
- 0: Success
- 1: Password error
- 2: Connection timeout
- 3: DHCP fail
- 4: Gateway configuration failed

---

## 36. Update Firmware Version

### Get Latest Version Number

Use `get_status.cgi?` to get the `sys_ver` value (current version).

**Request URL:**
```
http://api4.eye4.cn:808/firmware/${currentVersion}/cn
```

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

### Update Firmware

**CGI Command:**
```
auto_download_file.cgi?server=$server&file=$file&type=0&resevered1=&resevered2=&resevered3=&resevered4=&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| file | String | download_file from version response |
| server | String | download_server from version response |

---

## 37. Switching Device WiFi

### Get WiFi List

**Step 1:**
```
wifi_scan.cgi?
```

**Step 2:**
```
get_wifi_scan_result.cgi?
```

### Switch Device WiFi

**CGI Command:**
```
set_wifi.cgi?ssid=${Uri.encodeQueryComponent(info.ssid)}&channel=${info.channel}&authtype=${info.security}&wpa_psk=${Uri.encodeQueryComponent(password)}&enable=1&
```

Or with area parameter:
```
set_wifi.cgi?ssid=${Uri.encodeQueryComponent(info.ssid)}&channel=${info.channel}&authtype=${info.security}&wpa_psk=${Uri.encodeQueryComponent(password)}&enable=1&$area&
```

---

## 38. AI Smart Service

### Get AI Smart Service Status

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2400&command=1&AiType=$aiType&
```

| aiType | Description |
|--------|-------------|
| 0 | Area intrusion |
| 1 | Human loitering detection |
| 2 | Illegal parking detection |
| 3 | Line crossing detection |
| 4 | Absence detection |
| 5 | Vehicle retrograde detection |
| 6 | Package detection |
| 7 | Fire detection |

### Set AI Smart Service Data

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2400&command=0&AiType=$aiType&AiCfg=$aiConfigString&
```

| Parameter | Type | Description |
|-----------|------|-------------|
| aiType | int | AI type (0-7, see above) |
| aiConfigString | String | Model data JSON string |

### AI Model Data Structures

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

| Parameter | Type | Description |
|-----------|------|-------------|
| enable | int | 0: Off, 1: On |
| object | int | Target Type: 1: Pet, 2: Car, 3: Person+Car, 4: Pet, 5: Person+Pet, 6: Car+Pet, 7: All |
| region | list | Activity zone data |
| sensitive | int | Sensitivity: 1-3 |
| lightLed | int | Flashing light: 0: Off, 1: On |
| areaframe | int | Display target box: 0: Off, 1: On |

#### 2. Human Loitering

```json
{
    "enable": 0,
    "staytime": 80,
    "region": [...],
    "sensitive": 2,
    "lightLed": 0,
    "areaframe": 1
}
```

| Parameter | Type | Description |
|-----------|------|-------------|
| enable | int | 0: Off, 1: On |
| staytime | int | Loitering time: 30-3600 seconds |
| region | list | Activity zone data |
| sensitive | int | Sensitivity: 1-3 |
| lightLed | int | Flashing light: 0: Off, 1: On |
| areaframe | int | Display target box: 0: Off, 1: On |

#### 3. Illegal Parking

```json
{
    "enable": 0,
    "staytime": 80,
    "region": [...],
    "sensitive": 2,
    "lightLed": 0,
    "areaframe": 1
}
```

| Parameter | Type | Description |
|-----------|------|-------------|
| enable | int | 0: Off, 1: On |
| staytime | int | Parking time: 30-3600 seconds |
| region | list | Activity zone data |
| sensitive | int | Sensitivity: 1-3 |
| lightLed | int | Flashing light: 0: Off, 1: On |
| areaframe | int | Display target box: 0: Off, 1: On |

#### 4. Line Crossing

```json
{
    "enable": 0,
    "object": 1,
    "crosslineArr": [{"0": {"0": {"x": 0.5, "y": 0.0}, "1": {"x": 0.5, "y": 1.0}}, "dir": 1}],
    "sensitive": 2,
    "lightLed": 0,
    "areaframe": 1
}
```

| Parameter | Type | Description |
|-----------|------|-------------|
| enable | int | 0: Off, 1: On |
| object | int | Target Type (same as Area Intrusion) |
| crosslineArr | list | Cross line array |
| sensitive | int | Sensitivity: 1-3 |
| lightLed | int | Flashing light: 0: Off, 1: On |
| areaframe | int | Display target box: 0: Off, 1: On |

#### 5. Absence Detection

```json
{
    "enable": 0,
    "leavetime": 80,
    "sumperson": 1,
    "region": [...],
    "sensitive": 2,
    "lightLed": 0,
    "areaframe": 1
}
```

| Parameter | Type | Description |
|-----------|------|-------------|
| enable | int | 0: Off, 1: On |
| leavetime | int | Absence time: 30-3600 seconds |
| sumperson | int | Minimum personnel on duty: 1, 2, or 3 |
| region | list | Activity zone data |
| sensitive | int | Sensitivity: 1-3 |
| lightLed | int | Flashing light: 0: Off, 1: On |
| areaframe | int | Display target box: 0: Off, 1: On |

#### 6. Vehicle Retrograde

```json
{
    "enable": 0,
    "region": [{"0": {"point": {...}, "selectedLine": 1}}],
    "sensitive": 2,
    "lightLed": 0,
    "areaframe": 1
}
```

| Parameter | Type | Description |
|-----------|------|-------------|
| enable | int | 0: Off, 1: On |
| region | list | Activity zone data with selectedLine |
| sensitive | int | Sensitivity: 1-3 |
| lightLed | int | Flashing light: 0: Off, 1: On |
| areaframe | int | Display target box: 0: Off, 1: On |

#### 7. Package Detection

```json
{
    "appearEnable": 0,
    "disappearEnable": 0,
    "stayEnable": 0,
    "region": [...],
    "stayTime": 600,
    "sensitive": 2,
    "appearLightLed": 0,
    "disappearLightLed": 0,
    "stayLightLed": 0,
    "areaframe": 1
}
```

| Parameter | Type | Description |
|-----------|------|-------------|
| appearEnable | int | Package appear: 0: Off, 1: On |
| disappearEnable | int | Package disappear: 0: Off, 1: On |
| stayEnable | int | Package stay: 0: Off, 1: On |
| region | list | Activity zone data |
| stayTime | int | Detention time in seconds (10min, 30min, 1h, 6h, 12h, 24h, 48h, 72h) |
| sensitive | int | Sensitivity: 1-3 |
| appearLightLed | int | Appear flash: 0: Off, 1: On |
| disappearLightLed | int | Disappear flash: 0: Off, 1: On |
| stayLightLed | int | Stay flash: 0: Off, 1: On |
| areaframe | int | Display target box: 0: Off, 1: On |

#### 8. Fire & Smoke Detection

```json
{
    "fireEnable": 0,
    "smokeEnable": 0,
    "sensitive": 2,
    "fireLightLed": 0,
    "smokeLightLed": 0,
    "firePlace": 0,
    "areaframe": 1
}
```

| Parameter | Type | Description |
|-----------|------|-------------|
| fireEnable | int | Fire detection: 0: Off, 1: On |
| smokeEnable | int | Smoke detection: 0: Off, 1: On |
| sensitive | int | Sensitivity: 1-3 |
| fireLightLed | int | Fire flash: 0: Off, 1: On |
| smokeLightLed | int | Smoke flash: 0: Off, 1: On |
| firePlace | int | Scene: 0: Indoor, 1: Outdoor |
| areaframe | int | Display target box: 0: Off, 1: On |

### AI Detection Schedule

#### Setting Detection Schedule

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2017&command=$type&mark=1&${typeString}_plan1=${records[0]}&...&${typeString}_plan21=${records[20]}&${typeString}_plan_enable=$enable&
```

| type | typeString | Description |
|------|------------|-------------|
| 12 | fire | Fire detection |
| 14 | region_entry | Area intrusion |
| 15 | person_stay | Human loitering |
| 16 | car_stay | Illegal parking |
| 17 | line_cross | Line crossing |
| 18 | person_onduty | Absence detection |
| 19 | car_retrograde | Vehicle retrograde |
| 20 | package_detect | Package detection |

| Parameter | Type | Description |
|-----------|------|-------------|
| records | list | Plan records, length = 21, default = -1. See [Detection Schedule](#20-detection-schedule) for calculation |
| enable | int | 1: Turn on, 0: Turn off |

#### Getting Detection Schedule Data

**CGI Command:**
```
trans_cmd_string.cgi?cmd=2017&command=11&mark=1&type=$type&
```

| type | Description |
|------|-------------|
| 12 | Fire detection |
| 14 | Area intrusion |
| 15 | Human loitering |
| 16 | Illegal parking |
| 17 | Line crossing |
| 18 | Absence detection |
| 19 | Vehicle retrograde |
| 20 | Package detection |
