# Rà soát bảo mật và hiệu năng ABAP RAP

Ngày rà soát cập nhật: **26/08/2026**  
Phạm vi: backend xác thực mobile, RBAC/Work Context, production allocation, immutable ledger và các Fiori admin service trong `serialized/`.

## Kết quả hiện tại

- Không phát hiện secret hoặc mật khẩu hard-code trong source.
- Mobile không có đường OData raw CRUD vào credential, session, employee allocation hoặc transaction ledger.
- Mutation production đi qua static RAP command facade có token/session/device validation server-side.
- `ActorUserUUID` được suy ra từ token/session; client không được tự khai actor.
- Worker password chỉ dùng để verify trong request, không persist plaintext vào ledger.
- `ZTB_PP_ALLOC_TXN` là append-only audit ledger; reverse/correction tạo transaction mới thay vì sửa/xóa original row.
- `abaplint` ABAP Cloud hiện tại: **0 issue trên 241 file**.

## Xác thực và vòng đời phiên

- Token hashing có một implementation dùng chung trong `ZCL_MOB_TOKEN_VALIDATOR`.
- Access token được validate cùng DeviceID và trạng thái session/user.
- Login lockout và password verification chạy ở backend; client response không được dùng làm nguồn phân quyền.
- Permission và Work Context trả cho mobile chỉ phục vụ UX; protected operation vẫn kiểm tra grant server-side ở thời điểm request.
- Đổi mật khẩu và session lifecycle giữ nguyên các hardening đã triển khai trước đó.

## Mobile production API boundary

`ZUI_PP_OPALLOC` cung cấp command/status/history contract, không expose raw balance/ledger mutation:

- `submitInitialAssign`
- `submitTransfer`
- `submitRecall`
- `submitConfirm`
- `submitReverse`
- `getSyncStatus`
- `getWorkHistory`

Kiến trúc hiện tại **không** có SAP-side background queue, bgPF worker hoặc standard SAP Production Confirmation posting.

Mobile background worker tự quản pending/retry. Mỗi mutation dùng `SyncItemUUID` ổn định được sinh trước khi gửi.

### Timeout safety

Network timeout không được map trực tiếp thành business `FAILED`.

Sau timeout, mobile gọi `getSyncStatus`:

- `SUCCESS`: backend tìm đúng một POSTED ledger receipt thuộc actor hiện tại;
- `NOT_FOUND`: backend chưa chứng minh được commit, không phải permanent failure;
- duplicate receipt: fail-closed để lộ data-integrity problem thay vì chọn tùy ý một row.

## RAP transactional consistency

`ZR_PP_OpAlloc` là managed RAP BO:

- root `OperationAllocation` là `lock master`;
- employee allocation và transaction ledger là lock-dependent child;
- balance update + ledger append nằm trong cùng RAP LUW;
- internal domain actions dùng EML `IN LOCAL MODE` trong chính behavior pool.

Một hardening quan trọng ở facade: sau khi internal action tạo transaction child, code dùng

```abap
READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
  ENTITY OperationAllocation BY \_Transactions
```

để đọc receipt từ **RAP transactional buffer**. Không dùng Open SQL để đọc một row chưa tới save sequence.

## Domain invariants

Employee balance phải luôn thỏa:

```text
Remaining = InitialAssigned
          + TransferredIn
          - TransferredOut
          - Recalled
          - Completed
```

`validateBalance` fail nếu invariant sai hoặc Remaining âm.

Các command đều kiểm tra quantity/UoM và ledger lineage trước mutation. `reverse` chỉ đảo effective quantity của một POSTED `CONFIRM`; `correctConfirm` ghi signed `CORRECTION` delta và giữ original transaction immutable.

## SAP live master-data guard

`ZCL_PP_OPERATION_GUARD` không tin production-order snapshot do mobile gửi. Nó đọc SAP VDM trực tiếp:

- `I_ManufacturingOrderStatus`;
- `I_ManufacturingOrderOperation`;
- `I_WorkCenter`.

Guard hiện kiểm tra active system status, REL, terminal/deletion status, control profile `YBP1`, standard text code, planned quantity, UoM, Plant và Work Center.

Các CDS/field này phải được verify release status trên **đúng target tenant/release** khi activate. Static lint không thay thế ADT activation hoặc ATC.

## Phân quyền và cô lập dữ liệu

- DCL deny/inherited-deny bảo vệ mobile projection khỏi query raw data.
- Static action vẫn validate end-user CASLA token vì service có thể chạy dưới communication user.
- Work Context giới hạn operation theo Plant + Work Center.
- Fiori admin services tách khỏi mobile communication surface.
- `ZUI_PP_ALLOC_ADM` chỉ cho controlled `correctConfirm`; ledger list là read-only.

## Concurrency review

### Existing operation instance

Managed RAP `lock master` cung cấp pessimistic locking cho modify/action trên một operation BO instance. Child balance/ledger mutation cùng operation đi theo lock master.

### First snapshot creation — cần tenant hardening

`ensure_operation` có thể CREATE `ZTB_PP_OP_ALLOC` khi snapshot chưa tồn tại. RAP lock của active instance không thể tự bảo đảm business-key uniqueness cho một row chưa tồn tại.

