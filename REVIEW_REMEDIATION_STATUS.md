# Trạng thái review và remediation

Tài liệu này ghi lại các quyết định đã xử lý trong working tree và phần còn phải xác minh trên tenant. Không dùng các ghi chú cũ về submitSync, Sync Inbox hoặc SAP Production Confirmation để suy ra kiến trúc hiện hành.

## Đã remediation

| Vấn đề | Cách xử lý hiện tại |
| --- | --- |
| Mobile gửi actor tùy ý | Actor được derive từ access token/session đã validate |
| Token plain text trong persistence | Chỉ lưu token hash; refresh token được rotate |
| Bỏ qua device binding | validate_hash bắt buộc DeviceID khớp session |
| Client tin permission cache | protected action kiểm tra function/work scope lại server-side |
| CRUD trực tiếp balance/ledger | Mobile projection chỉ expose static command/status/history |
| Sửa/xóa ledger khi reverse | reverse append transaction mới, original immutable |
| Fiori sửa confirm bằng update thô | correctConfirm append signed CORRECTION có reason |
| Đọc receipt ngay sau EML bằng Open SQL | Facade đọc child ledger qua EML transactional buffer |
| Timeout bị coi là FAILED | getSyncStatus trả SUCCESS hoặc NOT_FOUND, mobile giữ pending |
| Worker password verify lệch thuật toán | KDF/verify tập trung trong ZCL_MOB_TOKEN_VALIDATOR |
| Role/Work hard-delete | handler chặn delete, dùng trạng thái A/I |

## Rủi ro còn mở

1. Race khi hai request cùng first-create ZTB_PP_OP_ALLOC; cần unique business key ở target.
2. Race duplicate SyncItemUUID cần stress-test trong runtime thật.
3. Lock conflict/retry semantics cần thống nhất với mobile.
4. Password error message hiện nói 12 ký tự/hoa/thường/số nhưng predicate chỉ kiểm tra >= 6 và không chứa username.
5. Pepper/token secret trong Z-table cần secure-store/rotation review.
6. Released API/field của SAP CDS cần verify trên release đích.
7. DCL/IAM/communication role phải test phân tách mobile và admin.

## Kết quả chất lượng source

Repository có workflow ABAP Cloud lint với @abaplint/cli 2.120.35; kết quả gần nhất được ghi nhận là 0 issue / 241 files analyzed. Đây không thay thế ADT activation, ATC hoặc kiểm thử tích hợp.
