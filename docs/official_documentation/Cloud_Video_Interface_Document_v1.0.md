# Cloud Video Interface Document (v1.0)

This document is a translation of `云视频接口文档v1.0.pdf`. It outlines the API for the Eye4 cloud video service.

**Base URL:** `https://open.eye4.cn`

**Unified Request Header:**
-   `AccessKey`: Your application's AccessKey.
-   `SecretKey`: Your application's SecretKey.

---

### 1. Corded Camera: Get Cloud Storage Summary

-   **Description:** Retrieves a summary of cloud storage usage (dates and video counts).
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

---

### 2. Corded Camera: Get Cloud Video Data for a Specific Day

-   **Description:** Retrieves detailed video clip information for a given day.
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

---

### 3. Corded Camera: Get Cloud Video URL for a Specific Time

-   **Description:** Retrieves the direct downloadable URL for one or more video clips.
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

---

### 4. Corded Camera: Get Cloud Storage Video Thumbnail

-   **Description:** Retrieves the thumbnail for a specific video clip.
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
-   **Note:** Low-power devices record in 5-second segments. The full video is a concatenation of multiple segments from the URL list returned by this API.
