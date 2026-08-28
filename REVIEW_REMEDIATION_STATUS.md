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
| RAP signature `changePasswordAdmin` thiếu `IMPORTING` | Handler declaration đã dùng `IMPORTING keys FOR ACTION MobileUser~changePasswordAdmin` |
| `changePasswordAdmin` đọc lại `$self` dù BDEF không khai báo result | Đã bỏ lần `READ ENTITIES` cuối và biến `updated_users` không sử dụng |
| Password message lệch predicate | Policy hiện thống nhất ở mức tối thiểu 6 ký tự và không chứa username; message create/change/admin dùng cùng rule |
| `method_length` dùng sai key | Đã đổi sang `statements: 80`; phần revoke session được tách khỏi `login` để method quay lại dưới quality gate |
| `unused_variables` exclude toàn `locals_imp` | Đã bỏ exclude rộng; các global authorization handler dùng `requested_authorizations` theo RAP request mask |
| Custom RAP checks nhúng trong workflow YAML | Đã chuyển sang `scripts/check_rap_patterns.py`; local và CI cùng chạy qua `bash scripts/check_ci.sh` |
| Không có ABAP Unit regression test | Đã thêm test class cho constant-time comparison/empty secret của `ZCL_MOB_HASHER` và guard cho empty token, KDF iteration range, empty salt của `ZCL_MOB_TOKEN_VALIDATOR` |

## Rủi ro còn mở

1. Race khi hai request cùng first-create ZTB_PP_OP_ALLOC; cần unique business key ở target.
2. Race duplicate SyncItemUUID cần stress-test trong runtime thật.
3. Lock conflict/retry semantics cần thống nhất với mobile.
4. Password policy hiện chọn rule tối thiểu 6 ký tự + không chứa username; nếu tenant yêu cầu policy mạnh hơn phải thay predicate, migration, message và test cùng lúc.
5. Pepper/token secret trong Z-table cần secure-store/rotation review.
6. Released API/field của SAP CDS cần verify trên release đích.
7. DCL/IAM/communication role phải test phân tách mobile và admin.
8. ABAP Unit hiện mới bao phủ các guard crypto/KDF thuần; session lifecycle, token rotation với persistence, idempotency, command invariants và balance invariant vẫn cần test seam/fixture phù hợp và chạy trên tenant đã activate.

## Kết quả chất lượng source

Quality gate dùng `@abaplint/cli` phiên bản cố định `2.120.35` cùng các RAP/CDS activation-risk checks được version hóa trong repository.

Chạy local bằng một lệnh duy nhất:

```bash
bash scripts/check_ci.sh
```

Tiêu chí merge là command trên và GitHub Action **ABAP lint** phải xanh. Không đóng đinh số lượng `issue/file analyzed` trong tài liệu vì đó là số liệu transient thay đổi theo working tree. Quality gate tĩnh này không thay thế ADT activation, ATC, việc thực thi ABAP Unit hoặc kiểm thử tích hợp trên tenant đích.
