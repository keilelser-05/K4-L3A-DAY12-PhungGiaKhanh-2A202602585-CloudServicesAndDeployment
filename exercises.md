# Phiếu Phản Ánh — K4 Level 3A, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay mỗi dòng placeholder dưới từng câu bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Phung Gia Khanh  Mã học viên: 2A202602585

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Tôi deploy image lên Render nhưng quên set `AGENT_API_KEY` trong dashboard. Nhờ fail fast, container crash ngay lúc start với `ValidationError` và log build/runtime chỉ rõ thiếu biến, tôi sửa trong 1 phút. Nếu để mặc định `"changeme"`, app vẫn lên, `/health` vẫn 200, tôi tưởng deploy thành công; kẻ khác đoán được key mặc định và gọi `/ask` miễn phí bằng tiền của tôi cho đến khi tôi đọc hóa đơn mới biết.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Dòng log thật thu được khi gọi `log_event`:

```
{"event": "ask_completed", "level": "info", "timestamp": "2026-09-28T09:57:40.734273+00:00", "user_id": "sv01", "tokens_in": 12, "tokens_out": 40, "cost_usd": 2.58e-05}
```

Hai việc `print("đã trả lời xong")` không làm được: (1) nhóm theo `user_id` và cộng `cost_usd` để ra bảng user tiêu nhiều tiền nhất hôm nay; (2) lọc theo `event` + `level` và đếm theo khung giờ để tính tỷ lệ lỗi 5 phút qua và gắn cảnh báo tự động. Log thường chỉ đọc được bằng mắt, log JSON một dòng thì máy parse, lọc và vẽ biểu đồ được.

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
| 1 stage (bản đầu) | không đo trong buổi này (ước lượng ~800MB–1GB vì base `python:3.11` đầy đủ) |
| Multi-stage | 220MB (`day12-agent:prod`, đo bằng `docker images`) |

Giải thích: phần chênh lệch là compiler/toolchain và cache pip ở stage `builder` bị vứt đi (không copy sang stage runtime), cộng với base `python:3.11-slim` nhẹ hơn base `python:3.11` đầy đủ, và image prod chỉ cài runtime deps (`fastapi uvicorn pydantic redis...`) thay vì cả `pytest/fakeredis`.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

Quan sát khi chạy `docker compose up -d --build agent` sau khi chỉ sửa code: các layer `FROM`, `WORKDIR`, `COPY requirements.txt`, `RUN pip install` hiện `CACHED`, chỉ các layer `COPY app`, `COPY utils` trở đi chạy lại. Vì `COPY requirements.txt` đứng trước `pip install` và code copy sau, sửa code không làm mất cache thư viện. Nếu đặt `COPY . .` lên trước `RUN pip install`, mọi lần sửa một ký tự trong code đều đổi layer copy, kéo theo `pip install` chạy lại toàn bộ từ đầu, build chậm đi vài phút mỗi lần.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

Chuỗi sự kiện: lỗ hổng trong code (ví dụ injection cho phép thực thi lệnh) cho kẻ tấn công shell bên trong container → process đang là uid 0 nên shell đó là root trong container → kẻ tấn công mount hoặc khai thác breakout (ví dụ ghi vào socket Docker, volume host, hoặc leo đặc quyền kernel) để chạm tới host với quyền root. Lệnh `USER appuser` cắt ở mắt xích đầu: shell chiếm được chỉ là user thường uid 10001, không đọc/ghi được file root, không mount device, phạm vi phá hoại bị nhốt trong quyền của app.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

Tối đa 20 request trong 2 giây. Cách làm: gửi 10 request vào giây cuối cùng của phút này (ví dụ 10:00:59) cho đầy quota phút đó, rồi ngay khi đồng hồ sang phút mới (10:01:00–10:01:01) quota reset và gửi tiếp 10 request nữa. Hai cụm cách nhau ~2 giây nhưng thuộc hai khung đếm khác nhau nên đều hợp lệ. Sliding window 60 giây trượt thì không có kẽ hở này vì nó luôn nhìn lại đúng 60 giây gần nhất.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

Rate limit giới hạn số lượng request trên một cửa sổ thời gian (chống spam/burst), cost guard giới hạn tổng số tiền đã tiêu trong tháng (chống cháy ngân sách). Tình huống 1: user chỉ gọi 5 request/phút (dưới hạn 10) nhưng mỗi request kèm prompt hàng chục nghìn token, tổng chi phí vượt 10 USD/tháng — rate limit cho qua, cost guard trả 402. Tình huống 2: attacker dùng key hợp lệ bắn 50 request rẻ tiền trong 1 phút, tổng mới vài cent — cost guard chưa chạm ngưỡng nhưng rate limit chặn ở request thứ 11 bằng 429.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Thứ tự sự kiện: (1) Redis mất kết nối 30 giây; (2) cả 3 container gọi endpoint gộp đều fail vì bước kiểm tra Redis fail, cùng trả unhealthy/503; (3) orchestrator hiểu nhầm là cả 3 process hỏng nên restart đồng loạt cả cụm; (4) trong lúc restart không còn container nào phục vụ, request đang chạy rớt hết; (5) khi Redis quay lại thì cụm đang khởi động lại từ đầu thay vì chỉ đứng yên chờ. Tách riêng thì `/health` vẫn 200 (process sống, không restart), chỉ `/ready` 503 để load balancer tạm ngừng đẩy traffic.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

Với Redis, `history_length` tăng đều 0, 2, 4... vì mọi container cùng đọc một list chung. Với dict trong RAM, mỗi container có một dict riêng: request 1 vào container A thấy 0, request 2 rơi vào container B cũng thấy 0 (vì B chưa từng thấy câu trước), request 3 quay lại A thì thấy 2. Con số nhảy loạn, tăng không đều, có lúc tụt về 0 — agent lúc nhớ lúc quên tùy container nào nhận request, đúng kiểu mất trí nhớ ngẫu nhiên sau load balancer.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

Lỗi gặp khi build image: `pip._vendor.urllib3.exceptions.ReadTimeoutError: HTTPSConnectionPool(host='files.pythonhosted.org', port=443): Read timed out` ở bước `RUN pip install -r requirements.txt`, fail ở gói `uvloop` (~3.8MB) vì mạng chậm (tốc độ tải chỉ vài chục KB/s). Tôi biết nguyên nhân nhờ đọc log `docker build`, thấy tốc độ tải kẹt ở một wheel lớn rồi timeout sau hàng trăm giây. Cách sửa: thêm `--timeout=100 --retries=10` cho pip và chuyển image prod sang chỉ cài runtime deps (`fastapi uvicorn pydantic pydantic-settings redis python-dotenv`, bỏ `pytest/fakeredis` và extras nặng), build lại thành công còn 220MB. Bài học thêm cùng buổi: container crash lúc start vì `lifespan` gọi `lifecycle.install()` chưa cài (`NotImplementedError`), đọc `docker compose logs agent` là thấy ngay.
