# Cloud Video Interface Document (0106)

This document is a translation of `云视频接口文档0106.pdf`. It describes the API for interacting with the Eye4 cloud storage service.

**Base URL:** `https://open.eye4.cn`

**Unified Request Header:**
-   `AccessKey`: Your application's AccessKey.
-   `SecretKey`: Your application's SecretKey.

---

### 1. Corded Camera: Get Cloud Storage Summary

-   **Description:** Retrieves a summary of cloud storage usage, showing dates and the corresponding number of video clips.
-   **Method:** `POST`
-   **URL:** `$path/D004/summary/show`
    -   *Note: `path` and `licenseKey` are obtained from the motion detection cloud storage authorization API.*
-   **Body:**
    ```json
    {
        "licenseKey": "your_licenseKey",
        "uid": "camera_device_id",
        "timeZone": "client_timezone"
    }
    ```
-   **Example Result:**
    ```json
    {"20220224": 28, "20220225": 58, ...}
    ```

---

### 2. Corded Camera: Get Cloud Video Data for a Specific Day

-   **Description:** Retrieves detailed video clip information for a specific day.
-   **Method:** `POST`
-   **URL:** `$path/D004/group/show`
-   **Body:**
    ```json
    {
        "licenseKey": "your_licenseKey",
        "uid": "camera_device_id",
        "date": "2023-12-09",
        "timeZone": "client_timezone"
    }
    ```
-   **Example Result:** A list of video segments with start/end times and duration.

---

### 3. Corded Camera: Get Cloud Video URL for a Specific Time

-   **Description:** Retrieves the direct downloadable URL for a specific video clip.
-   **Method:** `POST`
-   **URL:** `$path/D004/file/url`
-   **Body:**
    ```json
    {
        "licenseKey": "your_licenseKey",
        "uid": "camera_device_id",
        "time": ["2023-11-29:03_50_29_06"]
    }
    ```
-   **Example Result:**
    ```json
    [
      {
        "name": "VE0005622QHOW_2023-11-29:03_50_29_06",
        "url": "http://d004-vstc.eye4.cn/VE0005622QHOW..."
      }
    ]
    ```

---

### 4. Corded Camera: Get Cloud Storage Video Thumbnail

-   **Description:** Retrieves the thumbnail/cover image for a specific video clip.
-   **Method:** `POST`
-   **URL:** `$path/D004/cover`
-   **Body:**
    ```json
    {
        "licenseKey": "your_licenseKey",
        "uid": "camera_device_id",
        "url": "the_video_url_from_the_previous_api_call"
    }
    ```

---

### 5. Low-Power Camera: Get Cloud Video Data

-   **Description:** Retrieves video data for low-power devices.
-   **Method:** `POST`
-   **URL:** `/push/fileid`
-   **Body:**
    ```json
    {
        "fileid": "fileId_from_message",
        "type": "D009"
    }
    ```
-   **Example Result:** A list of video segment URLs.
    -   **Note:** The device records in 5-second segments. A complete video is a concatenation of multiple segments. The video source should be a `NetworkVideoSource(urls)`.
