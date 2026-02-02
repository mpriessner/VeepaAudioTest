# Open Platform API Documentation (20231123)

This document is a conversion of `Open Platform API Documentation_20231123.pdf`.

---

## Authentication

To prevent malicious tampering, all interface calls require authentication fields. The server verifies requests based on these parameters.

-   **Host:** `https://open.eye4.cn`
-   **Headers:**
    -   `AccessKey`: "6pCrDUjkDscEGIPV" (Use your own AccessKey)
    -   `SecretKey`: "P1fyTVZU1yaDc9K9" (Use your own SecretKey)

---

## Obtain Product List

-   **Endpoint:** `POST /product/list`
-   **Description:** Retrieves a list of available cloud storage products.
-   **Response (`200 OK`):**
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
-   **Fields:**
    -   `productId`: The ID of the product.
    -   `name`: The name of the product.
    -   `productType`: Type of product (e.g., motion detection cloud storage, low-power cloud storage).

---

## Activate Service

-   **Endpoint:** `POST /service/open`
-   **Description:** Activates a cloud storage service for a device.
-   **Request Body:**
    ```json
    {
      "target": "DEVICE_ID",
      "productId": "PRODUCT_ID_FROM_LIST"
    }
    ```
-   **Response (`200 OK`):**
    ```json
    {
      "code": 0,
      "msg": "success"
    }
    ```

---

## Query Motion Detection Cloud Storage Activation Information

-   **Endpoint:** `POST /service/D004/info`
-   **Description:** Checks the activation status of cloud storage for a specific device.
-   **Request Body:**
    ```json
    {
      "target": "DEVICE_ID"
    }
    ```
-   **Response (`200 OK`):**
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

## Obtain Motion Detection Cloud Storage Authorization Information

-   **Endpoint:** `POST /service/D004/license`
-   **Description:** Gets the authorization code and API address needed to initialize the cloud storage playback logic in the SDK.
-   **Request Body:**
    ```json
    {
      "target": "DEVICE_ID"
    }
    ```
-   **Response (`200 OK`):**
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
-   **Action:** Import the `license` and `url` parameters into the SDK to initialize playback.

---

## Query Low-Power Cloud Storage Activation Information

-   **Endpoint:** `POST /service/D015/info`
-   **Description:** Checks the activation status for low-power cloud storage.
-   **Request Body:**
    ```json
    {
      "target": "DEVICE_ID"
    }
    ```
-   **Response (`200 OK`):**
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
