# Mobile command và reconciliation

Đây là thiết kế **hiện hành** cho đồng bộ nghiệp vụ giữa CASLA Mobile và backend ABAP RAP. “Sync” ở đây nghĩa là mobile đồng bộ command với custom Z-table trên SAP; không phải posting standard SAP Production Confirmation.

## 1. Quyết định kiến trúc

    Mobile local queue
       -> direct command + stable SyncItemUUID
       -> ZUI_PP_OPALLOC
       -> token/session/device guard
       -> RBAC + Work Context
       -> live Production Order / Operation guard
       -> managed RAP action
           -> ZTB_PP_EMP_ALLOC
           -> ZTB_PP_ALLOC_TXN (POSTED receipt)

Đã loại bỏ khỏi flow: ZTB_PP_SYNC_H/I, submitSync, SAP-side mobile queue, background worker và standard confirmation adapter. Mobile là nơi quản lý offline/pending/retry; SAP quản lý authentication, authorization, validation, atomic mutation và audit evidence.

## 2. Command contract

Static mobile actions:

- submitInitialAssign
- submitTransfer
- submitRecall
- submitConfirm
- submitReverse
- getSyncStatus
- getWorkHistory

Common fields: AccessToken, DeviceID, ProductionOrder, Operation, SyncItemUUID và dữ liệu theo command. Backend resolve OperationUUID, Plant, Work Center, UoM, planned quantity và MaCongDoan; mobile không được gửi actor để backend tin trực tiếp.

## 3. State machine phía mobile

    PENDING_LOCAL -> SENDING
                        ├─ SUCCESS -> SYNCED
                        ├─ deterministic validation -> BUSINESS_FAILED
                        └─ timeout/network ambiguity -> PENDING_CONFIRMATION

    PENDING_CONFIRMATION -> getSyncStatus
                        ├─ SUCCESS -> SYNCED
                        ├─ NOT_FOUND -> giữ pending hoặc retry cùng command/key
                        └─ auth failure -> refresh/re-login flow

Không tạo FAILED chỉ vì network exception. Nếu retry, giữ nguyên SyncItemUUID và logical payload.

## 4. Idempotency

Backend đọc ledger theo SyncItemUUID:

| Receipt | Kết quả |
| --- | --- |
| 0 | thực thi command |
| 1, payload khớp | idempotent success |
| 1, payload khác | IDEMPOTENCY_KEY_REUSED |
| >1 | SYNC_RECEIPT_DUPLICATE, fail-closed |

Các action bound kiểm tra payload của receipt tương ứng. getSyncStatus lọc thêm actor hiện tại và POSTED, vì cùng sync key của actor khác không được làm lộ receipt.

## 5. Atomicity và transactional buffer

Balance update và ledger append cùng managed RAP LUW:

    commit  -> cả balance và receipt tồn tại
    rollback -> không có thay đổi nghiệp vụ

Sau khi facade gọi domain action IN LOCAL MODE, receipt có thể chưa ở database. Vì vậy code đọc bằng EML READ ENTITIES ... BY _Transactions IN LOCAL MODE, không dùng Open SQL để đọc row vừa tạo trước save sequence.

## 6. Live operation guard

ZCL_PP_OPERATION_GUARD kiểm tra:

- active system status có REL (I0002);
- không có TECO (I0045), CLSD (I0046) hoặc DLFL (I0076);
- operation có control profile không rỗng, không marked-for-deletion; khi
  `PP_OPERATION_CONTROL_PROFILE` active trong `ZTB_MOB_CONFIG` thì profile phải khớp cấu hình;
- có standard text code, planned quantity > 0, Plant, internal Work Center ID, UoM;
- I_WorkCenter resolve được code theo Plant + internal ID.

Standard text code được snapshot thành MaCongDoan. Field/release phải verify trên target tenant.

## 7. Domain mutation

- **Initial assign:** verify function PP_INITIAL_ASSIGN, scope, worker active/password; create/cộng balance và append INITIAL_ASSIGN.
- **Transfer:** verify target worker/password, source đủ Remaining; trừ source, cộng/tạo target; append TRANSFER.
- **Recall:** original lineage phải là INITIAL_ASSIGN hoặc TRANSFER, balance đủ; append RECALL.
- **Confirm:** worker active/password/UoM/balance; Completed += qty, Remaining -= qty; append CONFIRM custom.
- **Reverse:** chỉ reverse POSTED CONFIRM, tính cả CORRECTION delta trước đó, append REVERSE.
- **Correction:** Fiori/IAM dùng correctConfirm; append signed delta CORRECTION, giữ nguyên original.

## 8. Reconciliation result

| Status | Ý nghĩa |
| --- | --- |
| SUCCESS | tìm đúng một POSTED receipt của actor và SyncItemUUID |
| NOT_FOUND | chưa chứng minh commit; không phải business failure |
| SYNC_RECEIPT_DUPLICATE | data-integrity issue; fail-closed |
| token/device/permission error | request bị reject theo security boundary |
