# CASLA Mobile Production Allocation

Tài liệu kỹ thuật chuẩn cho backend ABAP RAP/CDS của CASLA Mobile. Repository này lưu các object ABAP Cloud ở dạng serialize để triển khai bằng abapGit lên SAP S/4HANA Cloud Public Edition hoặc tenant ABAP Cloud tương thích.

> **Phạm vi nghiệp vụ:** backend ghi nhận nghiệp vụ phân bổ sản lượng CASLA vào các bảng Z trên SAP thông qua RAP/OData V4. Backend **không** tạo standard SAP Production Confirmation, material document hoặc business document SAP chuẩn khác.

> **Nguồn sự thật:** nội dung dưới đây được đối chiếu với source trong serialized/. Các chi tiết phụ thuộc release/tenant SAP được đánh dấu riêng và phải xác nhận bằng ADT/View Browser trước khi activate.

## 1. Tóm tắt hệ thống

CASLA Mobile cho phép người dùng mobile:

- đăng nhập, làm mới/đóng phiên và đổi mật khẩu;
- làm việc trong phạm vi Plant + Work Center được cấp qua RBAC;
- giao việc ban đầu, điều chuyển, thu hồi, xác nhận và đảo xác nhận sản lượng;
- tra cứu lịch sử theo phạm vi bản thân hoặc nhóm;
- xử lý retry/offline ở phía mobile bằng SyncItemUUID ổn định;
- đối chiếu một request sau timeout bằng getSyncStatus.

Người dùng Fiori/IAM có các bề mặt quản trị tách biệt:

- tài khoản và gán Role;
- Role, Function và Work Context;
- master Công đoạn/đơn giá theo phiên bản hiệu lực;
- điều chỉnh có kiểm soát một giao dịch CONFIRM và xem ledger chỉ đọc.

### Trạng thái triển khai

| Hạng mục | Trạng thái trong repository |
| --- | --- |
| ABAP Cloud syntax/quality gate | Có workflow GitHub Actions; source gate gần nhất ghi nhận 0 issue / 241 file |
| Mobile authentication/session | Đã có source RAP và behavior implementation |
| RBAC + Work Context | Đã có source, validation và query server-side |
| PP commands + immutable ledger | Đã có initialAssign, transfer, recall, confirm, reverse |
| Timeout reconciliation | Đã có getSyncStatus theo actor + SyncItemUUID |
| Fiori correction/audit | Đã có correctConfirm và ledger read-only |
| Master Công đoạn | Đã có versioned persistence, validation và OData V4 service |
| Tenant activation/ATC/IAM/index stress test | Chưa thể chứng minh chỉ bằng repository; bắt buộc thực hiện trên tenant đích |

## 2. Kiến trúc tổng thể

    Mobile app
      └─ local pending/retry queue
           └─ ZUI_MOB_AUTH / ZUI_PP_OPALLOC (OData V4)
                ├─ token hash + active session + device guard
                ├─ RBAC function + Work Context guard
                ├─ live SAP Production Order / Operation guard
                ├─ managed RAP domain action
                │    ├─ ZTB_PP_EMP_ALLOC       current balance
                │    └─ ZTB_PP_ALLOC_TXN       immutable POSTED receipt
                └─ response receipt / getSyncStatus

    Fiori + SAP IAM
      ├─ ZUI_MOB_USER_ADM       user administration
      ├─ ZUI_MOB_RBAC_ADM       role/function/work administration
      ├─ ZUI_MD_CONGDOAN_ADM    master Công đoạn
      └─ ZUI_PP_ALLOC_ADM       correction + audit

### Các quyết định kiến trúc cần giữ

