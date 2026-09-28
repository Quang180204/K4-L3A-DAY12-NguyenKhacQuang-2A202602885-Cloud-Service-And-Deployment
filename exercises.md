# Phiếu Phản Ánh — K4 Level 3A, Ngày 12

> Họ và tên: Nguyễn Khắc Quang  Mã học viên: 2A202602885

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Giả sử tôi deploy lên Render nhưng quên cấu hình biến `AGENT_API_KEY` trên dashboard. Nếu để mặc định `"changeme"`, app vẫn khởi động thành công, `curl /health` trả 200 — tôi tưởng mọi thứ ổn. Nhưng bất kỳ ai cũng có thể gọi `/ask` với header `X-API-Key: changeme` và tiêu thoải mái ngân sách LLM của tôi mà không cần crack gì cả. Tôi chỉ phát hiện ra khi nhìn hóa đơn cuối tháng. Ngược lại, khi `agent_api_key` không có giá trị mặc định, app ném `ValidationError` ngay lúc khởi động — container crash, health check không pass, Render không cho traffic vào và gửi alert ngay cho tôi. Tôi sửa biến môi trường trong vài giây, deploy lại là xong, không mất một đồng nào.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Dòng log thu được khi gọi `/ask`:
> ```
> {"event": "ask_completed", "level": "info", "timestamp": "2026-09-28T10:15:32+00:00", "user_id": "sv-test", "tokens_in": 42, "tokens_out": 118, "cost_usd": 0.00023}
> ```
>
> Hai việc làm được mà `print("đã trả lời xong")` không làm được:
>
> 1. **Lọc và thống kê theo điều kiện**: Với log JSON, tôi có thể dùng `jq` hoặc Datadog để hỏi "user nào tiêu nhiều nhất hôm nay?" — ví dụ: `cat log.json | jq 'select(.event=="ask_completed") | {user_id, cost_usd}' | jq -s 'group_by(.user_id)'`. Với `print("đã trả lời xong")` chỉ là chuỗi thuần, không thể tự động tách và nhóm theo trường.
>
> 2. **Cảnh báo tự động khi vượt ngưỡng**: Platform log (Railway, Render, Datadog...) đọc từng dòng JSON như một object có cấu trúc, cho phép tôi tạo alert rule "khi `cost_usd > 0.1` thì gửi email". `print()` chỉ ra chuỗi văn bản — hệ thống log không thể tự biết trường `cost_usd` nằm ở đâu trong đó.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ~1050 MB |
| Multi-stage | ~210 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Phần chênh lệch ~840 MB đến từ những thứ stage `builder` cài nhưng stage `runtime` không cần giữ lại:
>
> - **Compiler và build tools** (`gcc`, `build-essential`): Python cần biên dịch một số package C (như `cryptography`, `pydantic-core`) trong lúc `pip install`. Sau khi build xong các file `.so`, compiler không còn vai trò gì nữa.
> - **Cache của pip** (`~/.cache/pip`): file wheel tải về để cài nhưng không cần chạy.
> - **Header file và thư viện phát triển** (`*.h`, `libpython-dev`): chỉ cần khi biên dịch, không cần khi chạy.
> - **Source code của pip và setuptools** trong Python image đầy đủ.
>
> Multi-stage build giải quyết bằng cách: stage `builder` làm hết việc nặng rồi "bị bỏ". Stage `runtime` chỉ `COPY --from=builder /install /usr/local` — tức là chỉ copy các file `.so` và `.py` đã biên dịch xong, không mang theo bất kỳ tool phát triển nào.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Với Dockerfile hiện tại (thứ tự đúng):
> ```
> COPY requirements.txt .          ← layer 1
> RUN pip install ...              ← layer 2 (nặng, ~60s)
> COPY app ./app                   ← layer 3
> COPY utils ./utils               ← layer 4
> ```
> Khi sửa một ký tự trong `app/main.py`, Docker so sánh checksum và thấy `requirements.txt` **không đổi** → layer 1 và layer 2 (pip install) được dùng lại từ cache. Chỉ layer 3 trở đi phải chạy lại. Tổng thời gian build lại chỉ vài giây.
>
> Nếu đặt `COPY . .` lên trước `RUN pip install`:
> ```
> COPY . .                         ← layer 1 (copy toàn bộ source)
> RUN pip install ...              ← layer 2
> ```
> Sửa bất kỳ dòng nào trong `app/main.py` sẽ làm layer 1 thay đổi → Docker invalidate cache từ layer 1 → **buộc phải chạy lại pip install**. Mỗi lần sửa 1 dấu phẩy là phải chờ 60 giây cài lại toàn bộ thư viện — hoàn toàn lãng phí.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện khi chạy bằng root:
>
> 1. Code có lỗ hổng RCE (ví dụ: eval đầu vào người dùng trong `/ask`, hoặc lỗ hổng trong một thư viện dependency).
> 2. Kẻ tấn công gửi payload độc hại, chiếm được quyền chạy lệnh tùy ý **bên trong container với quyền root**.
> 3. Vì container chạy root và Docker daemon mặc định chia sẻ kernel với host, kẻ tấn công có thể dùng các kỹ thuật container escape (lỗ hổng kernel, mount `/proc/sysrq-trigger`, ghi vào `/etc/crontab` nếu volume mount...) để **thoát khỏi container lên host với quyền root**.
> 4. Từ đó, kẻ tấn công có thể đọc secret của các container khác, phá hủy dữ liệu, hoặc dùng host làm bàn đạp tấn công tiếp.
>
> Lệnh `USER appuser` cắt đứt chuỗi **tại bước 2**: dù kẻ tấn công chiếm được quyền chạy lệnh, họ chỉ có quyền của `appuser` (UID 10001) — không thể `chmod`, không thể mount filesystem đặc biệt, không thể ghi vào `/etc`. Các container escape exploit hầu hết yêu cầu quyền root, nên đây là tường chắn quan trọng.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> Với đếm theo phút đồng hồ (reset lúc giây 00) và hạn mức 10 request/phút, người dùng có thể gửi **tối đa 20 request trong 2 giây liên tiếp**:
>
> - Gửi 10 request từ giây :58 đến :59 (cuối phút 1) — đúng hạn mức, không bị chặn.
> - Đồng hồ reset lúc :00 — counter归零.
> - Gửi thêm 10 request từ giây :00 đến :01 (đầu phút 2) — lại đúng hạn mức.
>
> Kết quả: 20 request trong khoảng 2–3 giây, gấp đôi hạn mức. Với sliding window 60 giây, bất kỳ thời điểm nào cũng chỉ tính 60 giây gần nhất, nên 10 request ở giây :58-:59 vẫn còn trong cửa sổ khi tính từ giây :00 — không cho phép gửi thêm cho đến khi các request đó rời khỏi cửa sổ (lúc giây :58 của phút tiếp theo).

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> **Sự khác nhau cốt lõi:**
> - **Rate limit** đếm *số lượng request* trong một khoảng thời gian — kiểm soát tần suất gọi API, bất kể mỗi request tốn bao nhiêu tiền.
> - **Cost guard** đếm *số tiền đã tiêu* trong tháng — kiểm soát ngân sách tổng, bất kể tần suất gọi.
>
> **Tình huống rate limit cho qua nhưng cost guard chặn:**
> Người dùng gửi 5 request/phút (dưới hạn mức 10/phút), nhưng mỗi câu hỏi là một đoạn văn 10.000 từ cần 50k token để xử lý. Sau 3 request đầu tháng, họ đã tiêu $9.5 USD trên ngân sách $10. Request thứ 4 — dù tần suất hoàn toàn hợp lệ — bị cost guard chặn với 402.
>
> **Tình huống cost guard cho qua nhưng rate limit chặn:**
> Người dùng mới tháng, chưa tiêu đồng nào (spent = $0, budget = $10). Họ viết script tự động gửi 50 request trong 10 giây — cost guard thấy ngân sách còn nhiều, cho qua hết. Nhưng rate limiter đếm được 10 request đã qua trong 60 giây, chặn các request tiếp theo với 429.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Chuỗi sự kiện nếu gộp `/health` và `/ready` làm một, cùng kiểm tra Redis:
>
> 1. **Giây 0**: Redis mất kết nối đột ngột (ví dụ: Redis pod restart, mạng gián đoạn).
> 2. **Giây 5-10**: Orchestrator (K8s/Railway/Render) gọi health check → cả 3 container đều trả 503 vì Redis không ping được.
> 3. **Giây 10-15**: Orchestrator đánh dấu cả 3 container là "unhealthy" → bắt đầu restart từng container.
> 4. **Giây 15-30**: Trong khi đang restart, không có container nào serving traffic → **toàn bộ service sập hoàn toàn** cho người dùng.
> 5. **Giây 30**: Redis kết nối lại. Nhưng các container đang ở giữa chu kỳ restart — phải chờ thêm thời gian khởi động.
> 6. **Kết quả**: Sự cố Redis 30 giây trở thành sự cố toàn service 60-90 giây.
>
> Nếu tách đúng: `/health` chỉ kiểm tra process → container không bị restart → vẫn đứng yên nhận request buffered. `/ready` trả 503 → load balancer tạm ngừng đẩy traffic mới vào → khi Redis hồi phục, `/ready` trả 200, traffic vào lại bình thường. Người dùng chỉ thấy vài request bị chậm, không có downtime.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Với lịch sử lưu trong **Redis** (stateless — đúng cách hiện tại):
> Dù request 1 vào container A, request 2 vào container B, request 3 vào container C — tất cả đều đọc và ghi vào cùng một key Redis `history:sv-test`. Kết quả: `history_length` tăng đều đặn: 0 → 2 → 4 → 6 → ...
>
> Nếu lưu trong **dict Python** (stateful trong process):
> Mỗi container có một dict `{}` riêng trong RAM. Load balancer phân phối request luân phiên:
> - Request 1 → Container A: `{sv-test: [{user: "câu 1"}, {assistant: "..."}]}` → `history_length = 0`
> - Request 2 → Container B: dict trống → `history_length = 0` (B không biết container A đã lưu gì)
> - Request 3 → Container C: dict trống → `history_length = 0`
> - Request 4 → Container A: `history_length = 2` (chỉ nhớ câu 1)
>
> Con số `history_length` sẽ nhảy loạn: 0, 0, 0, 2, 0, 0, 4, 0, 0... Agent "mất trí nhớ" ngẫu nhiên, không thể dùng cho hội thoại thật.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> **Lỗi gặp phải**: Khi deploy lên Render lần đầu bằng Blueprint từ `render.yaml`, Render báo lỗi: `Service type 'redis' is not valid. Valid types are: web, worker, cron, keyvalue`.
>
> **Nguyên nhân**: File `render.yaml` ban đầu trong bài lab dùng `type: redis` — đây là tên cũ của loại service Redis trên Render. Render đã đổi tên thành `type: keyvalue` trong API mới hơn. Tôi tìm ra bằng cách đọc thông báo lỗi trên Render dashboard và tra tài liệu Render Blueprints.
>
> **Cách sửa**: Đổi tất cả `type: redis` thành `type: keyvalue` trong `render.yaml`:
> ```yaml
> - type: keyvalue       # sửa từ "redis"
>   name: day12-redis
>   plan: free
>   ipAllowList: []
> ```
> Và phần `fromService` tương ứng:
> ```yaml
> fromService:
>   name: day12-redis
>   type: keyvalue       # sửa từ "redis"
>   property: connectionString
> ```
> Sau khi sửa và push lên GitHub, Blueprint trên Render nhận diện đúng và tạo thành công cả Web Service lẫn Key-Value (Redis) service.
