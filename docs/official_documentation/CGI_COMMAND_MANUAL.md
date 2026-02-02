# IP/WIRELESS CAMERA CGI Command Manual (v12, 20230505) - Translated

This document is a text conversion of the `C系列cgi命令手册_v12_20230505.pdf` file.

---

## Introduction

The CGIs listed in this document are a subset of the communication protocol provided by the IP camera for client communication. CGI can be used in two ways: one based on HTTP and the other based on P2P. HTTP-based client programs (which can be web pages running in a browser or other applications) can perform various operations on the device through CGI. P2P-based client programs can communicate after using the SDK we provide. The SDK includes versions for Android, iOS, and Windows.

### 1. CGI Security Authentication

CGI authentication is divided into three types:
1.  **HTTP Basic Authentication:** This method is mostly used for GET-related CGIs.
2.  **CGI with User/Password Parameters:** This method is mainly for SET-related CGIs.
3.  **HTTPS Authentication:** Supported by some machines.

### 2. POST-related CGI

POST CGIs use the HTTP POST method. There are only two upgrade-related POST CGIs available: `upgrade_firmware.cgi` and `upgrade_htmls.cgi`.

**POST Example:**
```html
<form action=”upgrade_firmware.cgi?next_url=mail.htm” method=”post” enctype=”multipart/form-data”>
  <input type=”file” name=”file” size=”20”>
</form>
```

### 3. GET-related CGI

These CGIs retrieve the device status and parameters, including `get_status.cgi` and `get_params.cgi`. They return text that includes device status or parameters, with a format similar to JavaScript variable definitions. Each status or parameter is defined as a variable and returned.

**Example:**
```javascript
var alias="IPCAM";
var sys_ver="Apr 28 2011 00:18:03";
var id="00000000031729";
```

### 4. SET-related CGI

These CGIs are for configuring device parameters. Each CGI requires different permissions.

**Example:**
`http://ip:port/set_alias.cgi?loginuse=admin&loginpas=&alias=hdipcam`

### 5. Media Stream-related CGI

These CGIs are for configuring media stream parameters. Each CGI requires different permissions.

**Example:**
`http://ip:port/videostream.cgi?user=admin&pwd=`

### 6. Search Protocol

To find related devices on the local network, please contact Shenzhen Vstarcam Technology Co., Ltd. directly.

### 7. Manufacturer and Production Parameters

For manufacturer-related parameters, production tools, configuration, and version verification, please contact Shenzhen Vstarcam Technology Co., Ltd. directly.

---

## CGI Command List

### I. GET-related CGI

*   `get_status.cgi`: Get device status. (Page 9)
*   `get_params.cgi`: Get device parameters. (Page 13)
*   `get_alarmlog.cgi`: Get alarm log. (Page 18)
*   `get_log.cgi`: Get system log. (Page 18)
*   `get_misc.cgi`: Get miscellaneous PTZ parameters. (Page 19)
*   `get_record.cgi`: Get recording parameters. (Page 19)
*   `get_record_file.cgi`: Get list of recording files. (Page 20)
*   `get_record_idx.cgi`: Get recording index file for timeline. (Page 21)
*   `get_wifi_scan_result.cgi`: Get WiFi scan results. (Page 21)
*   `get_factory_param.cgi`: Get factory parameters. (Page 22)
*   `get_apwifi.cgi`: Get AP mode WiFi parameters. (Page 23)
*   `mailtest.cgi`: Test email settings. (Page 23)
*   `ftptest.cgi`: Test FTP settings. (Page 23)
*   `login.cgi`: Get last login user info. (Page 23)
*   `get_factory_extra.cgi`: Get extra factory parameters (ADC). (Page 24)
*   `get_pnp_server.cgi`: Get PnP server settings. (Page 24)
*   `get_rtsp.cgi`: Get RTSP parameters. (Page 24)
*   `get_onvif.cgi`: Get ONVIF status. (Page 24)
*   `get_aging.cgi`: Get aging test parameters. (Page 25)
*   `get_test_hardware_result.cgi`: Get hardware test results. (Page 25)
*   `ipc135x_get.cgi`: Get RF parameters. (Page 25)
*   `get_whiteled_value.cgi`: Get white LED brightness value. (Page 26)
*   `get_hw_config.cgi`: Get hardware configuration. (Page 26)

### II. Audio/Video-related CGI

*   `snapshot.cgi`: Capture a still image. (Page 27)
*   `videostream.cgi`: Request video stream for non-IE browsers (push). (Page 27)
*   `livestream.cgi`: Request video stream communication. (Page 28)
*   `audiostream.cgi`: Request audio stream communication. (Page 29)
*   RTSP Stream: Real-Time Streaming Protocol. (Page 30)

### III. Control-related CGI

