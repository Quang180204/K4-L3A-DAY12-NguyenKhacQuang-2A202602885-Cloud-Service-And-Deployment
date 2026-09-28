# Thông Tin Deploy — Checkpoint 5

> Điền file này sau khi deploy xong. `pytest tests/test_cp5.py` đọc file này
> để tìm địa chỉ service của bạn và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị API key vào đây.**
> Repo này công khai — dán khóa vào là mất khóa.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Nguyễn Khắc Quang |
| Mã học viên | 2A202602885 |
| Repo | https://github.com/Quang180204/K4-L3A-DAY12-NguyenKhacQuang-2A202602885-Cloud-Service-And-Deployment |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://day12-agent-rm10.onrender.com |
| Platform | Render |
| Ngày deploy | 28/9/2026 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | platform tự gán |
| `AGENT_API_KEY` | ✅ | đặt trong dashboard, không nằm trong repo |
| `REDIS_URL` | ✅ | Render Key Value `day12-redis`, được liên kết qua Blueprint |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

```powershell
$baseUrl = "https://day12-agent-rm10.onrender.com"

# 1. Liveness — mong đợi 200 {"status":"ok"}
Invoke-WebRequest -Uri "$baseUrl/health"

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
Invoke-WebRequest -Uri "$baseUrl/ready"

# 3. Không có API key — mong đợi 401
$body = @{ question = "Hello" } | ConvertTo-Json -Compress
try {
  Invoke-WebRequest -Uri "$baseUrl/ask" -Method Post `
    -ContentType "application/json" -Body $body
} catch {
  [int]$_.Exception.Response.StatusCode
}

# 4. Có API key — mong đợi 200 kèm câu trả lời
$headers = @{
  "X-API-Key" = $env:AGENT_API_KEY
  "X-User-Id" = "sv-test"
}
$body = @{ question = "Deploy là gì?" } | ConvertTo-Json -Compress
Invoke-WebRequest -Uri "$baseUrl/ask" -Method Post `
  -Headers $headers -ContentType "application/json" -Body $body

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
1..15 | ForEach-Object {
  try {
    $response = Invoke-WebRequest -Uri "$baseUrl/ask" -Method Post `
      -Headers $headers -ContentType "application/json" `
      -Body (@{ question = "test" } | ConvertTo-Json -Compress)
    $response.StatusCode
  } catch {
    if ($_.Exception.Response) {
      [int]$_.Exception.Response.StatusCode
    } else {
      throw
    }
  }
}
```

Trước bước 4, đặt `$env:AGENT_API_KEY` trong PowerShell bằng cùng khóa đã cấu hình
trên Render. Chỉ nhập khóa trong terminal của bạn, không ghi vào file này.

## Kết Quả Chạy Thật

Kết quả đã xác nhận trên service công khai:

```
GET /health → HTTP 200
{"status":"ok","service":"day12-agent","version":"1.0.0"}

GET /ready → HTTP 200
{"status":"ready","redis":true}

POST /ask không có API key → HTTP 401
```

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trang quản lý service trên platform
- `screenshots/health.png` — kết quả gọi `/health` từ trình duyệt hoặc PowerShell
