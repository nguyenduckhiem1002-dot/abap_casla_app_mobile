# Trạng thái implementation

Ngày đối chiếu: **28/08/2026**. File này là bảng trạng thái ngắn; đặc tả đầy đủ nằm trong [README.md](README.md).

## Đã có trong source

| Nhóm | Object/logic | Trạng thái |
| --- | --- | --- |
| Account | create user, login, logout, refresh, change password | Đã có |
| Session | access/refresh hash, rotation, device binding, revoke | Đã có |
| Lockout | 5 lỗi/1 phút -> lock 10 phút | Đã có |
| Password | KDF SHA-256 lặp, pepper từ config, salt riêng | Đã có; policy predicate hiện chỉ >= 6 và không chứa username |
| RBAC | User/Role/Function/Work + mapping | Đã có |
| Work scope | kiểm tra exact Plant + WorkCenter server-side | Đã có |
| Live guard | SAP status/order operation/work center | Đã có trong ZCL_PP_OPERATION_GUARD |
| Allocation | initial assign, transfer, recall, confirm | Đã có |
| Reversal | compensating REVERSE cho CONFIRM | Đã có |
| Correction | Fiori/IAM correctConfirm -> signed CORRECTION | Đã có |
| Ledger | ZTB_PP_ALLOC_TXN, trạng thái POSTED, lineage | Đã có |
| Reconciliation | getSyncStatus theo actor + SyncItemUUID | Đã có |
| History | self/team scope, D/W/M/custom, summary/entries | Đã có |
| Master | versioned Công đoạn + non-overlap validation | Đã có |
| Fiori services | User, RBAC, master, correction/audit | Đã có metadata/binding serialize |

## Kiến trúc đã loại khỏi flow hiện hành

- ZTB_PP_SYNC_H / ZTB_PP_SYNC_I;
- abstract submitSync batch contract;
- SAP-side mobile queue/background worker;
- standard SAP Production Confirmation adapter;
- constraint theo thời gian còn lại của ca làm việc.

## Chưa thể kết luận chỉ từ repository

- activation thành công trên đúng Public Cloud release;
- released status/field của I_ManufacturingOrderStatus, I_ManufacturingOrderOperation, I_WorkCenter;
- ATC/ABAP Cloud result trên tenant;
- IAM catalog, communication arrangement, binding publish và Launchpad mapping;
- unique constraint/index và concurrency behavior khi first-create;
- benchmark KDF, cleanup session, rate limiting, log redaction;
- end-to-end mobile timeout/retry trên hệ thống thật.

## Việc tiếp theo trước production

1. Import/activate theo dependency order trong README.
2. Verify CDS release/fields bằng ADT/View Browser.
3. Chạy ATC và test metadata/action của toàn bộ OData V4 binding.
4. Enforce/test unique business key cho operation snapshot.
5. Chạy test matrix về lock, duplicate key, response loss và immutable lineage.
6. Chốt policy mật khẩu; sửa code/message/test nếu yêu cầu 12 ký tự và complexity là bắt buộc.
