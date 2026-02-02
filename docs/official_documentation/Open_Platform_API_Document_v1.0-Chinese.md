# 开放平台API文档1.0版 (Open Platform API Document v1.0)

This is a conversion of `开放平台API文档v1.0.pdf`.

---

## 鉴权 (Authentication)

为了防止接口调用过程中被恶意篡改,调用任何一个接口都需要携带鉴权字段,服务端根据请求参数,对鉴权进行验证,鉴权不合法的请求将会被拒绝。

-   **Host:** `https://open.eye4.cn`
-   **Headers:**
    -   `AccessKey`: "n0***TyY" (请用自己的AccessKey)
    -   `SecretKey`: "6J***Y9" (请用自己的SecretKey)

---

## 获取产品列表 (Obtain Product List)

-   **Endpoint:** `POST /product/list`
-   **描述:** 获取可用的云存储产品列表。
-   **请求体:** `{}`
-   **成功响应 (`200 OK`):**
    ```json
    {
      "code": 0,
      "msg": "success",
      "data": [
        {
          "name": "【大陆地区】云存储月卡(7天)",
          "productId": "64649b8d9cbb8138a2f47078",
          "productType": "移动侦测云存储"
        }
      ]
    }
    ```

---

## 服务开通 (Activate Service)

-   **Endpoint:** `POST /service/open`
-   **描述:** 为指定设备开通云服务。
-   **请求体:**
    ```json
    {
      "target": "设备ID",
      "productId": "产品ID"
    }
    ```
-   **成功响应 (`200 OK`):**
    ```json
    {
      "code": 0,
      "msg": "success"
    }
    ```

---

## 查询移动侦测云存储开通信息 (Query Motion Detection Cloud Storage Activation Information)

-   **Endpoint:** `POST /service/D004/info`
-   **描述:** 查询设备的移动侦测云存储的开通状态。
-   **请求体:**
    ```json
    {
      "target": "设备ID"
    }
    ```
-   **成功响应 (`200 OK`):**
    ```json
    {
      "code": 0,
      "msg": "success",
      "data": {
        "isOpen": true,
        "msg": "已经开通云存储",
        "region": "frankfurt",
        "action": true,
        "cycle": 7,
        "expirationTime": "2024-05-06"
      }
    }
    ```

---

## 获取移动侦测云存储授权信息 (Obtain Motion Detection Cloud Storage Authorization Information)

-   **Endpoint:** `POST /service/D004/license`
-   **描述:** 获取初始化云存储回放业务逻辑所需的授权码和API地址。
-   **请求体:**
    ```json
    {
      "target": "设备ID"
    }
    ```
-   **成功响应 (`200 OK`):**
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

## 查询低功耗云存储开通信息 (Query Low-Power Cloud Storage Activation Information)

-   **Endpoint:** `POST /service/D015/info`
-   **描述:** 查询低功耗设备的云存储开通状态。
-   **请求体:**
    ```json
    {
      "target": "设备ID"
    }
    ```
-   **成功响应 (`200 OK`):**
    ```json
    {
      "code": 0,
      "msg": "success",
      "data": {
        "isOpen": true,
        "msg": "已经开通云存储",
        "cycle": 30,
        "expirationTime": "2024-10-30"
      }
    }
    ```