*   `reboot.cgi`: Reboot the device. (Page 31)
*   `camera_control.cgi`: Control image sensor parameters. (Page 31)
*   `decoder_control.cgi`: Control PTZ (Pan-Tilt-Zoom). (Page 32)
*   `moto_step_correct.cgi`: Calibrate gun-ball camera PTZ. (Page 33)
*   `set_whiteled_value.cgi`: Set white LED brightness. (Page 33)
*   `restore_factory.cgi`: Restore to factory settings. (Page 34)
*   `set_moto_run.cgi`: Set PTZ test patrol. (Page 34)
*   `del_file.cgi`: Delete a recording file from the TF card. (Page 34)
*   `test_ftp.cgi`: Test FTP connection. (Page 34)
*   `test_mail.cgi`: Test email connection. (Page 34)
*   `wifi_scan.cgi`: Scan for WiFi networks. (Page 34)
*   `set_ir_gpio.cgi`: Control IR light. (Page 34)
*   `check_user.cgi`: Check Eye4 user account. (Page 35)
*   `lens_control.cgi`: For C7833-x4 zoom initialization. (Page 35)
*   `manual_trigger_cloud_record.cgi`: Manually trigger a cloud recording. (Page 35)

### IV. SET-related CGI

*   `set_upnp.cgi`: Configure UPNP. (Page 36)
*   `set_alarm.cgi`: Configure alarm settings. (Page 36)
*   `set_users.cgi`: Configure user accounts. (Page 37)
*   `set_alias.cgi`: Set device alias. (Page 37)
*   `set_mail.cgi`: Configure mail service. (Page 38)
*   `set_wifi.cgi`: Configure WiFi settings. (Page 38)
*   `set_datetime.cgi`: Set date and time. (Page 38)
*   `set_media.cgi`: Set media parameters. (Page 39)
*   `set_ddns.cgi`: Set DDNS options. (Page 39)
*   `set_misc.cgi`: Set miscellaneous PTZ parameters. (Page 40)
*   `set_default.cgi`: Set current settings as factory default. (Page 41)
*   `set_devices.cgi`: Set multi-channel device parameters. (Page 41)
*   `set_network.cgi`: Set basic network parameters. (Page 41)
*   `set_factory_param.cgi`: Set factory parameters. (Page 42)
*   `set_pppoe.cgi`: Set PPPoE options. (Page 42)
*   `set_formatsd.cgi`: Format the SD card. (Page 42)
*   `set_recordsch.cgi`: Set recording schedule. (Page 43)
*   `set_ftp.cgi`: Set FTP options. (Page 43)
*   `set_rtsp.cgi`: Set RTSP authentication service. (Page 43)
*   `set_apwifi.cgi`: Set AP WiFi parameters. (Page 44)
*   `set_alarmlogclr.cgi`: Clear the alarm log. (Page 44)
*   `set_pnp_server.cgi`: Set custom P2P server string. (Page 44)
*   `set_bootday.cgi`: Set auto-reboot day. (Page 45)
*   `set_extra.cgi`: Set extra parameters. (Page 45)
*   `set_factory_extra.cgi`: Set factory ADC parameters. (Page 45)
*   `set_onvif.cgi`: Set ONVIF parameters. (Page 45)
*   `set_aging.cgi`: Set aging test mode. (Page 45)
*   `set_update_push_user.cgi`: Notify camera to update push user list. (Page 46)
*   `auto_download_file.cgi`: Online upgrade function. (Page 46)
*   `ipc135x_set.cgi`: Set RF related parameters. (Page 46)
*   `set_test_hardware.cgi`: Online upgrade function. (Page 47)
*   `record_fastplay.cgi`: Timeline recording download. (Page 47)
*   `set_production_config.cgi`: Set production configuration parameters. (Page 47)
*   `set_power_off.cgi`: Remote power off. (Page 47)

### V. POST-related CGI

*   `upgrade_firmware.cgi`: Upgrade device firmware. (Page 48)
*   `upgrade_htmls.cgi`: Upgrade device web interface. (Page 49)
*   `upgrade_factory_params.cgi`: Upgrade device factory default parameters. (Page 49)

### VI. Alarm Linkage Function-related CGI

*   `get_sensorstatus.cgi`: Get sensor status (for C7838-AR). (Page 49)
*   `set_sensorstatus.cgi`: Set sensor status (for C7838-AR). (Page 50)
*   `get_sensorlist.cgi`: Get sensor list. (Page 50)
*   `set_sensorname.cgi`: Set sensor name. (Page 50)
*   `del_sensor.cgi`: Delete a sensor. (Page 50)
*   `set_doorbell_push.cgi`: Set doorbell push notifications. (Page 51)
*   `get_sensor_preset.cgi`: Get guard position and alarm linkage preset. (Page 51)
*   `set_sensor_preset.cgi`: Set guard position and alarm linkage preset. (Page 51)

### Universal CGI Definition

To reduce the maintenance workload of middleware (like Android JNI, Windows P2PAPI.dll), a universal CGI is defined for interaction between the client and the device.

The `cmd` value of `CMD_CHANNEL_HEAD` is `0x60D1`.
The CGI command to get information is:
`trans_cmd_string.cgi?loginuse=&loginpas=&[user=&pwd=&]cmd=&[p1=]&[p2=]……`

The `cmd` is an integer defined according to actual needs. The device implements the corresponding function based on `cmd`. The content returned by the CGI is also defined by `cmd`, and the client parses the returned content based on `cmd`. The JNI or P2PAPI.dll will return the entire content to the client, and the client is responsible for parsing it. The length of the returned string is limited to 10K.

---
*This is a partial translation and summary of the key commands. For detailed parameters and return values, refer to the original PDF document.*