1. **Server authoritative:** actor, phiên, permission, Work Context, worker và operation đều được xác thực lại trên backend.
2. **Command-only:** client gọi action nghiệp vụ; không được tự CRUD balance hoặc ledger.
3. **Immutable ledger:** reverse/correction tạo transaction mới và liên kết bằng OriginalTransactionUUID.
4. **Atomic RAP LUW:** cập nhật balance và append receipt nằm trong cùng transaction boundary.
5. **Idempotency ở mobile:** mobile sinh SyncItemUUID trước khi gửi và giữ nguyên khi retry.
6. **Timeout không đồng nghĩa thất bại:** mất response chỉ đưa item vào trạng thái chờ đối chiếu.
7. **Không có SAP-side mobile queue:** pending/retry thuộc mobile; repository không còn ZTB_PP_SYNC_H/I, submitSync hoặc background worker mobile.
8. **Không phụ thuộc ca làm việc:** assignment có thể kéo dài nhiều ngày/tuần; không còn rule “ca còn >= 60 phút”.

## 3. Cấu trúc repository

    serialized/                     object ABAP Cloud dạng abapGit
      *.tabl.xml                    bảng active/draft
      *.asddls                     CDS view/abstract entity
      *.asbdef                     behavior definition
      *.asdcls                     DCL
      *.clas.abap                   global behavior pool/class
      *.locals_imp.abap             local handler implementation
      *.srvdsrv                    service definition
      *.srvb.xml                    OData V4 service binding
      *.ddlx.asddlxs                metadata extension/UI annotation
    .github/workflows/abaplint.yml  quality gate
    docs/                           thiết kế sync, Fiori, ERD/flow
    abaplint.json                   cấu hình ABAP Cloud lint

Snapshot object count trong working tree:

| Loại | Số lượng |
| --- | ---: |
| Serialized files | 315 |
| DDIC table metadata | 24 |
| CDS source | 51 |
| Behavior definitions | 16 |
| DCL | 11 |
| Global/local ABAP implementation | 21 |
| Service definitions | 6 |
| Service bindings | 5 |
| Metadata extensions | 10 |

## 4. Mô hình dữ liệu

### 4.1. Identity, credential, session và RBAC

    ZTB_MOB_USER
      ├─ ZTB_MOB_CRED
      ├─ ZTB_MOB_SESSION
      └─ ZTB_MOB_USR_ROL ── ZTB_MOB_ROLE
                              ├─ ZTB_MOB_ROL_FNC ── ZTB_MOB_FUNC
                              └─ ZTB_MOB_ROL_WRK ── ZTB_MOB_WORK

| Bảng | Vai trò | Ghi chú |
| --- | --- | --- |
| ZTB_MOB_USER | tài khoản mobile | username chuẩn hóa, worker mapping, trạng thái, lockout, cờ đổi mật khẩu |
| ZTB_MOB_CRED | credential | hash, salt, algorithm, số vòng, trạng thái; không expose cho mobile |
| ZTB_MOB_SESSION | access/refresh session | chỉ lưu hash token, expiry, device, revoke state |
| ZTB_MOB_ROLE | Role | A/I; vô hiệu hóa thay cho hard-delete |
| ZTB_MOB_FUNC | Function | mã quyền ổn định theo module |
| ZTB_MOB_WORK | Work Context | Plant, WorkCenter, bộ phận, vị trí, A/I |
| mapping tables | quan hệ cấp quyền | User-Role, Role-Function, Role-Work |

### 4.2. Production allocation

    ZR_PP_OpAlloc / ZTB_PP_OP_ALLOC
      ├─ ZR_PP_EmpAlloc / ZTB_PP_EMP_ALLOC
      └─ ZR_PP_AllocTxn / ZTB_PP_ALLOC_TXN

| Bảng | Dữ liệu | Business rule chính |
| --- | --- | --- |
| ZTB_PP_OP_ALLOC | snapshot operation | live resolve từ SAP theo ProductionOrder + Operation; cần unique business key trên tenant |
| ZTB_PP_EMP_ALLOC | balance theo worker | khóa logic OperationUUID + WorkerID; invariant Remaining bắt buộc đúng |
| ZTB_PP_ALLOC_TXN | ledger/audit append-only | POSTED receipt, idempotency, lineage, actor/session/device, quantity và lý do |

