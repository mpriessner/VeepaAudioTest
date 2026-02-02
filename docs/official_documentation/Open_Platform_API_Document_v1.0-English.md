# Open Platform API Document v1.0 (English)

This document is a conversion of `开放平台API文档v1.0-英文.pdf`.

---

## Authentication

To prevent malicious tampering during interface calls, every request must include authentication fields. The server validates these fields.

-   **Host:** `https://open.eye4.cn`
-   **Headers:**
    -   `AccessKey`: "6pCrDUjkDscEGIPV" (Use your own AccessKey)
    -   `SecretKey`: "P1fyTVZU1yaDc9K9" (Use your own SecretKey)

---

## 1. Obtain Product List

-   **Endpoint:** `POST /product/list`
-   **Description:** Retrieves a list of available cloud storage products.
-   **Request Body:** `{}`
-   **Successful Response (`200 OK`):**
    ```json
    {
      "code": 0,
      "msg": "success",
      "data": [
        {
          "name": "【Mainland China】 Cloud storage monthly card (Cycle storage for 7 days)",
          "productId": "64649b8d9cbb8138a2f47078",
          "productType": "Motion detection cloud storage"
        }
      ]
    }
    ```

---

## 2. Activate Service

-   **Endpoint:** `POST /service/open`
-   **Description:** Activates a specified cloud service for a target device.
-   **Request Body:**
    ```json
    {
      "target": "DEVICE_ID",
      "productId": "PRODUCT_ID"
    }
    ```
-   **Successful Response (`200 OK`):**
    ```json
    {
      "code": 0,
      "msg": "success"
    }
    ```

---

## 3. Query Motion Detection Cloud Storage Activation Information

-   **Endpoint:** `POST /service/D004/info`
-   **Description:** Queries the activation status of motion detection cloud storage for a device.
-   **Request Body:**
    ```json
    {
      "target": "DEVICE_ID"
    }
    ```
-   **Successful Response (`200 OK`):**
    ```json
    {
      "code": 0,
      "msg": "success",
      "data": {
        "isOpen": true,
        "msg": "Cloud storage activated",
        "region": "frankfurt",
        "action": true,
        "cycle": 7,
        "expirationTime": "2024-05-06"
      }
    }
    ```

---

## 4. Obtain Motion Detection Cloud Storage Authorization

-   **Endpoint:** `POST /service/D004/license`
-   **Description:** Gets the license and URL required to initialize the cloud storage playback logic in the SDK.
-   **Request Body:**
    ```json
    {
      "target": "DEVICE_ID"
    }
    ```
-   **Successful Response (`200 OK`):**
    ```json
    {
      "code": 0,
      "msg": "success",
      "data": {
        "license": "mHsZafq5pecuL***zLJoI09mWsN/LOagA==",
        "url": "***"
      }
    }
    ```

---

## 5. Query Low-Power Cloud Storage Activation Information

-   **Endpoint:** `POST /service/D015/info`
-   **Description:** Queries the activation status of cloud storage for a low-power device.
-   **Request Body:**
    ```json
    {
      "target": "DEVICE_ID"
    }
    ```
-   **Successful Response (`200 OK`):**
    ```json
    {
      "code": 0,
      "msg": "success",
      "data": {
        "isOpen": true,
        "msg": "Cloud storage activated",
        "cycle": 30,
        "expirationTime": "2024-10-30"
      }
    }
    ```
