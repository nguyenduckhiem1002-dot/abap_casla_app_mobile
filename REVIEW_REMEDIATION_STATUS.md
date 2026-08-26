# Trạng thái xử lý code review

> Tài liệu này mô tả **trạng thái cuối hiện tại** của branch triển khai. Các ghi chú hardening cũ về `submitSync`, Sync Inbox, bgPF/SAP background worker và standard SAP Production Confirmation adapter đã được loại khỏi working tree vì kiến trúc đó đã bị thay thế. Lịch sử chi tiết vẫn còn nguyên trong Git history.

## Kiến trúc đã chốt

CASLA Mobile ghi nhận nghiệp vụ trực tiếp vào các Z-table trên SAP thông qua RAP/OData V4 custom API của project.

```text
Mobile background queue
        |
        v
ZUI_MOB_AUTH / ZUI_PP_OPALLOC
        |
        +-- validate CASLA token + session + device
        +-- validate RBAC + Work Context server-side
        +-- resolve Production Order / Operation từ released SAP CDS
        +-- validate worker + worker password + UoM + quantity
        +-- execute domain command trong managed RAP LUW
        |
        +--> ZTB_PP_EMP_ALLOC     (current balance)
        +--> ZTB_PP_ALLOC_TXN     (immutable ledger)
```

Không có:

- standard SAP Production Confirmation posting;
- SAP Application Job/bgPF để xử lý command mobile;
- Sync Inbox `ZTB_PP_SYNC_H` / `ZTB_PP_SYNC_I`;
- raw CRUD từ mobile vào allocation/ledger table.

## Mobile command surface

`ZUI_PP_OPALLOC` chỉ expose command/status/history contract an toàn:

- `submitInitialAssign`
- `submitTransfer`
- `submitRecall`
- `submitConfirm`
- `submitReverse`
- `getSyncStatus`
- `getWorkHistory`

Mỗi mutation dùng `SyncItemUUID` ổn định do mobile sinh **trước khi gửi request**.

### Timeout/reconciliation

HTTP timeout hoặc mất response không phải business failure.

Mobile giữ item ở `UNKNOWN` / `PENDING_CONFIRMATION`, sau đó gọi `getSyncStatus` bằng cùng `SyncItemUUID`:

- `SUCCESS`: backend chứng minh được một POSTED ledger receipt của actor hiện tại;
- `NOT_FOUND`: backend chưa chứng minh được commit, không được coi là `FAILED`;
- duplicate receipt: backend fail-closed thay vì chọn tùy ý một row.

Nếu phải resend mutation, mobile gửi lại đúng command và đúng idempotency identity.

## RAP transaction semantics đã harden

- `ZR_PP_OpAlloc` là managed RAP BO, root `OperationAllocation` là `lock master`; child balance/ledger lock dependent theo root.
- Internal domain actions dùng `MODIFY ENTITIES ... IN LOCAL MODE` trong chính behavior pool.
- Balance update và ledger append nằm trong cùng RAP LUW.
- Facade action không dùng Open SQL để đọc ledger vừa tạo trước save. Nó dùng `READ ENTITIES ... BY \_Transactions IN LOCAL MODE`, vì receipt mới tồn tại trong RAP transactional buffer tại thời điểm đó.
- `confirm` khi có `OriginalTransactionUUID` cũng đọc transaction gốc bằng EML trong transactional buffer và fail-closed nếu key không hợp lệ, sai operation hoặc không POSTED.

## Domain behavior đã hoàn thiện

### Initial Assign

- token/session/device validation;
- Work Context validation;
- worker active + worker password verification;
- UoM/quantity validation;
- update/create employee allocation balance;
- append `INITIAL_ASSIGN` ledger row.

### Transfer

- source/target worker validation;
- source remaining quantity validation;
- decrement source + increment/create target balance;
- append `TRANSFER` ledger row.

### Recall

- only valid lineage from `INITIAL_ASSIGN` / `TRANSFER`;
- validate remaining balance;
- append `RECALL`; original transaction stays immutable.

### Confirm

- validate worker, password, Work Context, UoM and remaining quantity;
- `Completed += Quantity`;
- `Remaining -= Quantity`;
- append `CONFIRM` ledger row.