Các field legacy SAP_CONFIRMATION_GROUP, SAP_CONFIRMATION_COUNT, SAP_ERROR_CODE, SAP_ERROR_TEXT vẫn còn trong ledger để tránh migration DDIC không cần thiết. Chúng không phải bằng chứng của standard SAP Production Confirmation và không thuộc flow hiện hành.

### 4.3. Invariant balance

    Remaining
      = InitialAssigned
      + TransferredIn
      - TransferredOut
      - Recalled
      - Completed

validateBalance reject khi Remaining < 0 hoặc số dư lưu trong entity không bằng giá trị tính lại.

### 4.4. Master Công đoạn

ZTB_MD_CONGDOAN dùng khóa phiên bản:

    CLIENT + MA_CONGDOAN + VALID_FROM

Các field chính: MA_CONGDOAN, TEN_CONGDOAN, BO_PHAN, DONGIA_XM, DONGIA_GC, VALID_FROM, VALID_TO và managed audit fields. MA_CONGDOAN được lấy từ OperationStandardTextCode để enrichment/reporting; master này không quyết định operation SAP có được phép thao tác hay không.

Validation hiện có:

- mã, tên và hai mốc hiệu lực bắt buộc;
- ValidFrom <= ValidTo;
- đơn giá không âm;
- cùng mã không được chồng lấn khoảng hiệu lực;
- Fiori không được hard-delete bản ghi lịch sử.

## 5. Authentication, session và bảo mật mật khẩu

### 5.1. Luồng login

1. Chuẩn hóa username bằng trim/condense và lowercase.
2. Chỉ tìm account active, credential active và không đang lock.
3. Verify password qua KDF dùng chung.
4. Tạo access/refresh token dạng UUID ghép, chỉ lưu hash.
5. Một device chỉ có một active session; account giữ tối đa 5 session active. Session cũ bị revoke với reason NEW_LOGIN.
6. Access token hết hạn sau 30 phút; refresh token hết hạn sau 30 ngày.
7. Trả permissions và Work Context hiệu lực để mobile dựng UI; backend vẫn kiểm tra lại khi thực thi.

### 5.2. Lockout và đổi mật khẩu

- 5 lần thất bại trong cửa sổ 1 phút sẽ lock account 10 phút.
- logout, refresh-token rotation và revoke session nằm trong behavior implementation.
- Đổi mật khẩu của chính mình hoặc admin reset đều revoke các session active.
- Tài khoản tạo mới được đặt PasswordChangeRequired = true.

### 5.3. KDF hiện tại và lưu ý tài liệu

ZCL_MOB_TOKEN_VALIDATOR là nguồn logic dùng chung cho hash token, hash password và verify worker password. Password dùng custom iterative SHA-256 với:

- secret PASSWORD_PEPPER lấy từ ZTB_MOB_CONFIG;
- salt riêng từng credential;
- mặc định 10.000 vòng (10.000..100.000 là miền được chấp nhận khi đọc credential);
- so sánh digest constant-time.

> **Sai lệch cần xử lý:** predicate thực tế hiện chỉ enforce mật khẩu dài tối thiểu 6 ký tự và không chứa username. Error text trong createUser vẫn nói “12 ký tự, hoa, thường và số”. Khi muốn áp chính sách mạnh hơn, phải sửa predicate, message và migration/test cùng lúc; không được coi message hiện tại là enforcement.

### 5.4. Token guard

Mọi mobile action sau login gọi validate_token/validate_hash để kiểm tra:

- token tồn tại, hash đúng, session active và chưa hết hạn;
- DeviceID khớp session;
- user active;
- không bị chặn bởi PasswordChangeRequired, trừ flow đổi mật khẩu;
- function bắt buộc nếu action yêu cầu.

ActorUserUUID luôn lấy từ session đã validate, không nhận từ payload client.

## 6. SAP live operation guard

ZCL_PP_OPERATION_GUARD=>resolve nhận ProductionOrder + Operation và trả context đã resolve. Các bước:

