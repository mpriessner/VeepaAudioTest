# Alarm CGI Documentation

## Description:

1.  The alarm functionality includes motion detection and detection related setting functionalities;
2.  There are motion detection and human detection. (Note: For corded electric camera, it's called motion detection, but for the low-power camera, motion detection refers to human detection.)
3.  Detection related functionalities include: human detection, person tracking, motion detection frequency, detection sensitivity, detection distance, alarm flashing light, activity zone, detection schedule, alarm sound etc.

## 1. Motion Detection For Low-Power Cameras (Actually Human Detection)

Field to determine whether it is low-power: support_low_power has a value and equal to 1 (Field acquisition command: get_status.cgi?)

**CGI for setting human detection:**
`"trans_cmd_string.cgi?cmd=2106&command=9&pirPushSwitch=$pirPushSwitch&pirPushSwitchVideo=$pirPushSwitchVideo&"`

| Parameter          | Type | Description                               |
| ------------------ | ---- | ----------------------------------------- |
| pirPushSwitch      | int  | 1: turn on, 0: turn off                   |
| pirPushSwitchVideo | int  | Cloud video recording: 1: turn on, 0: turn off |

**CGI for getting human detection:**
`"trans_cmd_string.cgi?cmd=2106&command=8&"`
Field: `pirPushSwitch`

## 2. Motion Detection Frequency(Only For Low-Power Cameras)

Note: This functionality could be set when human detection is enabled;

**CGI for setting detection frequency:**
`String cgi = "trans_cmd_string.cgi?cmd=2106&command=4&humanDetection=$detection&&mark=123456789&"`

| Parameter | Type | Description                       |
| --------- | ---- | --------------------------------- |
| detection | int  | 0-3, 0: turn off, 1-3: high-middle-low |
| mark      | int  | Random number                     |

**CGI for getting detection frequency:**
`"trans_cmd_string.cgi?cmd=2106&command=3&mark=12345678&"`
Field: `humanDetection`

## 3. Motion Detection For Corded Electric Cameras

Field to determine whether it is corded electric camera: support_low_power has no value or is equal to 0 (Field acquisition command:get_status.cgi?)

**CGI for setting motion detection:**
`String cgi ="trans_cmd_string.cgi?cmd=2017&command=2&mark=212&"`
`"motion_push_plan1=-1&"`
`"motion_push_plan2=-1&"`
`"motion_push_plan3=-1&"`
... (plans 4 through 21) ...
`"motion_push_plan_enable=$enable&"`

| Parameter          | Type | Description                                        |
| ------------------ | ---- | -------------------------------------------------- |
| motion_push_plan   | int  | Alarm plan, length is 21, default value is -1(unset) |
| enable             | int  | 0: turn off, 1: motion detection, 5: human detection   |

**CGI for getting motion detection:**
`"trans_cmd_string.cgi?cmd=2017&command=11&mark=212&type=2&"`
Field: `motion_push_enable`

## 4. Motion Detection Sensitivity For Corded Electric Cameras

**CGI for setting detection sensitivity:**
`"set_alarm.cgi?enable_alarm_audio=0&motion_armed=$motion_armed&motion_sensitivity=$motion_sensitivity&"`

| Parameter          | Type | Description                 |
| ------------------ | ---- | --------------------------- |
| motion_armed       | int  | 1: turn on, 0:turn off      |
| motion_sensitivity | int  | 1 High, 5 middle, 9 low     |

**CGI for getting detection sensitivity:**
`"get_params.cgi?"`
Field: `alarm_motion_sensitivity`

## 5. Human Detection Sensitivity For Corded Electric Cameras

**CGI for setting detection sensitivity:**
`"trans_cmd_string.cgi?cmd=2126&command=0&sensitive=$sensitive&&mark=123456789&"`

| Parameter | Type | Description                       |
| --------- | ---- | --------------------------------- |
| sensitive | int  | 0-3, 0: Turn off, 1-3 High-middle-low |
| mark      | int  | Random number                     |

**CGI for getting detection sensitivity:**
`"trans_cmd_string.cgi?cmd=2126&command=1&mark=123456789&"`
Field: `sensitive`

## 6. Humanoid Detection Switch

Low power cameras do not need to enable human framing, they only need to enable humanoid detection. (Alarm will only be triggered when a person is detected, which can improve the accuracy of the alarm)
Value==1 on, value==0 off

**CGI for setting humanoid detection:**
`String cgi = "trans_cmd_string.cgi?cmd=2106&command=4&HumanoidDetection=$value&"`

| Parameter | Type | Description          |
| --------- | ---- | -------------------- |
| value     | int  | 0:turn off, 1:turn on |

**CGI for getting humanoid detection:**
`"trans_cmd_string.cgi?cmd=2106&command=3&"`
Field: `HumanoidDetection`

## 7. Detection Distance Setting

After enabling motion detection, the detection distance can be set, but it is necessary to determine whether the device supports this function. Use `get_status.cgi?` to get `support_Pir_Distance_Adjust` value, if value>0, it supports this functionality.

**CGI for setting detection distance:**
`String cgi ="trans_cmd_string.cgi?cmd=2106&command=4&humanDetection=$pirLevel&DistanceAdjust=$distance&"`

| Parameter | Type | Description                |
| --------- | ---- | -------------------------- |
| distance  | int  | 1-3 Near, medium, and far  |

**CGI for getting detection distance:**
`"trans_cmd_string.cgi?cmd=2106&command=3&"`
Field: `DistanceAdjust`
