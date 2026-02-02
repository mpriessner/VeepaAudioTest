# Cloud Video API Documentation

**Base URL:** `https://open.eye4.cn`

---

## Unified Request Header Information

```
headers["AccessKey"] = "6p****V";  // Use your own AccessKey
headers["SecretKey"] = "P1***K9";  // Use your own SecretKey
```

---

## Long-Power Devices: Get Cloud Storage Summary (Dates and Corresponding Video Counts)

**Request Method:** POST

**Request URL:** `$path/D004/summary/show`

> Note: The `path` and `licenseKey` parameter are obtained from the motion detection cloud storage authorization information API.

### Request Parameters

```json
{
  "licenseKey": "licenseKey",
  "uid": "uid",
  "timeZone": "zone"
}
```

| Parameter | Type | Description |
|-----------|------|-------------|
| licenseKey | String | Authorization information, obtained from API |
| uid | String | Device ID |
| timeZone | String | Timezone: `FlutterNativeTimezone.getLocalTimezone()` |

### Response Example

```json
{
  "20220224": 28,
  "20220225": 58,
  "20220226": 4,
  "20220227": 0,
  "20220228": 130,
  "20220301": 336,
  "20220302": 1332,
  "20220303": 0
}
```

---

## Long-Power Devices: Get Cloud Video Data for a Specific Day

**Request Method:** POST

**Request URL:** `$path/D004/group/show`

> Note: The `path` and `licenseKey` parameter are obtained from the motion detection cloud storage authorization information API.

### Request Parameters

```json
{
  "licenseKey": "licenseKey",
  "uid": "uid",
  "date": "time",
  "timeZone": "zone"
}
```

| Parameter | Type | Description |
|-----------|------|-------------|
| licenseKey | String | Authorization information, obtained from API |
| uid | String | Device ID |
| date | String | Date in YYYY-MM-DD format, e.g., `2023-12-09` |
| timeZone | String | Timezone: `FlutterNativeTimezone.getLocalTimezone()` |

### Response Example

```json
[
  {
    "start": 42629,
    "end": 42891,
    "duration": 262,
    "original": [
      {
        "key": "2023-11-29:03_50_29_06",
        "hour": "11",
        "type": "h264",
        "eventMark": "1",
        "start_index": 42629,
        "end_index": 42635
      },
      {
        "key": "2023-11-29:03_50_35_06",
        "hour": "11",
        "type": "h264",
        "eventMark": "1",
        "start_index": 42635,
        "end_index": 42641
      }
    ]
  }
]
```

---

## Long-Power Devices: Get Cloud Video Data for a Specific Time Point

**Request Method:** POST

**Request URL:** `$path/D004/file/url`

> Note: The `path` and `licenseKey` parameter are obtained from the motion detection cloud storage authorization information API.

### Request Parameters

```json
{
  "licenseKey": "licenseKey",
  "uid": "uid",
  "time": "time"
}
```

| Parameter | Type | Description |
|-----------|------|-------------|
| licenseKey | String | Cloud storage authorization information, obtained from API |
| uid | String | Device ID |
| time | List\<String\> | Video time, e.g., `["2023-11-29:03_50_29_06"]` |

### Response Example

```json
[
  {
    "name": "VE0005622QHOW_2023-11-29:03_50_29_06",
    "url": "http://d004-vstc.eye4.cn/VE0005622QHOW_2023-11-29:03_50_29_06?e=1701264785&token=l5gvKghs6BCqoVtQJOkLwykc7JtTnXvUCGgl2AzZ:3QHpPvjYp2LZrQ0tpCjG1AqzYmk="
  }
]
```

---

## Long-Power Devices: Get Cloud Storage Video Cover Image

**Request Method:** POST

**Request URL:** `$path/D004/cover`

> Note: The `path` and `licenseKey` parameter are obtained from the motion detection cloud storage authorization information API.

### Request Parameters

```json
{
  "licenseKey": "licenseKey",
  "uid": "uid",
  "url": "url"
}
```

| Parameter | Type | Description |
|-----------|------|-------------|
| licenseKey | String | Cloud storage authorization information, obtained from API |
| uid | String | Device ID |
| url | String | The first URL from the cloud video data array at a specific time point |

---

## Low-Power Devices: Get Cloud Video Data

**Request Method:** POST

**Request URL:** `/push/fileid`

### Request Parameters

```javascript
jsonEncode({
  "fileid": fileId,  // Obtain this value from the message
  "type": fileType   // "D009"
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| fileid | String | File ID, obtained from Message |
| fileType | String | File type, `"D009"` |

### Response Example

```json
[
  {
    "file_name": "http://d015-z0.eye4.cn//tmp/HTB0005151PQSU_2023-12-08-07-57-50_01_0?e=1702277606&token=l5gvKghs6BCqoVtQJOkLwykc7JtTnXvUCGgl2AzZ:gL0UVClR9oFAcpSuuh534cqGk2k=",
    "file_Type": "video"
  },
  {
    "file_name": "http://d015-z0.eye4.cn//tmp/HTB0005151PQSU_2023-12-08-07-57-55_01_1?e=1702277606&token=l5gvKghs6BCqoVtQJOkLwykc7JtTnXvUCGgl2AzZ:JUzTflgT0vSZlVGtV899ddOg50=",
    "file_Type": "video"
  }
]
```

### Note

The device records in segments, with each segment being 5 seconds long. The total length of a complete video should be the combined duration of multiple videos in the array.

Video source: `NetworkVideoSource(urls)`