### Reverse

- only reverses an existing POSTED `CONFIRM`;
- rejects already-reversed transaction;
- includes signed corrections in effective quantity;
- restores Completed/Remaining;
- appends `REVERSE` linked by `OriginalTransactionUUID`.

### Controlled Fiori correction

`ZUI_PP_ALLOC_ADM` provides IAM-protected `correctConfirm`:

- generic ledger update/delete is not exposed;
- original `CONFIRM` is never edited;
- balance is adjusted by signed delta;
- new immutable `CORRECTION` row records reason and lineage.

## SAP live operation validation

`ZCL_PP_OPERATION_GUARD` resolves the operation from SAP VDM rather than trusting mobile payload:

- `I_ManufacturingOrderStatus` for active system statuses;
- `I_ManufacturingOrderOperation` for operation snapshot fields;
- `I_WorkCenter` for semantic work-center ID.

Current business rules include REL required, terminal/deletion statuses blocked, operation control profile `YBP1`, required standard text code, positive planned quantity and valid Plant/Work Center/UoM.

Release/field availability must still be activated and verified on the target Public Cloud tenant; repository lint cannot replace ADT activation/ATC.

## RBAC / Work Context / auth

- Login lockout, token validation and worker-password verification remain server-side.
- `ActorUserUUID` is always derived from the authenticated token/session, not accepted from mobile input.
- Mobile login/refresh returns effective permissions/work contexts for UX, but backend re-checks grants for protected operations.
- Worker verification audit persists UUID/time/method without storing plaintext password.
- User Role / Role Function / Role Work assignments remain composition-based admin data.

## Fiori administration surfaces

1. `ZUI_MOB_USER_ADM` — User Administration.
2. `ZUI_MOB_RBAC_ADM` — Role / Function / Work Administration.
3. `ZUI_MD_CONGDOAN_ADM` — versioned Công đoạn master.
4. `ZUI_PP_ALLOC_ADM` — allocation audit + controlled confirm correction.

Tenant-specific Launchpad targets, catalogs, semantic objects and runtime URLs are intentionally not fabricated in this repository.

## Concurrency checks còn bắt buộc trên tenant

Managed RAP locking protects modification of an existing operation BO instance. Tuy nhiên lần đầu `ensure_operation` phải CREATE snapshot, và RAP locking không thể dùng một active-instance key chưa tồn tại để bảo đảm uniqueness business key.

Trước production phải:

1. enforce/verify uniqueness của `CLIENT + PRODUCTION_ORDER + OPERATION_NO` cho `ZTB_PP_OP_ALLOC` ở target DDIC/database;
2. stress-test hai request đầu tiên đồng thời cho cùng Order/Operation;
3. stress-test duplicate `SyncItemUUID` đồng thời trên cùng operation;
4. xác nhận lock conflict được mobile coi là transient/retryable, không phải permanent business failure.

Không tạo một unique index mù trên `SYNC_ITEM_UUID` khi chưa xử lý semantics của các ledger row Fiori/CORRECTION có thể không dùng mobile sync identity.

## Quality gate hiện tại

- `@abaplint/cli 2.120.35`
- ABAP language version: Cloud
- `parser_error`, syntax, DDIC, host-variable escaping, `SELECT SINGLE` full-key, method length và cyclomatic complexity đều bật.
- Latest source gate: **0 issue / 241 files analyzed**.

## Còn phải verify trên SAP tenant

- abapGit import + ADT activation toàn dependency chain;
- ATC/ABAP Cloud checks trên đúng release;
- released status/field của SAP CDS dùng trong `ZCL_PP_OPERATION_GUARD`;
- OData V4 service binding publish;
- IAM/business catalogs cho admin services;
- concurrency/index checks nêu trên;
- end-to-end smoke test mobile timeout -> `getSyncStatus` -> safe retry cùng `SyncItemUUID`.

Xem thêm:

- `README.md`
- `IMPLEMENTATION_STATUS.md`
- `docs/ABAP_RAP_MOBILE_SYNC_PLAN.md`
- `docs/FIORI_ELEMENTS_ADMIN.md`
- `docs/CASLA_DATA_MODEL.drawio`