1. Đọc active system status từ I_ManufacturingOrderStatus.
2. Bắt buộc status REL (I0002). Chặn TECO (I0045), CLSD (I0046), DLFL (I0076), kể cả khi REL vẫn còn active.
3. Đọc I_ManufacturingOrderOperation theo ManufacturingOrder và ManufacturingOrderOperation_2.
4. Bắt buộc OperationControlProfile = YBP1, không đánh dấu xóa, có OperationStandardTextCode.
5. Bắt buộc planned quantity > 0, UoM, Plant và Work Center internal ID.
6. Resolve mã Work Center từ I_WorkCenter theo Plant + WorkCenterInternalID.
7. Ghi snapshot vào ZTB_PP_OP_ALLOC, trong đó OperationStandardTextCode -> MaCongDoan.

Mỗi mutation đều resolve live trước khi thay đổi balance. Snapshot cũ được refresh nếu các field live thay đổi. Nếu có nhiều hơn một snapshot cho business key, flow fail-closed với OPERATION_SNAPSHOT_DUPLICATE.

> **Tenant dependency:** tên view, field và release status của các CDS SAP phải được kiểm tra trên tenant đích bằng ADT/View Browser. abaplint không thay thế activation hoặc ATC.

## 7. Domain commands và contract

### 7.1. Internal actions và facade mobile

| Layer | Action | Mục đích |
| --- | --- | --- |
| Domain bound | initialAssign | tạo/cộng balance và append INITIAL_ASSIGN |
| Domain bound | transfer | trừ source, cộng/tạo target và append TRANSFER |
| Domain bound | recall | thu hồi phần còn lại thuộc assignment/transfer hợp lệ |
| Domain bound | confirm | cộng Completed, trừ Remaining và append CONFIRM |
| Domain bound | reverse | compensating transaction cho một CONFIRM |
| Domain bound | correctConfirm | Fiori/IAM điều chỉnh qua signed CORRECTION |
| Mobile static | submitInitialAssign | validate facade rồi gọi domain action |
| Mobile static | submitTransfer | validate facade rồi gọi domain action |
| Mobile static | submitRecall | validate facade rồi gọi domain action |
| Mobile static | submitConfirm | validate facade rồi gọi domain action |
| Mobile static | submitReverse | validate facade rồi gọi domain action |
| Mobile static | getSyncStatus | đối chiếu receipt sau timeout |
| Mobile static | getWorkHistory | trả summary/entries theo scope |

Mobile chỉ gửi business key ProductionOrder + Operation; backend tự resolve OperationUUID. Mỗi mutation gửi SyncItemUUID dạng UUID tạo ở client trước lần gửi đầu tiên.

### 7.2. Payload tối thiểu theo action

| Action | Dữ liệu nghiệp vụ |
| --- | --- |
| submitInitialAssign | ToWorkerID, Quantity, UnitOfMeasure, ExecutionDate, WorkerPassword |
| submitTransfer | FromWorkerID, ToWorkerID, Quantity, UnitOfMeasure, ExecutionDate, WorkerPassword |
| submitRecall | WorkerID, Quantity, UnitOfMeasure, ExecutionDate, OriginalTransactionUUID, WorkerPassword |
| submitConfirm | WorkerID, Quantity, UnitOfMeasure, ExecutionDate, optional OriginalTransactionUUID, WorkerPassword |
| submitReverse | TransactionUUID, Reason |
| getSyncStatus | SyncItemUUID |
| getWorkHistory | RangeCode, ngày custom nếu có, optional WorkerID, SummaryOnly |

AccessToken và DeviceID nằm trong các abstract parameter entity của mobile contract. Plaintext worker password chỉ tồn tại trong request xử lý; không ghi vào ledger.

### 7.3. Validation nghiệp vụ

**Initial Assign**

- token có function PP_INITIAL_ASSIGN;
- Work Context của actor khớp operation;
- worker active theo Plant/Work Center/ExecutionDate và password đúng;
- quantity > 0, UoM khớp và không vượt operation quantity;
- tạo mới hoặc cộng vào balance của worker;
- append INITIAL_ASSIGN với SourceChannel = MOBILE, VerificationMethod = PASSWORD.

