# Open Platform API Documentation v1.0

## Authentication

To prevent malicious tampering during the interface call process, any interface call requires carrying an authentication field. The server verifies authentication based on the request parameters, and requests with illegal authentication will be rejected.

### Authentication Process

Pass the `AccessKey` and `SecretKey` parameter fields in the interface headers.

**Host:** `https://open.eye4.cn`

```json
{
  "AccessKey": "6pCrDUjkDscEGlPV",
  "SecretKey": "P1fyTVZU1yaDc9K9"
}
```

---

## Obtain Product List

### Request Syntax

```http
POST /product/list HTTP/1.1
host: https://open.eye4.cn
AccessKey: n0***TyY
SecretKey: 6J***Y9
Content-Type: application/json; charset=utf-8
Connection: close
Content-Length: 2

{}
```

### Response

If the request is successful, the HTTP request status code is 200, and a JSON string containing the following content is returned:

```json
{
  "code": 0,
  "data": [
    {
      "name": "【Mainland China】Cloud storage monthly card (Cycle storage for 7 days)",
      "productId": "64649b8d9cbb8138a2f47078",
      "productType": "Motion detection cloud storage"
    }
  ],
  "msg": "success"
}
```

### Response Fields

| Field Name | Description |
|------------|-------------|
| productId | Product ID |
| name | Product name |
| productType | Product type (currently divided into motion detection cloud storage and low-power cloud storage) |

> Note: Includes low power consumption and long power supply types.

---

## Activate Service

### Request Syntax

```http
POST /service/open HTTP/1.1
AccessKey: n0***TyY
SecretKey: 6J***Y9
Content-Type: application/json; charset=utf-8
Connection: close
Content-Length: 2

{"target":"TEST123456ABCD","productId":"64649b8d9cbb8138a2f47078"}
```

### Request Fields

| Field Name | Type | Description |
|------------|------|-------------|
| target | string | Device ID, object of activating the service |
| productId | string | Product ID, obtained from product list |

### Response

If the request is successful, the HTTP request status code is 200, and a JSON string containing the following content is returned:

```json
{
  "code": 0,
  "msg": "success"
}
```

---

## Query Motion Detection Cloud Storage Activation Information

### Request Syntax

```http
POST /service/D004/info HTTP/1.1
AccessKey: n0***TyY
SecretKey: 6J***Y9
Content-Type: application/json; charset=utf-8
Connection: close
Content-Length: 2

{"target":"TEST123456ABCD"}
```

### Request Fields

| Field Name | Type | Description |
|------------|------|-------------|
| target | string | Device ID, object of activating the service |

### Response

If the request is successful, the HTTP request status code is 200, and a JSON string containing the following content is returned:

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

### Response Fields

| Field Name | Type | Description |
|------------|------|-------------|
| isOpen | boolean | Indicates whether activated or not |
| msg | string | Explanation |
| region | string | Cloud storage region |
| cycle | int | Cycle period |
| action | boolean | Whether it is activated or not. If the call is paused, the status is false |
| expirationTime | string | Expiration time (this time is in days) |

---

## Obtain Motion Detection Cloud Storage Authorization Information

### Request Syntax

```http
POST /service/D004/license HTTP/1.1
AccessKey: n0***TyY
SecretKey: 6J***Y9
Content-Type: application/json; charset=utf-8
Connection: close
Content-Length: 2

{"target":"TEST123456ABCD"}
```

### Request Fields

| Field Name | Type | Description |
|------------|------|-------------|
| target | string | Device ID |

### Response

If the request is successful, the HTTP request status code is 200, and a JSON string containing the following content is returned:

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

### Response Fields

| Field Name | Type | Description |
|------------|------|-------------|
| license | string | Authorization code |
| url | string | Cloud storage node API address |

> Note: Import these two parameters into the SDK to initialize the cloud storage playback business logic.

---

## Query Low-Power Cloud Storage Activation Information

### Request Syntax

```http
POST /service/D015/info HTTP/1.1
AccessKey: n0***TyY
SecretKey: 6J***Y9
Content-Type: application/json; charset=utf-8
Connection: close
Content-Length: 2

{"target":"TEST123456ABCD"}
```

### Request Fields

| Field Name | Type | Description |
|------------|------|-------------|
| target | string | Device ID, object of activating the service |

### Response

If the request is successful, the HTTP request status code is 200, and a JSON string containing the following content is returned:

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

### Response Fields

| Field Name | Type | Description |
|------------|------|-------------|
| isOpen | boolean | Indicates whether activated or not |
| msg | string | Explanation |
| cycle | int | Storage cycle of cloud storage |
| expirationTime | string | Cloud storage expiration time |