Trước production phải enforce và test uniqueness:

```text
CLIENT + PRODUCTION_ORDER + OPERATION_NO
```

Không chỉ check application bằng `SELECT ... UP TO 2 ROWS`; cần constraint/index phù hợp trên target DDIC/database để đóng race của hai first request đồng thời.

### SyncItemUUID replay

Application đã fail-closed khi thấy 0/1/>1 receipt. Với existing operation, RAP locking giúp serialize modification cùng BO instance, nhưng vẫn phải stress-test duplicate request đồng thời trên target runtime.

Không nên tạo một unique index mù trên `SYNC_ITEM_UUID` trước khi chốt semantics cho mọi source channel, vì Fiori `CORRECTION` không phải mobile command và không nhất thiết có mobile sync identity.

Nếu tenant test chứng minh còn race ngoài phạm vi root lock, chọn một cơ chế uniqueness/receipt riêng có semantics rõ ràng thay vì dựa vào `SELECT`-before-create.

## Hiệu năng

Các đường nóng hiện chủ yếu lookup theo:

- normalized username;
- access/refresh token hash;
- user/session status;
- operation business key;
- operation UUID + worker ID;
- SyncItemUUID;
- transaction lineage (`ORIGINAL_TRANSACTION_UUID`);
- actor/history date range.

Secondary indexes phải được xác nhận bằng data volume gần production và execution plan/ST05 trên tenant; không index mọi field theo cảm tính.

Các index tối thiểu cần verify/enforce:

1. `ZTB_MOB_USER`: unique `CLIENT + NORMALIZED_USERNAME`.
2. `ZTB_MOB_SESSION`: unique `CLIENT + ACCESS_TOKEN_HASH`.
3. `ZTB_MOB_SESSION`: unique `CLIENT + REFRESH_TOKEN_HASH`.
4. `ZTB_MOB_SESSION`: `CLIENT + USER_UUID + STATUS` hoặc biến thể có `LOGIN_AT` nếu đúng query thực tế.
5. `ZTB_PP_OP_ALLOC`: unique `CLIENT + PRODUCTION_ORDER + OPERATION_NO`.
6. `ZTB_PP_EMP_ALLOC`: lookup `CLIENT + OPERATION_UUID + WORKER_ID` nếu target table size/query plan yêu cầu.
7. `ZTB_PP_ALLOC_TXN`: index đọc theo `CLIENT + SYNC_ITEM_UUID` và lineage/history theo query thực tế; uniqueness phải theo semantics đã chốt, không áp mù.

## Việc bắt buộc trên target tenant

1. Import bằng abapGit và activate dependency chain trong ADT.
2. Chạy ATC/ABAP Cloud checks trên đúng release.
3. Verify released status/field của SAP CDS trong `ZCL_PP_OPERATION_GUARD` bằng View Browser/ADT.
4. Activate/publish OData V4 bindings và test service metadata.
5. Smoke-test IAM separation: mobile communication role không gọi được admin surfaces.
6. Bắt buộc HTTPS và redact request-body logging vì action parameter chứa token/password.
7. Rate-limit login/refresh/production commands ở API/Web Dispatcher layer phù hợp tenant.
8. Stress-test concurrent first-create operation snapshot, duplicate SyncItemUUID, failed login và refresh replay.
9. Test timeout sau server commit: mobile không resend với ID mới; `getSyncStatus` phải reconcile đúng receipt.
10. Thiết lập retention/cleanup session theo chính sách vận hành; việc này độc lập với production command flow và không biến thành SAP-side mobile queue.

## Rủi ro còn lại cần quyết định vận hành

- `PASSWORD_PEPPER` / `TOKEN_SECRET` trong config Z-table vẫn cần đánh giá secure-store/released API theo target release và rotation policy.
- Password KDF hiện tại cần được benchmark và migrate có version nếu tenant có released password-KDF API phù hợp; không đổi hash scheme trực tiếp khi chưa có migration path.
- Concurrent refresh / failed-login counter cần stress-test để loại lost-update trên runtime thật.
- Mọi target-specific index, IAM catalog, communication arrangement và Launchpad mapping phải được tạo từ hệ thống thật, không fabricate trong repo.

## Nghiệm thu tối thiểu

- Login/lockout/password-change/session tests.
- Role inactive mất quyền ở request kế tiếp.
- Work Context chặn operation ngoài Plant + Work Center được gán.
- Initial assign / transfer / recall / confirm giữ balance invariant.
- Reverse không sửa original CONFIRM và không reverse hai lần.
- `correctConfirm` append CORRECTION delta với reason.
- Same SyncItemUUID + same logical command không tạo duplicate ledger.
- Same SyncItemUUID + khác payload bị từ chối.
- Lost HTTP response -> `getSyncStatus` -> `SUCCESS` nếu ledger đã commit.
- `NOT_FOUND` không bị client coi là business failure.
- Mobile không query/update/delete raw ledger.

Xem sơ đồ tổng thể tại `docs/CASLA_DATA_MODEL.drawio`.