**Transfer**

- source và target khác nhau;
- target được verify password và active đúng scope/ngày;
- source đủ Remaining;
- source giảm TransferredOut, target tăng TransferredIn;
- append TRANSFER với from/to worker.

**Recall**

- original transaction phải thuộc operation và là INITIAL_ASSIGN hoặc TRANSFER;
- worker balance tồn tại, cùng UoM và đủ Remaining;
- giảm Remaining, tăng Recalled;
- append RECALL liên kết original; không sửa transaction gốc.

**Confirm**

- worker active, UoM khớp operation, password đúng và balance đủ;
- nếu có OriginalTransactionUUID, original phải tồn tại, đúng operation và POSTED;
- tăng Completed, giảm Remaining;
- append CONFIRM dạng CASLA custom transaction, không gọi API confirm chuẩn của SAP.

**Reverse**

- target phải là một CONFIRM POSTED đúng operation;
- không reverse lần hai;
- effective quantity = quantity gốc + tổng các CORRECTION trước đó;
- giảm Completed và cộng lại Remaining theo effective quantity;
- append REVERSE liên kết original, giữ nguyên các row gốc.

**Controlled correction**

- chỉ qua correctConfirm trên service IAM/Fiori;
- target phải là CONFIRM POSTED và chưa bị reverse;
- NewQuantity cùng UoM, reason code/text bắt buộc;
- delta = NewQuantity - effective current quantity;
- balance điều chỉnh theo delta;
- append CORRECTION với SourceChannel = FIORI, VerificationMethod = IAM.

## 8. Idempotency và timeout reconciliation

### 8.1. Quy tắc SyncItemUUID

    Chưa có receipt
      -> thực thi command

    Có đúng một receipt và payload khớp
      -> trả idempotent success, không tạo transaction mới

    Có receipt nhưng payload khác
      -> IDEMPOTENCY_KEY_REUSED

    Có hơn một receipt
      -> SYNC_RECEIPT_DUPLICATE, fail-closed

Payload dùng để đối chiếu gồm operation, transaction type và các field nghiệp vụ liên quan như worker, from/to worker, quantity, UoM, execution date, original transaction. Cùng key nhưng khác logic nghiệp vụ không được coi là retry hợp lệ.

### 8.2. Trình tự sau khi HTTP response mất

    Mobile tạo SyncItemUUID
            ↓
    submit command
            ↓
    RAP cập nhật balance + append ledger trong cùng LUW
            ↓
    response thành công hoặc bị mất
            ↓
    timeout => UNKNOWN / PENDING_CONFIRMATION
            ↓
    getSyncStatus(AccessToken, DeviceID, SyncItemUUID)
            ├─ SUCCESS   => mark SYNCED
            └─ NOT_FOUND => chưa chứng minh commit; giữ pending hoặc retry cùng key

NOT_FOUND không phải business rejection. Nếu retry, mobile phải gửi lại cùng logical command và cùng SyncItemUUID, không sinh ID mới chỉ vì timeout.

### 8.3. RAP transactional buffer

Facade gọi domain action trong IN LOCAL MODE, sau đó đọc receipt bằng EML:

    READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
      ENTITY OperationAllocation BY _Transactions
      ...

Không dùng Open SQL để đọc row child vừa tạo trước save sequence, vì row có thể chỉ mới nằm trong RAP transactional buffer.

## 9. Tra cứu lịch sử

ZCL_PP_WORK_HISTORY đọc dữ liệu từ ZTB_PP_ALLOC_TXN kết hợp operation snapshot và ZI_PP_WorkerRef để lấy tên worker. ZI_PP_WorkerRef chỉ dùng cho hiển thị/active worker reference, không dùng để quyết định RBAC.

### Range

