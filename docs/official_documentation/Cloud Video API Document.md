# Cloud Video API Document

**Base URL:** `https://open.eye4.cn`

**Unified Request Header:**
```
headers["AccessKey"] = "6p****V"; // Please use your AccessKey
headers["SecretKey"] = "P1***K9"; // Please use your SecretKey
```

---

### Corded Electric Camera: Get Cloud Storage Summary
Get a summary of cloud storage (date and corresponding number of videos).

- **Method:** `POST`
- **URL:** `$path/D004/summary/show` (Note: `path` and `licenseKey` parameters are obtained from the motion detection cloud storage API)
- **Request Body:**
  ```json
  {
      "licenseKey": "your_licenseKey",
      "uid": "camera_uid",
      "timeZone": "client_timezone"
  }
  ```
- **Example Result:**
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

### Corded Electric Camera: Get Cloud Video Data for a Specified Day

- **Method:** `POST`
- **URL:** `$path/D004/group/show` (Note: `path` and `licenseKey` from motion detection cloud storage API)
- **Request Body:**
  ```json
  {
      "licenseKey": "your_licenseKey",
      "uid": "camera_uid",
      "date": "2023-12-09",
      "timeZone": "client_timezone"
  }
  ```
- **Example Result:**
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
          ...
        }
      ]
    }
  ]
  ```

---

### Corded Electric Camera: Get Cloud Video Data at a Specified Time

- **Method:** `POST`
- **URL:** `$path/D004/file/url` (Note: `path` and `licenseKey` from motion detection cloud storage API)
- **Request Body:**
  ```json
  {
      "licenseKey": "your_licenseKey",
      "uid": "camera_uid",
      "time": ["2023-11-29:03_50_29_06"]
  }
  ```
- **Example Result:**
  ```json
  [
    {
      "name": "VE0005622QHOW_2023-11-29:03_50_29_06",
      "url": "http://d004-vstc.eye4.cn/VE0005622QHOW_2023-11-29:03_50_29_06?e=..."
    }
  ]
  ```

---

### Corded Electric Camera: Get Video Cover Data from Cloud Storage

- **Method:** `POST`
- **URL:** `$path/D004/cover` (Note: `path` and `licenseKey` from motion detection cloud storage API)
- **Request Body:**
  ```json
  {
      "licenseKey": "your_licenseKey",
      "uid": "camera_uid",
      "url": "video_url_from_previous_request"
  }
  ```

---

### Low-Power Camera: Get Cloud Video Data

- **Method:** `POST`
- **URL:** `/push/fileid`
- **Request Body:**
  ```json
  {
      "fileid": "fileid_from_message",
      "type": "D009"
  }
  ```
- **Example Result:**
  ```json
  [
    {
      "file_name": "http://d015-z0.eye4.cn//tmp/HTB0005151PQSU_2023-12-08-07-57-50_01_0?e=...",
      "file_Type": "video"
    },
    {
      "file_name": "http://d015-z0.eye4.cn//tmp/HTB0005151PQSU_2023-12-08-07-57-55_01_1?e=...",
      "file_Type": "video"
    }
  ]
  ```
- **Note:** The device records in segments, each lasting 5 seconds. The total length of a complete video should be the sum of the durations of multiple videos stitched together from the array. The video source is: `NetworkVideoSource(urls)`.
