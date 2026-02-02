# Equipment Alarm Receiving and Access Process

**Update date:** October 23, 2023

The device alarm information can be obtained by asynchronous notification.

---

## 1. Flow Chart

```
[Device] --(1) Triggers alarm, sends info --> [Eye4 System] --(3) Async notification --> [Customer Server]
          <--(2) System responds: received --
```
1.  Device triggers an alarm and sends the alarm information.
2.  The Eye4 System acknowledges receipt to the device.
3.  The Eye4 System sends an asynchronous notification to the customer's server.

---

## 2. Example of an Alarm Message Structure

When a device triggers an alarm, it reports the message immediately. Because live video requires a certain recording time, the video is uploaded to cloud storage *after* the recording. Therefore, an alarm event is divided into two messages. The first one is the alarm message itself.

**Structure:**
```json
{
    "type": "doorbell",
    "action": "100",
    "did": "<--Device ID-->",
    "payload": {
        "electricity": "<--Power-->",
        "fileid": "<--The file is uniquely labeled as the-->",
        "cover": "<--Cover picture-->"
    }
}
```

**Parameters:**

| Parameter | Type   | Explanation                                                              |
| :-------- | :----- | :----------------------------------------------------------------------- |
| `did`     | String | The unique number of the equipment.                                      |
| `type`    | String | Device type.                                                             |
| `action`  | String | Message action code. `100`: Door magnet opened / PIR human detection. `101`: Low power reminder. |
| `cover`   | String | The URL for the cover image/thumbnail.                                   |
| `payload` | String | Custom data, defined by the device side.                                 |

---

## 3. Example of the Resource Message Structure

A callback notification is triggered when the device uploads the resource file (the video).

**Structure:**
```json
{
    "Key": "<--fileid-->", // from the alarm message
    "region": "<--Resource File Storage area-->",
    "d009_id": "<--, business number ID-->"
}
```

**Parameters:**

| Parameter | Type   | Explanation                                                              |
| :-------- | :----- | :----------------------------------------------------------------------- |
| `d009_id` | String | Unique ID of the resource file, corresponds to `fileid` in the alarm message. |
| `region`  | String | Resource file storage area.                                              |
| `key`     | String | The uploaded resource file name.                                         |

---

## 4. Get the Resource Playback Address

Use the `fileid` to obtain the download address.

-   **Request:** `POST /push/fileid HTTP/1.1`
-   **Host:** `api.eye4.cn`
-   **Body:**
    ```json
    {
        "fileid": "f 991d 9064ac 71fad6a9fae22d17a4aab9f5b264d",
        "type": "D009"
    }
    ```

**Request Parameters:**

| Parameter | Type   | Explanation                                                            |
| :-------- | :----- | :--------------------------------------------------------------------- |
| `userid`  | String | User-specific and unique labeling.                                     |
| `authkey` | String | Authorization code.                                                    |
| `fileid`  | String | Unique identifier of the cloud storage resource.                       |
| `type`    | String | Resource type (`D005`: Alarm cloud storage, `D009`: Doorbell cloud storage). |

-   **Successful Response (200 OK):** A JSON array containing file information.
    ```json
    [
        {
            "file_name": "http://alarm-vstc.eye4.cn/alarm_image_....jpg?e=...",
            "file_Type": "image"
        },
        {
            "file_name": "http://alarm-vstc.eye4.cn/alarm_video_....h264?e=...",
            "file_Type": "video"
        }
    ]
    ```

**Response Fields:**

| Key         | Explanation      |
| :---------- | :--------------- |
| `file_name` | Download link.   |
| `file_Type` | Document type.   |

**Error Handling:**
If the resource has expired (default is 30 days), the API returns an empty `[]` array.

---

## V. Matters Needing Attention

1.  It is recommended to receive alarm messages and resource file callbacks on separate interfaces.
2.  Resource messages are not guaranteed to arrive 100% of the time. The accessing party needs to be fault-tolerant to handle potential loss of resource files due to network issues.
3.  For HTTP requests from the Eye4 system, the header will have a fixed `guid` field. The user can judge this field to prevent forged alarm messages.
4.  The default validity period of resource documents is 30 days.
