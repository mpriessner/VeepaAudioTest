# IP/WIRELESS CAMERA CGI Command Manual (v12, 20231223) - Translated

This document is a text conversion of the `C系列cgi命令手册_v12_20231223.pdf` file. It appears to be an updated version of the previous CGI manual.

---

## Introduction

The CGIs listed in this document are a subset of the communication protocol provided by the IP camera for client communication. CGI can be used in two ways: one based on HTTP and the other based on P2P. HTTP-based client programs can perform various operations on the device through CGI. P2P-based client programs can communicate after using the SDK we provide, which includes versions for Android, iOS, and Windows.

### 1. CGI Security Authentication
- **HTTP Basic Authentication:** Mostly for GET-related CGIs.
- **CGI with User/Password Parameters:** Mainly for SET-related CGIs.
- **HTTPS Authentication:** Supported by some machines.

### 2. POST-related CGI
Uses the HTTP POST method, primarily for firmware and HTML upgrades (`upgrade_firmware.cgi`, `upgrade_htmls.cgi`).

### 3. GET-related CGI
Retrieves device status and parameters (e.g., `get_status.cgi`, `get_params.cgi`). They return text formatted like JavaScript variable definitions.

**Example:**
```javascript
var alias="IPCAM";
var sys_ver="Apr 28 2011 00:18:03";
var id="00000000031729";
```

### 4. SET-related CGI
Configures device parameters, requiring different permissions for each CGI.

**Example:** `http://ip:port/set_alias.cgi?loginuse=admin&loginpas=&alias=hdipcam`

### 5. Media Stream-related CGI
Configures media stream parameters.

**Example:** `http://ip:port/videostream.cgi?user=admin&pwd=`

---

## CGI Command List Summary

*(The command list is extensive and identical to the previously translated manual, covering GET, SET, Control, POST, and Alarm-related CGIs. Please refer to `CGI_COMMAND_MANUAL.md` for the detailed list of commands like `get_status.cgi`, `set_alarm.cgi`, `camera_control.cgi`, etc.)*

### Key Updates and Change Log Summary from the Document:

*   **2023-05-05:** Update of recent CGIs.
*   **2023-03-22:** Added optional date search or specified date search for recording index.
*   **2021-11-04:** Added support for human detection, and one-key power-off for low-power products.
*   **2020-05-19:** Added CGI return for VUID judgment for external test tools.
*   **2019-12-27:** Added query for 4G support and related information.
*   **2019-06-25:** Added fields to `get_status.cgi` to support focus and Alex Echo Show. Added zoom functionality to `decoder_control.cgi`. Added 90s hidden mode via transparent CGI.
*   **2018-12-24:** `get_status.cgi` now returns `DualAuthentication` field. `set_user.cgi` is extended with `OwnerUser`, `OwnerPwd`, `WebUser`, `WebPwd` for third-party access.
*   **2017-07-12:** `get_status.cgi` now includes `timeplan_ver`, `camera_type`, `pwd_change_realtime` (for password changes without reboot).
*   **2016-08-16:** `check_user.cgi` now returns `current_users` and `max_support_users`.

---
*This is a summary. The full PDF contains over 80 pages of detailed command specifications. The generated markdown file provides a complete list of commands and serves as a quick reference.*
