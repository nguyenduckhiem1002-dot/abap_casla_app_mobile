# Trạng thái xử lý code review

## Đã sửa trong source

- Bổ sung ABAP language version 5 cho metadata class, CDS, service definition
  và table thuộc repo.
- Sửa `ZBP_I_MOB_USER` thành behavior pool của `ZI_MOB_USER`.
- Xóa bản sao table trong `src/tables`; `serialized/` là nguồn deploy duy nhất.
- Bổ sung `@Semantics.*` cho audit field và local ETag.
- Gộp khai báo UUID managed numbering, bổ sung create-by-association và update
  trong projection BDEF.
- Normalize `ValidTo = 00000000` thành `99991231` tại `ZI_PP_WORKERREF`.
- Worker validator chỉ dùng type của wrapper CDS và hỗ trợ mass validation.
- Auth action kiểm tra input rỗng/batch, đưa error vào cả `FAILED` và `REPORTED`,
  capture lỗi EML và kiểm tra credential bị thiếu.
- Login không còn trả message phân biệt credential inactive.
- Đổi mật khẩu revoke toàn bộ session đang hoạt động.
- Tách `ZUI_MOB_AUTH`, `ZUI_MOB_USER_ADM` khỏi service nghiệp vụ; auth entity
  không cho phép read.
- Domain BO đang fail-closed: direct mutation bị từ chối cho tới khi sync worker
  xác thực token và gọi EML nội bộ.
- Thêm validation bất biến cho `RemainingQuantity`.
- Nâng cấu hình abaplint từ parser-only lên syntax/DDIC/runtime-oriented rules.

## Đã sửa trong đợt hardening 2

- Login không còn set `FAILED` khi sai mật khẩu: kết quả trả `Status = 'F'`
  trong `ZA_MOB_LoginResult` để save sequence vẫn chạy và
  `FailedLoginCount`/`LockedUntil` được persist (khôi phục lockout).
  Client mobile phải đọc `Status` thay vì dựa vào HTTP error.
- Xóa compensation DELETE session thừa trong `login` (LUW đã rollback khi
  `FAILED` được set).
- So sánh password hash bằng `equals_constant_time` (login và changePassword).
- `changePassword` giữ lại session hiện tại khi revoke; chỉ các session khác
  bị thu hồi với `RevokedReason = 'PWD_CHANGE'`.
- Bật lại rule abaplint `unused_variables`, `unused_methods`.

## Đã sửa trong đợt hardening 3 (verify trên ADT)

- `@Capabilities.ReadRestrictions.Readable` được ADT xác nhận **không tồn tại**
  trong ABAP CDS (annotation của OData vocabulary, không phải ABAP annotation).
  Thay bằng CDS access control. Lưu ý ràng buộc DCL trên transactional query
  (ADT: "Access condition violates restrictions in projection views"): DCL của
  projection chỉ được phép `INHERITING CONDITIONS FROM ENTITY` hoặc full access
  rule, và projection tự áp access control của entity gốc theo 1:1. Thiết kế:
  - `ZI_MOB_USER` (DCL mới): deny-all bằng điều kiện luôn sai trên view gốc.
  - `ZC_MOB_USER` (DCL): `inheriting conditions from entity ZI_MOB_User`
    → service auth bị chặn read hoàn toàn.
  - `ZC_MOB_USER_ADM` (DCL mới): full access rule để override deny-all của
    gốc; việc giới hạn ai gọi được service admin nằm ở IAM/business catalog
    (mục 3 phần tenant).
  - `ZI_MOB_User`, `ZC_MOB_User`, `ZC_MOB_User_Adm` đều đặt
    `@AccessControl.authorizationCheck: #MANDATORY`.
  Cả 4 action của service auth đều là static action nên không bị ảnh hưởng
  bởi việc chặn read qua query path.
- Sửa lỗi cú pháp typed literal tại `ZI_PP_WORKERREF`: `dats'...'` →
  `abap.dats'...'` (ADT báo `Unexpected word`). Đây cũng chính là nguyên nhân
  abaplint báo "zi_pp_workerref not found" (parser fail nên view không được
  nhận diện).
- `createUser`: ADT xác nhận result row của static action không có `%tky`
  (`No component exists with the name "%TKY"`). Bỏ `%tky` khỏi result và gán
  `%param` qua `CORRESPONDING` để loại các thành phần `%` của READ result.
  Không còn mục nào chờ verify trên ADT.

## Đã sửa trong đợt hardening 4 (luồng đồng bộ)

- `zcl_mob_token_validator` nhận thêm `hash_token` và `validate_token`: băm
  token giờ chỉ có một implementation duy nhất. Trước đây logic băm nằm trong
  `PRIVATE SECTION` của `lhc_mobileuser`, nên mọi entry point mới (submitSync)
  buộc phải chép lại; hai bản chép sẽ trôi khỏi nhau khi đổi cách băm, và
  session sẽ hợp lệ ở đường này nhưng vô hiệu ở đường kia. `changePassword`
  đã chuyển sang `validate_token`; handler giữ `hash_token` riêng chỉ để gọi
  lại validator.