| RangeCode | Cửa sổ |
| --- | --- |
| D | hôm nay |
| W | 7 ngày gần nhất, từ hôm nay trừ 6 ngày |
| M hoặc giá trị khác | 30 ngày gần nhất, từ hôm nay trừ 29 ngày |
| C | custom; bắt buộc from/to, không ở tương lai, date_to - date_from < 92 |

Custom range được phép tối đa 92 ngày theo cách tính inclusive hiện tại. Kết quả quét tối đa 20.000 ledger rows; entries trả ra tối đa 1.000 row. IsTruncated bật khi vượt giới hạn.

### Scope

- Có PP_HIST_TEAM: xem các assignment/transfer do chính actor ghi nhận, cùng các row dẫn xuất đúng lineage của scope đó.
- Chỉ có PP_HIST_SELF: bỏ qua WorkerID do client gửi và map worker từ account của actor; chỉ xem lịch sử của chính worker.
- Không có function phù hợp: MISSING_PERMISSION.
- Role inactive/work inactive bị loại ngay tại thời điểm query.

Summary cộng INITIAL_ASSIGN/transfer vào assigned, CONFIRM vào completed, REVERSE trừ completed. RECALL và CORRECTION không được cộng vào summary hiện tại; nếu cần hiển thị tác động của hai loại này, phải mở rộng rõ contract/reporting rule trước khi sửa code.

## 10. Service surface

### 10.1. Mobile

| Service definition | Binding hiện có | Expose | Bảo vệ |
| --- | --- | --- | --- |
| ZUI_MOB_AUTH | ZAPI_MOB_AUTH | MobileAuthentication | CASLA token/session logic trong action |
| ZUI_PP_OPALLOC | Chưa có file binding serialize trong repository | OperationAllocations | mobile token + Work Context + live operation guard |

ZC_MOB_User chỉ expose login/logout/refresh/changePassword qua mobile projection. ZC_PP_OpAlloc chỉ expose static command/status/history actions. Mobile không được truy cập raw EmployeeAllocation hoặc AllocationTransaction entity set.

### 10.2. Fiori/IAM

| Service definition | Binding | Expose | Mục đích |
| --- | --- | --- | --- |
| ZUI_MOB_USER_ADM | ZUI_MOB_USER_ADM_O4 | Accounts, UserRoles, RoleValueHelp | tạo tài khoản, reset mật khẩu, unlock, gán Role |
| ZUI_MOB_RBAC_ADM | ZUI_MOB_RBAC_ADM_O4 | Roles, RoleFunctions, RoleWorkContexts, Functions, WorkContexts, value helps | quản trị RBAC/Work Context |
| ZUI_MD_CONGDOAN_ADM | ZUI_MD_CONGDOAN_ADM_O4 | CongDoans | master Công đoạn/đơn giá versioned |
| ZUI_PP_ALLOC_ADM | ZUI_PP_ALLOC_ADM_O4 | OperationAllocations, AllocationTransactions | correction có kiểm soát + audit read-only |

Không đưa các admin binding vào mobile communication scenario. Service production vẫn cần tạo/publish binding OData V4 trên tenant đích. Fiori dùng SAP IAM/business-user context, không truyền custom CASLA token vào action correction.

## 11. DCL và authorization boundary

- Mobile projection dùng DCL kế thừa điều kiện từ root, trong đó điều kiện mặc định ở root được cấu hình theo hướng không cho đọc trực tiếp.
- Admin projections có @AccessControl.authorizationCheck: #MANDATORY và DCL grant select riêng cho từng bề mặt.
- Behavior pool có authorization handler cho action, nhưng đây không phải thay thế cho IAM hoặc kiểm tra token trong static mobile action.
- Role/Work/Function/master không hard-delete ở behavior handler; deactivate để giữ liên kết và lịch sử.
- ZC_PP_AllocTxn_Adm là query read-only; không có update/delete ledger.

## 12. Concurrency, index và rủi ro còn lại

### Đã có trong thiết kế/code

- root ZR_PP_OpAlloc dùng lock master;
- child balance/ledger dùng lock dependent by _Operation;
- mutation cùng operation chạy trong managed RAP LUW;
- application fail-closed cho 0/1/>1 receipt hoặc balance duplicate.

