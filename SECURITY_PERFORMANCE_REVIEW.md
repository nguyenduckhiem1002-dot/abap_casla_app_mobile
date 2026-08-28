# Rà soát bảo mật và hiệu năng

Ngày đối chiếu: **28/08/2026**. Phạm vi: authentication/session, RBAC, Work Context, production allocation, ledger, history và Fiori admin services.

## Kết luận ngắn

Các lớp bảo vệ quan trọng đã có trong source: token/session/device guard, server-side actor derivation, worker password verification, command-only mobile facade, immutable ledger và controlled correction. Điểm chưa thể đóng bằng source-only là uniqueness/concurrency của first snapshot, target-specific index, IAM/tenant activation và secret storage.

## Bảo mật

### Identity/session

- Username được normalize để lookup.
- Access/refresh token chỉ lưu dưới dạng digest; plain token chỉ trả trong login/refresh response.
- Session gắn DeviceID, có access expiry 30 phút và refresh expiry 30 ngày.
- Login giới hạn 5 active sessions/account; cùng device hoặc session vượt giới hạn bị revoke.
- 5 password failure trong 1 phút lock 10 phút.
- Đổi mật khẩu revoke session active.

### Password

KDF hiện tại là custom iterative SHA-256 dùng PASSWORD_PEPPER, salt và số vòng lưu cùng credential; mặc định 10.000 vòng, miền hợp lệ 10.000..100.000. Digest so sánh constant-time.

> **Ghi chú chính xác:** enforcement hiện tại là dài tối thiểu 6 ký tự và không chứa username. Text lỗi trong create user mô tả policy mạnh hơn nhưng không thực thi đủ. Đây là remediation về policy/message/test, không nên che bằng tài liệu.

### Authorization boundary

- Mobile projection không expose raw EmployeeAllocation, AllocationTransaction, credential hoặc session CRUD.
- Mọi mobile production action validate token/session/device và Work Context.
- Actor, verified worker, session và device được ghi vào ledger từ context server-side.
- Fiori admin dùng IAM/business catalog riêng; không đưa admin binding vào mobile communication scenario.
- Role/Work/Function/master hard-delete bị chặn để giữ lineage và mapping.

## Tính nhất quán nghiệp vụ

Balance phải giữ:

    Remaining = InitialAssigned + TransferredIn
                - TransferredOut - Recalled - Completed

Một command thành công phải cập nhật balance và append POSTED ledger trong cùng managed RAP LUW. Reverse/correction không update/delete transaction gốc.

## Timeout và replay

SyncItemUUID là client-generated idempotency identity. Cùng key + cùng payload là replay hợp lệ; cùng key + payload khác bị IDEMPOTENCY_KEY_REUSED; nhiều receipt bị SYNC_RECEIPT_DUPLICATE và fail-closed.

HTTP timeout chỉ tạo trạng thái UNKNOWN/PENDING_CONFIRMATION ở mobile. getSyncStatus lọc theo SyncItemUUID + ActorUserUUID + POSTED; SUCCESS chứng minh receipt, NOT_FOUND chỉ có nghĩa chưa chứng minh commit.

## Hiệu năng và concurrency

Các lookup nóng: normalized username, token hash, active session, operation business key, operation/worker balance, sync key, original lineage và actor/date history.

### Bắt buộc verify/enforce

- unique CLIENT + NORMALIZED_USERNAME;
- unique access/refresh token hash theo semantics session;
- unique CLIENT + PRODUCTION_ORDER + OPERATION_NO;
- index operation + worker cho balance nếu execution plan yêu cầu;
- index sync key và lineage/history theo volume thật.

Không áp unique index mù trên SyncItemUUID trước khi thống nhất rằng mọi source channel đều dùng field này. Fiori CORRECTION có thể không có mobile sync identity.

### Race còn lại

lock master bảo vệ operation instance đã tồn tại. Nó không tự bảo vệ hai request cùng tạo snapshot khi business key chưa có row. Cần DDIC/database uniqueness và stress test first-create. Duplicate request và concurrent refresh/failed-login counter cũng phải test trên tenant.

## Kiểm thử bảo mật/tải tối thiểu

- device mismatch, expired/revoked token, password-change-required;
- inactive Role/Work mất hiệu lực ngay request sau;
- worker mapping không unique/inactive/password sai;
- concurrent first-create snapshot;
- concurrent duplicate SyncItemUUID;
- concurrent transfer/confirm cùng balance;
- response loss sau commit và reconcile;
- Fiori correction/reverse lineage;
- mobile communication role không gọi được admin service;
- request-body redaction và rate limit tại lớp gateway.