- `ZC_PP_OpAlloc` (BDEF projection): bỏ `use create/update` và 4 `use action`.
  Đường ghi tương lai đi qua sync worker gọi EML nội bộ trên `ZR_PP_OpAlloc`,
  nên projection không bao giờ cần các thao tác này. Trước đây metadata OData
  vẫn công bố chúng rồi bị `get_global_authorizations` từ chối — bề mặt thừa.
- `IMPLEMENTATION_STATUS.md`: bổ sung unique index còn thiếu cho
  `ZTB_PP_ALLOC_TXN` (chống replay ở tầng DB) và chốt bảng giá trị
  `SYNC_STATUS` / `ITEM_STATUS` cùng quy tắc retry.

Còn để mở trong luồng đồng bộ (chưa làm):

- App chưa có đường đọc kết quả: `ZA_PP_SubmitSyncResult` không có chi tiết
  item, và không có CDS view nào trên `ZTB_PP_SYNC_H/_I`. Cần projection chỉ
  đọc để app poll trạng thái từng item.
- Chốt bgPF **per-header** thay vì per-item: thứ tự nghiệp vụ
  (initialAssign → transfer → confirm) và đơn vị khóa là công đoạn.
- `MOBILE_CHANGED_AT` do thiết bị gửi lên: chỉ dùng để sắp thứ tự trong một
  batch, không dùng làm mốc nghiệp vụ. `EXECUTION_DATE` nên chặn ngày tương
  lai và ngày quá cũ.

## Đã sửa trong đợt hardening 5 (lớp phân quyền RBAC)

- **Lỗi runtime**: `ZI_MOB_UsrRol` là composition child khai báo
  `authorization dependent by _User`, mà RAP ủy quyền **mọi** thao tác của
  child (create by association, update, delete) sang `%update` của entity
  master. `lhc_mobileuser` đang đặt `%update = unauthorized`, nên gán chức
  danh từ Fiori sẽ luôn bị từ chối. Đã đổi sang `allowed`; bề mặt ghi vẫn
  đóng ở tầng projection vì `ZC_MOB_User_Adm` chỉ có `createUser` + `_Roles`
  và `ZC_MOB_User` chỉ có các auth action — không view nào khai `use update`.
- **Nối RBAC vào luồng auth**: thêm static action `getPermissions`
  (`ZA_MOB_Token` → `ZA_MOB_Permission [0..*]`) trên service auth di động.
  Action xác thực token qua `validate_token` rồi join
  usr_rol × role × rol_fnc × func, chỉ lấy chức danh `Status = 'A'`, DISTINCT
  theo `FuncID`. Trước đó 4 bảng RBAC chỉ có CRUD quản trị, app di động
  không có đường nào đọc được quyền của mình.
- **Chuẩn hóa access control**: 4 projection RBAC mới đều đặt
  `#NOT_REQUIRED`, không theo quy ước đã chốt ở hardening 3. Nay root
  projection (`ZC_MOB_Func_Adm`, `ZC_MOB_Role_Adm`) dùng `#MANDATORY` + DCL
  full access như `ZC_MOB_User_Adm`; child projection giữ `#NOT_REQUIRED`
  vì đi theo navigation từ root. Quy ước được viết thành bảng trong
  `IMPLEMENTATION_STATUS.md` để lần sau không phải đoán.
- **Dọn association hở**: `ZC_MOB_RolFunc_Adm._Func` và
  `ZC_MOB_UsrRol_Adm._Role` trước đây trỏ thẳng vào interface view mà
  không redirect — sẽ kéo `ZI_MOB_Func`/`ZI_MOB_Role` vào mô hình OData.
  `_Func` nay redirect sang `ZC_MOB_Func_Adm` (cùng service RBAC); `_Role`
  bị bỏ vì `ZUI_MOB_USER_ADM` không expose role và không chỗ nào dùng tới.
  Value help cũng chuyển từ interface view sang admin projection.

Cần verify khi activate trên ADT:

- `result [0..*]` cho static action `getPermissions`: nếu release không chấp
  nhận cardinality này thì đổi sang `[1..*]` (danh sách rỗng vẫn trả về
  bình thường ở runtime).
- Smoke-test: gán chức danh cho một tài khoản từ Fiori admin, rồi gọi
  `getPermissions` bằng token của tài khoản đó để xác nhận hai đầu khớp nhau.

Còn để mở:

- `ZTB_MOB_FUNC` không có field audit/ETag trong khi `ZTB_MOB_ROLE` có đủ.
  Sửa master data chức năng đồng thời sẽ ghi đè lẫn nhau mà không báo.
- Danh sách chức năng của một chức danh hiện chỉ hiển `FuncID`, chưa có
  `FuncName`; muốn hiển tên cần text element hoặc text association.