### Bắt buộc harden trên tenant

1. Enforce/verify unique business key CLIENT + PRODUCTION_ORDER + OPERATION_NO cho ZTB_PP_OP_ALLOC. Application SELECT ... UP TO 2 ROWS không đủ để chặn race của hai first-create đồng thời.
2. Stress-test duplicate SyncItemUUID đồng thời.
3. Stress-test transfer/confirm concurrent trên cùng worker balance và lock conflict.
4. Verify index/execution plan theo data volume thật; không tạo index theo cảm tính.
5. Chốt semantics trước khi tạo unique index mù trên SyncItemUUID, vì các row Fiori CORRECTION có thể không dùng mobile identity.
6. Review secure storage/rotation cho PASSWORD_PEPPER và TOKEN_SECRET; hiện code đọc từ active config row ZTB_MOB_CONFIG.
7. Benchmark KDF 10.000 vòng và thiết kế version/migration nếu thay thuật toán.
8. Redact request body vì payload chứa token/password; bắt buộc HTTPS và rate-limit ở lớp API/Web Dispatcher phù hợp.
9. Thiết lập retention/cleanup session độc lập với production command flow.

## 13. Triển khai và kiểm thử

### Dependency order đề xuất

1. Import repository bằng abapGit.
2. Activate DDIC active/draft tables.
3. Activate CDS interface/wrapper và abstract entities.
4. Activate behavior definitions.
5. Activate behavior pool/class implementations.
6. Activate DCL và metadata extensions.
7. Activate service definitions.
8. Activate/publish OData V4 bindings.
9. Gán IAM business catalogs/roles cho bốn admin surfaces.
10. Cấu hình mobile communication scenario chỉ cho ZUI_MOB_AUTH và ZUI_PP_OPALLOC sau khi binding production đã được tạo/publish.

### Smoke test tối thiểu

- tạo account + credential + optional initial Role trong một LUW;
- login sai 5 lần, lock, unlock và login lại;
- login/refresh rotation/logout/device mismatch/password-change revoke;
- role/work inactive mất quyền ở request tiếp theo;
- operation REL thành TECO bị chặn;
- initial assign -> transfer -> recall -> confirm giữ invariant;
- same SyncItemUUID + same payload không tạo duplicate;
- same key + payload khác bị IDEMPOTENCY_KEY_REUSED;
- deliberately drop response sau commit, gọi getSyncStatus nhận SUCCESS;
- NOT_FOUND không bị mobile đánh dấu business failed;
- reverse không sửa original và không reverse lần hai;
- correction tạo signed CORRECTION, sau đó reverse theo effective quantity;
- master Công đoạn reject validity overlap/negative price;
- mobile role không đọc/update/delete raw ledger hoặc gọi admin service.

### Quality gate

Workflow .github/workflows/abaplint.yml hiện bật kiểm tra comment artifact, pattern RAP activation và chạy:

    @abaplint/cli 2.120.35
    ABAP language version: Cloud

Kết quả source gate được ghi nhận trong repository: 0 issue(s) found, 241 file(s) analyzed. Đây là kiểm tra tĩnh; không phải bằng chứng rằng tenant đích đã activate sạch.

## 14. Tài liệu liên quan

- [Thiết kế mobile command và reconciliation](docs/ABAP_RAP_MOBILE_SYNC_PLAN.md)
- [Thiết kế các bề mặt Fiori Elements](docs/FIORI_ELEMENTS_ADMIN.md)
- [Sơ đồ ERD và flow](docs/CASLA_DATA_MODEL.drawio)
- [Trạng thái implementation](IMPLEMENTATION_STATUS.md)
- [Trạng thái remediation/review](REVIEW_REMEDIATION_STATUS.md)
- [Rà soát bảo mật và hiệu năng](SECURITY_PERFORMANCE_REVIEW.md)
- [Prototype flow tương tác](wf_flow_redesign_prototype.html)
