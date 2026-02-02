# Device Alarm Reception Integration Process

**Last Updated:** October 23, 2023

Device alarm information can be obtained through asynchronous notifications.

---

## 1. Flow Diagram

```
┌────────────┐     ① Device triggers alarm,      ┌────────────┐     ③ Async notification     ┌────────────────┐
│            │        sends alarm info           │            │        to customer server   │                │
│   Device   │ ─────────────────────────────────>│ Eye4 System│ ─────────────────────────>  │ Customer Server│
│            │                                   │            │                              │                │
│            │ <─────────────────────────────────│            │                              │                │
└────────────┘     ② System responds that        └────────────┘                              └────────────────┘
                     alarm was received
```

---

## 2. Alarm Message Structure Example

When a device triggers an alarm event, it will immediately report the message to the system. Since on-site video requires recording time, the device will upload the video to cloud storage after recording is complete. Therefore, one alarm event is divided into two messages.

### Alarm Message Structure

The first message to arrive at the system is the alarm message:

```json
{
  "type": "doorbell",
  "action": "100",
  "did": "<-- Device ID -->",
  "payload": {
    "electricity": "<-- Battery Level -->",
    "fileid": "<-- File Unique Identifier -->"
  },
  "cover": "<-- Cover Image -->"
}
```

### Alarm Message Fields

| Parameter | Type | Description |
|-----------|------|-------------|
| did | String | Device unique identifier |
| type | String | Device type |
| action | String | Alarm message action code: `100` = Door sensor opened / PIR human detection triggered, `101` = Low battery reminder |
| cover | String | Cover image URL |
| payload | String | Custom data, defined by the device |

---

## 3. Resource Message Structure Example

When the device completes uploading the resource file, a callback notification is triggered:

```json
{
  "key": "<-- Corresponds to fileid in alarm message -->",
  "region": "<-- Resource file storage region -->",
  "d009_id": "<-- Business ID -->"
}
```

### Resource Message Fields

| Parameter | Type | Description |
|-----------|------|-------------|
| d009_id | String | Unique identifier of the resource file, corresponds to `fileid` in the alarm message structure |
| region | String | Resource file storage region |
| key | String | Uploaded resource file name |

---

## 4. Get Resource Playback URL

Obtain the download URL based on `fileid`.

### Request Syntax

```http
POST /push/fileid HTTP/1.1
Content-Type: application/json; charset=utf-8
Host: api.eye4.cn
Content-Length: 114

{"fileid":"f991d9064ac71fad6a9fae22d17a4aab9f5b264d","type":"D009"}
```

### Request Parameter Description

| Parameter | Type | Description |
|-----------|------|-------------|
| userid | String | User unique identifier |
| authkey | String | Authorization code |
| fileid | String | Cloud storage resource unique identifier |
| type | String | Resource type identifier: `D005` = Alarm cloud storage, `D009` = DB1 doorbell cloud storage |

### Response

If the request is successful, the HTTP request status code is 200, and a JSON string containing the following content is returned:

```json
[
  {
    "file_name": "http://alarmvstc.eye4.cn/alarm_image_VSTB366562CWVTV_20170306125805.jpg?e=1488875341&token=FSwzdzAjD8SHgZr6mnamWy2MNFSpjDu7-I7vX9ZO:MDE_oYGUAbGV7NnB8UM5NOI8SsI=",
    "file_Type": "image"
  },
  {
    "file_name": "http://alarmvstc.eye4.cn/alarm_video_VSTB366562CWVTV_20170306125804.h264?e=1488875341&token=FSwzdzAjD8SHgZr6mnamWy2MNFSpjDu7-I7vX9ZO:PAEKC0ZhjNIAN9IgR5AahiYDscY=",
    "file_Type": "video"
  }
]
```

### Response Field Description

| Key | Description |
|-----|-------------|
| file_name | Download URL |
| file_Type | File type |

### Response Codes

If the resource has expired (30 days), an empty array `[]` is returned.

---

## 5. Important Notes

1. **Separate callback interfaces are recommended** for receiving alarm messages and resource files to handle them separately.

2. **Resource messages are not 100% guaranteed** to exist. Due to network issues and various other problems, resource files may be lost. The integrating party needs to implement error tolerance.

3. **HTTP requests from the Eye4 system** will always carry a fixed `guid` field in the header. The integrating party can check the `guid` field to prevent others from forging alarm messages.

4. **Resource file default validity period** is 30 days.