## Đã sửa trong đợt hardening 6 (quyền đi kèm kết quả login)

- `ZA_MOB_LoginResult` chuyển thành **deep abstract entity**: thêm
  `_Permissions : composition [0..*] of ZA_MOB_Permission`, kèm BDEF
  `abstract; with hierarchy;` theo đúng mẫu `ZA_PP_SubmitSync` đã chạy được.
  Cả `login` và `refresh` trả danh sách chức năng, nên quyền gán thêm lúc
  phiên đang mở sẽ tới thiết bị ở lần xoay token kế tiếp.
- Bỏ static action `getPermissions` vừa thêm ở hardening 5: danh sách đã đi
  kèm kết quả login/refresh nên endpoint riêng thành thừa, và bề mặt API
  di động không còn action nào mang tên RBAC.
- **Validate phía backend** (điểm bắt buộc): `zcl_mob_token_validator` nhận
  `get_permissions`, `has_function` và tham số `required_func` trên
  `validate_token` / `validate_hash`. Mọi thao tác cần quyền chỉ việc truyền
  `required_func`, validator tự đọc lại grant từ DB và trả
  `MISSING_PERMISSION` nếu thiếu. Danh sách trả cho thiết bị **không bao giờ**
  được đọc ngược lại làm căn cứ phân quyền — thiết bị có thể sửa hoặc bịa.
  Cả hai đầu (hiển thị và kiểm tra) dùng chung một truy vấn
  `get_permissions` nên không trôi khỏi nhau.
- Value help chuyển sang hai view đọc thuần `ZI_MOB_ROLE_VH` /
  `ZI_MOB_FUNC_VH` (không BDEF) thay vì trỏ vào projection có behavior ghi.

Cần verify khi activate trên ADT:

- Cú pháp deep abstract entity làm **result** của action (trước đây repo mới
  dùng deep abstract làm *parameter* cho `submitSync`). Nếu ADT báo lỗi ở
  `_Permissions`, đối chiếu lại signature do quick fix sinh ra.
- Smoke-test: gán chức danh cho một tài khoản từ Fiori admin, login bằng tài
  khoản đó và kiểm tra `_Permissions` trong response; sau đó đổi chức danh
  sang `Status = 'I'` và gọi `refresh` để xác nhận danh sách rỗng đi.

## Bắt buộc thực hiện trên tenant

Các mục sau không được giả lập trong repo vì phụ thuộc release và repository
metadata do ADT/tenant sinh:

1. Tạo unique secondary index:
   - `ZTB_MOB_USER`: client + normalized username.
   - `ZTB_MOB_SESSION`: client + access token hash.
   - `ZTB_MOB_SESSION`: client + refresh token hash.
   - Các index idempotency/domain được liệt kê trong `IMPLEMENTATION_STATUS.md`.
2. Tạo/publish ba OData V4 service binding riêng cho `ZUI_PP_OPALLOC`,
   `ZUI_MOB_AUTH`, `ZUI_MOB_USER_ADM`.
3. Gắn service Fiori admin vào IAM app/business catalog chỉ dành cho quản trị.
4. Xác nhận `ZTB_KB_NHANCONG` được release hoặc có package interface/use access.
5. Xác nhận quy ước ngày kết thúc vô hạn của bảng đối tác là `00000000`.
6. Benchmark KDF 10.000 vòng và kiểm tra KDF chuẩn nào được released trên tenant.
7. Chuyển pepper/token secret sang secure store khi tenant cung cấp released API;
   trong giai đoạn hiện tại không expose `ZTB_MOB_CONFIG` qua CDS/service.
8. Sau khi activate bộ DCL mới: smoke-test `login`/`createUser` bằng
   communication user của service mobile và kiểm tra GET trên `ZC_MOB_User`
   trả rỗng còn Fiori admin vẫn đọc được. Kỳ vọng: DCL chỉ áp trên query path
   (SADL/OData GET), không áp trên EML `IN LOCAL MODE` của BO runtime; nếu
   action bị chặn thì phải chuyển sang mô hình pfcg_auth cho `ZI_MOB_USER`.

## Chưa triển khai nghiệp vụ

- `initialAssign`, `transfer`, `confirm`, `reverse` vẫn chủ động fail-closed.
- Sync Inbox BO, `submitSync`, bgPF/APJ và SAP Production Confirmation adapter
  chưa được đấu dây. README/implementation status không được hiểu là các phần này
  đã sẵn sàng production.
- Demo class được giữ lại theo yêu cầu demo workflow trước đó; không được dùng làm
  implementation nghiệp vụ production.

## Kết quả kiểm tra local

- XML abapGit: parse hợp lệ.
- `git diff --check`: không có whitespace error.
- abaplint 2.120.25: còn một false positive/known dependency tại
  `ZI_PP_WORKERREF`, do bảng đối tác không thuộc repo. Việc activate thật phải
  được xác nhận trên tenant theo mục 4 ở trên.
