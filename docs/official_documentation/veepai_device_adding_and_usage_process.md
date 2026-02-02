# Veepai Device Adding and Usage Process

This document is a summary of the mind map in `veepai 设备添加和使用流程.pdf`.

## Process Overview

The overall process can be broken down into two main parts: Adding a device and interacting with an added device.

---

### 1. Adding a Device

The method for adding a device depends on its type (4G or WiFi).

#### For 4G Devices:
-   The device ID and password are used to bind the device to the server.

#### For WiFi Devices:
1.  **Network Configuration:** The mobile app generates a QR code containing network credentials (SSID, password, etc.).
    -   **QR Code Content Example:** `{"BS":"e0d462e663b0","P":"1111111111","U":"12965091","RS":"vstarcam123"}`
2.  **Device Scans QR Code:** The camera scans this QR code to get the WiFi credentials and connect to the network.
3.  **Binding:** After successfully connecting to the network, the device ID and password are used to bind the device to the server.

---

### 2. Interacting with an Added Device (Connection Flow)

Once a device is added, the app interacts with it following these steps:

#### Step 1: Create `CameraDevice` Object
-   Instantiate the main SDK object for the device.
    ```dart
    CameraDevice mDevice = CameraDevice('VP0191279WWIS', '4G', 'admin', '70312622c2eec424', 'model');
    ```

#### Step 2: Connect to the Device
-   Call the `connect()` method on the `CameraDevice` object. This is an asynchronous operation.
    ```dart
    var connectState = await mDevice.connect();
    ```

#### Step 3: Handle Connection Result
-   The `connect()` method returns a `CameraConnectState` enum, which indicates the status of the connection. The possible states are:
    -   `connecting`: In the process of connecting.
    -   `logging`: Logging in.
    -   `connected`: **Online and ready.**
    -   `timeout`: Connection timed out.
    -   `disconnect`: Connection was interrupted.
    -   `password`: **Password error.**
    -   `maxUser`: Maximum number of concurrent viewers reached.
    -   `offline`: Device is offline.
    -   `illegal`: Illegal device.
    -   `none`: No state.

#### Step 4: Read/Write Data
-   Once connected, you can communicate with the device using CGI commands.
    -   **Write:** `mDevice.writeCgi(...)`
    -   **Read:** `mDevice.waitCommandResult(...)`

---

### 3. Live Streaming

To view the live video feed:

#### Step 1: Create Player
-   Instantiate the `AppPlayerController`.

#### Step 2: Request Video Stream
-   Call the `startStream` method on the connected `mDevice` object.
    ```dart
    mDevice.startStream();
    ```
