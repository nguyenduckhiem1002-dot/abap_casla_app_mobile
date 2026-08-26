# Rà soát bảo mật và hiệu năng ABAP RAP

Ngày rà soát: 20/08/2026
Phạm vi: toàn bộ `serialized/` của backend xác thực di động, RBAC và phân bổ
sản lượng.

## Kết quả

- Không phát hiện secret hoặc mật khẩu hard-code trong source.
- Không còn đường OData đọc thô tài khoản, credential, session, ledger hoặc
  header công đoạn. Các static action vẫn hoạt động sau lớp xác thực token.
- `abaplint` ABAP Cloud: **0 lỗi trên 164 file**.
- Các lỗi có thể sửa an toàn trong source đã được xử lý. Các việc phụ thuộc
  tenant được liệt kê riêng ở cuối tài liệu.

## Bản vá bảo mật đã áp dụng

### Xác thực và vòng đời phiên

- Refresh token có hạn tuyệt đối 30 ngày tính từ lúc login; refresh không còn
  kéo dài `RefreshExpiresAt` thêm 30 ngày sau mỗi lần gọi.
- Refresh kiểm tra lại trạng thái tài khoản và trạng thái bắt buộc đổi mật khẩu.
- Đổi mật khẩu thu hồi toàn bộ session, kể cả session vừa dùng để đổi mật khẩu.
- Mỗi tài khoản tối đa 5 session active; login lại cùng thiết bị thu hồi session
  cũ của thiết bị đó.
- Login dùng cùng response thất bại và chạy dummy password hash cho username
  không tồn tại, tài khoản inactive/locked và credential không hợp lệ, giảm
  user-enumeration và timing side-channel.
- Password policy: tối thiểu 12 ký tự, có chữ hoa, chữ thường, chữ số, không
  chứa username và không được trùng mật khẩu hiện tại.
- Chặn iteration KDF ngoài khoảng 10.000–100.000 và salt rỗng để tránh bypass
  hoặc CPU denial-of-service do dữ liệu credential hỏng.
- Lỗi crypto/config nội bộ không còn trả exception text ra OData response.

### Phân quyền và cô lập dữ liệu

- `WorkerID` của tài khoản là immutable sau khi tạo, tránh đổi chủ sở hữu của
  toàn bộ lịch sử đã ghi.
- Khi tạo tài khoản có WorkerID, backend xác nhận nhân công còn hiệu lực trong
  đúng nhà máy và từ chối WorkerID đã gắn với tài khoản khác.
- Xóa cứng Role và Function bị tắt; Role phải được vô hiệu hóa bằng `Status`.
  Điều này bảo toàn assignment và dấu vết phân quyền.
- `ZR_PP_OpAlloc` và `ZC_PP_OpAlloc` dùng DCL deny-all/inherited deny-all.
  Communication user không thể GET dữ liệu header toàn nhà máy; app chỉ dùng
  static action có kiểm tra access token và function server-side.
- Các lỗi xác thực nhân công dùng chung `WORKER_AUTH_FAILED`, không tiết lộ mã
  nhân công có tồn tại, inactive hay chưa có credential.

## Tối ưu hiệu năng đã áp dụng

- Login đọc user + credential bằng một `INNER JOIN`, giảm một DB round-trip.
- Validate access token đọc session + user trong một truy vấn thay vì hai.
- Kiểm tra một function RBAC dùng truy vấn `UP TO 1 ROWS`; không còn dựng toàn
  bộ danh sách permission cho mọi request nghiệp vụ.
- Permission result, worker reference và master history dùng sorted table với
  key phù hợp cho lookup, tránh linear scan lặp lại trong batch.
- Login dọn session theo một mass EML update, không update từng dòng.

## Việc bắt buộc trên tenant

1. Tạo các secondary index sau rồi kiểm tra execution plan/ST05 trên dữ liệu
   gần production:
   - `ZTB_MOB_USER`: unique `CLIENT + NORMALIZED_USERNAME`.
   - `ZTB_MOB_SESSION`: unique `CLIENT + ACCESS_TOKEN_HASH`.
   - `ZTB_MOB_SESSION`: unique `CLIENT + REFRESH_TOKEN_HASH`.
   - `ZTB_MOB_SESSION`: `CLIENT + USER_UUID + STATUS + LOGIN_AT`.
   - Các index idempotency và ledger trong `IMPLEMENTATION_STATUS.md`.
2. Activate DCL mới và smoke-test: GET `OperationAllocations` phải không trả
   row; `getWorkHistory` vẫn chạy sau khi token/function hợp lệ.
3. Cấu hình HTTPS bắt buộc; tắt/redact request-body logging vì access token và
   password đang nằm trong action parameter.
4. Đặt rate limit ở Web Dispatcher/API layer cho login, refresh và action PP.
   Lockout trong application không thay thế rate limit theo IP/device.
5. Ghi failed login, refresh replay, revoke, đổi mật khẩu và lỗi permission vào
   Application Log; hiện source chưa có security audit trail đầy đủ.
6. Fiori tạo tài khoản phải dùng password input được che ký tự; action metadata
   RAP không được coi là bảo đảm field password luôn được mask trên mọi client.
7. Tạo APJ dọn session revoked/expired theo retention đã thống nhất.

## Rủi ro còn lại cần quyết định kiến trúc

### Mức cao

- `PASSWORD_PEPPER` và `TOKEN_SECRET` hiện nằm trong `ZTB_MOB_CONFIG`. Bảng
  không được expose nhưng vẫn là plaintext at rest. Cần chuyển sang secure
  store/released API của đúng release tenant và lập quy trình rotation.
- KDF hiện là SHA-256 lặp 10.000 vòng có pepper, không phải password KDF chuẩn.
  Cần benchmark và migrate có version sang PBKDF2/bcrypt/Argon2 nếu tenant có
  released API phù hợp. Không đổi trực tiếp nếu chưa có migration credential.

### Mức trung bình

- Hai request refresh đồng thời có thể cùng đọc refresh token cũ trước khi một
  request rotate nó. Cần PoC khóa/ETag hoặc compare-and-swap trong unmanaged
  save để refresh token thực sự single-use dưới concurrency.
- Check username/WorkerID trước create vẫn có race. Unique index username là
  lớp bảo vệ bắt buộc; WorkerID cần index thường và quy tắc xử lý duplicate
  phù hợp vì tài khoản quản lý có thể không có WorkerID.
- Failed-login counter là read-then-update; cần stress-test song song. Nếu tenant
  cho thấy lost update, chuyển sang update có khóa/atomic counter.

## Kiểm thử nghiệm thu tối thiểu

- Username sai, password sai, user inactive/locked và credential inactive trả
  cùng public response và thời gian không chênh lệch đáng kể.
- Login lần thứ 6 chỉ còn tối đa 5 session active; login lại cùng DeviceID làm
  token cũ hết hiệu lực.
- Sau đổi mật khẩu, mọi access/refresh token cũ đều bị từ chối.
- Refresh nhiều lần không thay đổi `RefreshExpiresAt` ban đầu.
- Role inactive mất quyền ngay ở request kế tiếp dù token còn hạn.
- GET các entity nhạy cảm không trả dữ liệu; static action hợp lệ vẫn chạy.
- Chạy test đồng thời cho create username trùng, failed login và refresh replay.
