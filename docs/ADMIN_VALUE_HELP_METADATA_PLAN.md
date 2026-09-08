# Kế hoạch hoàn thiện value help và metadata cho các màn hình admin

Ngày rà soát: 08/09/2026. Trạng thái: **đã triển khai batch đầu tiên; còn chờ activation/EDMX và các provider lịch sử mở rộng trên tenant**.

Nhật ký triển khai hiện tại: đã khôi phục metadata Operation Allocation, hoàn thiện các mapping chính cho ledger, Work/Role assignment, master công đoạn, ca; expose ShiftValueHelp cho allocation/shift service; thêm text metadata cho mã Role/Function/Work/Operation; gom batch validation cho Function/Work/Role assignment; và thêm các provider lịch sử cho nhân công, công đoạn, giao dịch xác nhận. Chưa đánh dấu hoàn thành toàn bộ kế hoạch vì chưa có kiểm chứng SAP tenant/EDMX và chưa triển khai toàn bộ code-list/hành vi lọc lịch sử nâng cao.

Tài liệu dành cho agent triển khai tiếp, bao gồm Luna 5.6. Thực hiện tuần tự theo giai đoạn, không chia theo ngày. Không coi một giai đoạn hoàn thành nếu chưa đạt điều kiện nghiệm thu tương ứng.

## 1. Mục tiêu, baseline và giới hạn

- Hoàn thiện trải nghiệm List Report, Object Page, bảng con và dialog action của toàn bộ service admin hiện có.
- Mỗi field có nhãn rõ ràng; field tham chiếu cần chọn có value help đúng nguồn, text và ngữ cảnh. Field không phù hợp với value help phải được ghi rõ lý do, không thêm F4 đại trà.
- Giữ đúng nhãn **`@EndUserText.label: 'Work ID'`**. Work ID là mã vị trí/phạm vi làm việc của ứng dụng, không phải SAP Work Center.
- Đối chiếu ba lớp: Git trước đổi package `f5e8c2e`, Git sau đổi package/HEAD `4c1c114`, và working tree hiện tại. Working tree đang có nhiều sửa đổi chưa commit, bao gồm sửa nghiệp vụ từ các lượt trước; phải giữ nguyên phần không thuộc phạm vi này.
- Đây là các commit có sẵn trong repository local, chưa xác minh remote có commit mới hơn trong lần lập kế hoạch này. Trước khi code lại, kiểm tra HEAD/diff; nếu cần cập nhật remote thì xử lý working tree an toàn trước, không tự stash/reset hoặc ghi đè.
- Không restore nguyên file từ commit cũ. Chỉ đưa lại annotation đã xác nhận đúng vào object ở package hiện tại, rồi kiểm tra với logic mới.
- Không đổi key/type/alias OData hiện hữu, không chuyển package, không xóa/tạo lại bảng, không chạy seed hay xóa dữ liệu để phục vụ metadata.
- Giữ `ZUI_PP_SHIFT_ADM` và binding riêng cho cấu hình ca. `ZI_PP_Shift` phục vụ read/value-help; `ZR_PP_Shift`/`ZC_PP_Shift_Adm` phục vụ transactional create/update. Thêm value help ca vào service khác không đồng nghĩa gộp app ca vào app sản lượng.
- Không thay đổi logic phân công, confirm/correct/reverse, ca đêm, offline timestamp, quyền quản lý/nhân công. Chỉ tối ưu validator liên quan trực tiếp tới màn admin nếu bảo toàn hành vi và có test.

Workspace lúc rà soát: `G:\Android\abap_casla_app_mobile`. Các đường dẫn bên dưới tính từ workspace này.

### Quy ước package để tìm đúng file

| Ký hiệu | Thư mục source hiện tại |
| --- | --- |
| ROOT | `serialized/` |
| AUTH | `serialized/zpk_xnsl_sm_backend_auth/` |
| ROLE | `serialized/zpk_xnsl_sm_backend_role/` |
| WC | `serialized/zpk_xnsl_sm_backend_wc/` |
| CD | `serialized/zpk_xnsl_sm_backend_cd/` |

Lưu ý đặc biệt: DDLS `zc_mob_rolwork_adm` nằm trong WC, nhưng DDLX tương ứng hiện nằm trong ROLE. Đây là vị trí đang có; không tự di chuyển để làm chúng cùng thư mục.

## 2. Phát hiện đã xác minh từ source và Git

| Mã | Bằng chứng | Hệ quả và việc cần làm |
| --- | --- | --- |
| F01 | ROOT `zc_pp_opalloc_adm.ddls.asddls` hiện mất label/value help cho MaCongDoan, Plant, WorkCenter, UnitOfMeasure so với `f5e8c2e`; root nguồn cũng không cung cấp các value help này | Khôi phục có chọn lọc; không được chỉ expose provider trong service rồi coi là đủ |
| F02 | ROOT `zc_pp_opalloc_adm.ddlx.asddlxs` mất selectionField cho ProductionOrder, MaCongDoan, Plant, WorkCenter so với bản cũ | Khôi phục filter bar; bổ sung facet và audit/technical policy còn thiếu |
| F03 | ROLE `zc_mob_rolwork_adm.ddlx.asddlxs` chỉ còn RoleID ẩn và WorkID lineItem; DDLS có sẵn WorkName/Plant/WorkCenter/BoPhan/Location | Khôi phục facet, identification, các cột mô tả; bản cũ đã có WorkName/Plant/WorkCenter |
| F04 | ROOT `zc_pp_alloctxn_adm.ddlx.asddlxs` gán ShiftID → `ZI_PP_Shift`, nhưng `zui_pp_alloc_adm.srvd.srvdsrv` không expose provider này | Sửa chuỗi provider → annotation → expose; bổ sung ngữ cảnh Plant và xử lý phiên bản ca |
| F05 | ROOT `zi_mob_workcenter_vh.ddls.asddls` lặp `@EndUserText.label` trên cùng WorkCenter; provider chỉ có Plant/WorkCenter, dùng DISTINCT | Bỏ annotation lặp; xác minh key/cardinality trước khi bổ sung text, không tùy tiện bỏ DISTINCT |
| F06 | `ZI_PP_Worker_VH` lọc ngày hiện tại; key gồm WorkerID, WorkerName, Plant, WorkCenter. `ZI_MD_CongDoan_VH` cũng lọc ngày hiện tại | Không dùng hai provider này làm nguồn duy nhất cho bộ lọc lịch sử. Một WorkerID có thể hiện nhiều dòng do nhiều vị trí/tên; cần UX và key rõ ràng |
| F07 | `ZI_MOB_Role_VH`, `ZI_MOB_Func_VH` có search mã/tên nhưng chưa có text.element cho mã; Work VH đã có text.element | Hoàn thiện hiển thị mã + tên, giữ provider active-only cho gán mới |
| F08 | AUTH user MDE còn `Change Password`, WC MDE còn `Work Name`/`Plant`; user lineItem có vị trí 70 và 80 bị dùng lại | Chuẩn hóa tiếng Việt trừ Work ID theo yêu cầu; bố trí thứ tự riêng cho field và action |
| F09 | ROLE function MDE dùng string path `FuncId` trong header description, field source là `FuncID` | Dùng đúng tên field trong annotation path, xác minh path sinh ra trong EDMX; không dựa vào ABAP identifier không phân biệt hoa/thường |
| F10 | `ZA_PP_CorrectConfirm` chưa có label từng tham số hay value help TransactionUUID/UoM; create-user thiếu label Username/Password/FullName/Email | Bao phủ cả dialog action, không chỉ màn hình chính |
| F11 | CD MDE chưa có selectionField; nhiều field CD projection/interface chưa có EndUserText label; ledger MDE chưa có facet/identification đầy đủ | Bổ sung filter và Object Page; nhãn UI.lineItem không thay thế cho nhãn dùng ở mọi nơi |
| F12 | Shift projection và MDE cùng khai báo selectionField; ValidFrom có position khác nhau | Chọn MDE là nơi quản lý layout; kiểm tra annotation hiệu lực sau khi gộp, tránh hai nguồn cấu hình lệch nhau |
| F13 | `validateFunctionAssignment`, `validateWorkAssignment`, `validateRoleAssignment` đang SELECT trong LOOP | Tối ưu đọc theo tập mã cho thao tác gán nhiều dòng; giữ failed/reported theo từng dòng |
| F14 | WC `validateWork` hiện chỉ kiểm tra các field bắt buộc và IsActive A/I, chưa tra tính hợp lệ của cặp Plant/WorkCenter | Khi hoàn thiện dependent value help phải bổ sung kiểm tra cặp mã ở backend; F4 không đủ ngăn request nhập tay sai |

Có sẵn **11 metadata extension cho 11 entity admin**. Vấn đề là mức độ hoàn thiện và tính nhất quán, không phải thiếu toàn bộ MDE. Đừng tạo thêm object trùng tên để thay cái đang có.

Baseline kiểm tra local trong lần rà soát này:

- `npx --yes @abaplint/cli@2.120.35`: **0 issues, 351 files analyzed**.
- `python scripts/check_rap_patterns.py`: exit 0.
- `git diff --check`: không phát hiện lỗi whitespace; Git có cảnh báo LF/CRLF.
- Chưa chạy activation/ATC, ABAP Unit, Fiori Preview, lấy EDMX hay đo performance trên tenant. Lint hiện tại không bắt được đầy đủ các khoảng trống metadata nêu trên.

## 3. Nguyên tắc kỹ thuật sau research SAP

### 3.1. Phân lớp annotation

1. DDLS: khai báo field/association/semantics, text mapping, search và valueHelpDefinition theo pattern đang dùng trong repo. Không đổi quantity thành string để tránh lỗi UoM.
2. DDLX: quản lý header, facet, fieldGroup/identification, lineItem, selectionField, textArrangement, visibility và nhãn trải nghiệm. Giữ layer `#CORE` hiện tại, không đổi sang layer ưu tiên cao hơn để che lỗi.
3. Đảm bảo `@Metadata.allowExtensions: true`. Chỉ annotation được cho phép ở MDE mới được đặt trong MDE; cần kiểm tra annotation definition theo release tenant. MDE có thể override annotation trong DDLS, nên phải kiểm tra giá trị hiệu lực, không chỉ nhìn DDLS. [SAP: Metadata Extensions](https://help.sap.com/docs/abap-cloud/abap-data-models/metadata-extensions)
4. `@ObjectModel.text.element` nối mã với field mô tả đã có trong cùng entity. Ưu tiên reuse WorkName/RoleName/FuncName thay vì tạo virtual element đọc DB từng dòng. Dùng `@UI.textArrangement` phù hợp, không hiển thị tên hai lần. [SAP: Text elements in the same entity](https://help.sap.com/docs/abap-cloud/abap-rap/providing-text-by-text-elements-in-same-entity)
5. Tách basic search (`@Search.searchable`, defaultSearchElement) khỏi field filters (`@UI.selectionField`) và F4 (`@Consumption.valueHelpDefinition`). Có một loại không có nghĩa hai loại còn lại tự hoạt động. [SAP: Text and fuzzy search](https://help.sap.com/docs/ABAP_PLATFORM_NEW/cc0c305d2fab47bd808adcad3ca7ee9d/6f9212bbaf5e4d598c774b96d93f7b79.html?locale=en-US&state=PRODUCTION&version=202210.000)

### 3.2. Value help, binding và service

- Dùng `usage: #FILTER` khi chỉ muốn giới hạn danh sách, `#RESULT` khi muốn trả thêm field, `#FILTER_AND_RESULT` khi thực sự cần cả hai. Không để kết quả popup âm thầm ghi đè Plant hoặc field readonly. SAP có ví dụ cụ thể về các kiểu binding này. [SAP: Projection views and value help](https://help.sap.com/docs/abap-cloud/abap-rap/projecting-data-model-in-cds-projection-views?source=redirect)
- Expose provider được dùng trong từng service tiêu thụ, kể cả text provider qua association. Không đổi alias đang dùng; thêm alias riêng cho provider mới. [SAP: Exposing relevant CDS views](https://help.sap.com/docs/abap-cloud/abap-rap/exposing-relevant-cds-views-as-service)
- Đặc biệt, value help của tham số action phải được thêm rõ vào service definition. Sau khi đổi abstract parameter cần xác minh metadata thực tế và refresh theo quy trình của tenant, không kết luận từ file source. [SAP: Development constraints](https://help.sap.com/docs/latest/fc4c71aa50014fd1b43721701471913d/9cddeaa625854358b9cbedd198667787.html)
- Không coi additionalBinding là backend validation hay authorization. Người gọi có thể gửi trực tiếp mã không hợp lệ; validator phải tiếp tục bảo vệ nghiệp vụ.
- Additional binding theo ngày không tự tạo điều kiện khoảng `ValidFrom <= WorkDate <= ValidTo`. Không bind WorkDate bằng dấu bằng với ValidFrom rồi gọi là “lọc theo hiệu lực”.
- Không thêm tham số vào action hiện hữu chỉ để làm popup đẹp hơn. Ngữ cảnh bound entity truyền được vào action value help hay không phải được kiểm tra ở UI5/tenant đang dùng.

### 3.3. Dữ liệu SAP chuẩn và dữ liệu custom

| Loại dữ liệu | Nguồn ưu tiên | Điều phải kiểm tra trước khi code |
| --- | --- | --- |
| Nhà máy | `I_Plant` đang dùng trong service | Field mã/tên, release contract và quyền đọc của tenant |
| Work Center | `ZI_MOB_WorkCenter_VH` bọc `I_WorkCenter` hiện có | Key thật, loại/phiên bản work center, association text/ngôn ngữ released; không đoán join bằng riêng WorkCenter |
| Đơn vị tính | `I_UnitOfMeasure` hiện có | Mã SAP internal đúng cấu hình tenant; không hardcode PC/ST/PCE hoặc conversion exit classic |
| Nhân công | `ZI_PP_WorkerRef` trên `ZTB_KB_NHANCONG` | Đây là master custom hiện hữu, không giả định WorkerID là SAP Personnel Number |
| Work ID, chức danh, chức năng, mã công đoạn custom, ca | Các bảng/view Z đang có | Không thay bằng danh mục SAP khác chỉ vì giống tên |
| SAPTimeZone, BoPhan, Location, AppModule, ReasonCode | Theo hợp đồng dữ liệu thực sự của repo/tenant | Không tự bịa CDS chuẩn hoặc tập enum; xem quyết định cụ thể bên dưới |

Nguồn SAP công khai giúp chọn pattern; không chứng minh một CDS/annotation được released trên tenant cụ thể. Nếu thiếu API released, chỉ dừng hạng mục phụ thuộc đó, ghi rõ blocker; không truy cập bảng SAP chưa released để lách.

## 4. Ma trận coverage theo màn hình

Các tên object trong bảng là object đang có. Hoàn thiện DDLS và DDLX tương ứng, cùng service ở mục 5; không chỉ sửa một phía.

| Entity / nơi dùng | Value help và text cần đạt | Metadata/UX cần đạt |
| --- | --- | --- |
| AUTH `ZC_MOB_User_Adm` / Accounts | WorkerID: giữ VH hiện có cho tạo, hỗ trợ lọc nhân công lịch sử bằng provider không loại bản hết hiệu lực; Status có code/text đúng trạng thái tài khoản thực tế | Username, FullName, WorkerID, Status là filter chính; email/lock time là filter bổ sung; facet thông tin + chức danh + audit; UUID/ETag ẩn khỏi bố cục chính |
| ROLE `ZC_MOB_UsrRol_Adm` / UserRoles | RoleID → `ZI_MOB_Role_VH`, gán mới chỉ role A; text từ RoleName/RoleStatus đã có vẫn hiện khi role cũ bị ngừng | Mã + tên + trạng thái, identification để vào dòng con; UserUUID không cho nhập lại |
| ROLE `ZC_MOB_Role_Adm` / Roles | Status A/I: mã + diễn giải. RoleID khi tạo master vẫn nhập mã mới, không ép chọn role đã tồn tại | Giữ đủ 3 facet General/Functions/WorkAssignments; search RoleID/RoleName; audit tách khỏi cột chính |
| ROLE `ZC_MOB_RolFunc_Adm` / RoleFunctions | FuncID → `ZI_MOB_Func_VH`; text FuncName; AppModule hiển thị rõ | Thêm facet/identification dòng con; field dẫn xuất không được ghi ngược xuống master; parent RoleID ẩn |
| WC `ZC_MOB_RolWork_Adm`, MDE trong ROLE / RoleWorkContexts | WorkID → `ZI_MOB_Work_VH` đang có; active-only khi gán mới; WorkName/Plant/WorkCenter/BoPhan/Location từ association hiện tại | Khôi phục cột và Object Page dòng con; label Work ID giữ nguyên; không cho sửa thông tin master ở dòng gán |
| ROLE `ZC_MOB_Func_Adm` / Functions | FuncID/FuncName có search; AppModule hỗ trợ gợi ý từ các module đang tồn tại nhưng cho phép nhập module mới nếu backend vẫn cho phép | Sửa header FuncId → FuncID; filter mã/tên/phân hệ; không ép FuncID chọn mã có sẵn khi tạo |
| WC `ZC_MOB_Work_Adm` / WorkContexts | Plant → I_Plant; WorkCenter → wrapper lọc Plant; IsActive A/I có text; WorkID filter có trợ giúp tra master gồm cả inactive nhưng create vẫn nhập mới | Nhãn thống nhất, đủ 7 field nghiệp vụ; Plant chọn trước WorkCenter; đổi Plant không được để lưu WorkCenter sai cặp |
| CD `ZC_MD_CongDoan_Adm` / CongDoans | MaCongDoan filter có gợi ý mọi phiên bản; create vẫn cho nhập mã mới; BoPhan gợi ý giá trị custom, không khóa danh mục | Filter mã/tên/bộ phận/hiệu lực; cả ValidFrom key và ValidTo rõ ràng; label DonGiaXM/DonGiaGC, audit đầy đủ |
| ROOT `ZC_PP_OpAlloc_Adm` / OperationAllocations | Khôi phục Plant/WorkCenter/UoM; MaCongDoan filter dùng danh mục lịch sử; ProductionOrder → dữ liệu phân bổ hiện có; Operation phụ thuộc ProductionOrder | Khôi phục filter đã mất; facet thông tin/sản lượng/audit; action correctConfirm được giữ nguyên; OperationUUID không chiếm cột chính |
| ROOT `ZC_PP_AllocTxn_Adm` / AllocationTransactions | F4 WorkerID/FromWorkerID/ToWorkerID cùng nguồn lịch sử; Plant/WorkCenter/MaCongDoan; ShiftID có Plant; TransactionType/OriginalTransactionType/TransactionStatus/SourceChannel có mã + text | Filter chính WorkDate, Plant, ProductionOrder, WorkerID, ShiftID, TransactionType; ExecutionDate là ngày thực hiện, không đổi nhãn thành ngày làm việc; facet nghiệp vụ/nhân công/ca/lý do/audit |
| ROOT `ZC_PP_Shift_Adm` / Shifts | Plant giữ VH; ShiftID filter có nguồn mọi phiên bản và Plant, IsActive có text A/I; không bắt dùng ca active cho xem lịch sử | Đủ 10 field Plant/ShiftID/ValidFrom/ShiftName/StartTime/EndTime/EndDayOffset/SAPTimeZone/ValidTo/IsActive; managed create/update, không hard-delete, UI service riêng |

Quy tắc để xử lý một property vừa là filter vừa là field tạo master: dùng help để gợi ý, không dùng validation bắt mã mới phải tồn tại trong chính danh mục. Nếu UI release không tách được hành vi mong muốn, giữ nhập tự do và filter mã/tên thay vì chặn tạo mới. Đánh dấu ngoại lệ trong coverage và nghiệm thu riêng.

### 4.1. Nhóm field không cần ép value help

- Tên, email, mật khẩu, số lượng/đơn giá, nội dung lý do: nhập theo kiểu field và validator. Mật khẩu không search, không lineItem, không đưa vào provider hay log.
- Date/time dùng control tương ứng; EndDayOffset hiển thị 0 = cùng ngày, 1 = ngày kế tiếp, không chuyển schema sang boolean.
- Technical UUID, sync/session/device ID, timestamp audit: label rõ, chi tiết khi cần, không tạo dropdown tải toàn bộ ledger/user/session.
- ReasonCode hiện action chỉ yêu cầu có giá trị, chưa có master lý do. Có thể gợi ý mã đã dùng trong filter; không áp enum bắt buộc mới ở action. ReasonText luôn nhập tự do.
- BoPhan/Location/AppModule chưa chứng minh là danh mục chuẩn đóng. Gợi ý từ bảng master phù hợp, cho nhập mới; không thêm bảng cấu hình chỉ để có F4.
- SAPTimeZone trên màn ca là field cấu hình; value help timezone chuẩn chỉ là hạng mục sau nếu mở hỗ trợ chọn trực tiếp, cần xác minh API khi đó.

### 4.2. Dialog action phải nằm trong coverage

| Action / abstract entity | Việc cần làm | Ràng buộc không được thay đổi |
| --- | --- | --- |
| `createUser` / AUTH `ZA_MOB_CreateUser` | Nhãn đủ Username/Password/FullName/Email/WorkerID/RoleID; Worker VH và Role VH hoạt động trong popup; password masked theo khả năng annotation/UI5 đã kiểm tra | Giữ RoleID tùy chọn, WorkerID char(8); không tự đổi FullName/Email khi chọn worker; không dùng masked UI thay cho bảo mật backend |
| `changePasswordAdmin` / AUTH `ZA_MOB_CHANGEPWD_ADMIN` | Nhãn action và NewPassword tiếng Việt, password field không hiện rõ | Giữ signature và policy mật khẩu |
| `unlockUser` | Label rõ ở list/object page phù hợp; test select record/action visibility | Không bỏ kiểm tra quyền, không thêm tham số |
| `correctConfirm` / ROOT `ZA_PP_CorrectConfirm` | Label 5 field; TransactionUUID có popup giao dịch xác nhận; hiển thị order/operation/worker/qty/UoM/WorkDate/ShiftID để chọn; chọn dòng trả UnitOfMeasure nếu được hỗ trợ | Chỉ CONFIRM/POSTED chưa reverse; phải thuộc operation đang chọn. NewQuantity là tổng sản lượng mới, không phải delta. ReasonCode/ReasonText vẫn bắt buộc ở backend |

Với correctConfirm: làm PoC nhỏ để kiểm tra truyền context của bound OperationAllocation vào value help. Không tham chiếu `localElement: 'OperationUUID'` trong abstract entity hiện không có field đó. Nếu framework không truyền context được mà không đổi API, fallback được chấp nhận là popup có filter order/operation do người dùng chọn, liệt kê đầy đủ ngữ cảnh và backend từ chối khác operation. Không ship cú pháp giả hoặc thêm required parameter làm vỡ client cũ.

Không mở thêm action mobile ở admin chỉ để tăng số lượng nút. Chỉ cover các action đang expose trong projection BDEF.

## 5. Thiết kế provider và service

### 5.1. Reuse trước, thêm provider chỉ khi semantics khác

1. Giữ `ZI_MOB_Work_VH`, `ZI_MOB_Role_VH` active-only cho gán mới. Thêm text mapping vào Role/Function VH; bổ sung mô tả/cột/filter có ích cho Work VH.
2. Giữ key/contract provider cũ nếu được dùng bởi service mobile. Provider mới phục vụ history không được thay behavior của provider gán mới.
3. Worker history: nguồn `ZI_PP_WorkerRef` không lọc today; giữ định danh bản ghi `WorkerUUID` trong provider mới nếu cần phân biệt các phiên bản, WorkerID là giá trị trả về. Hiển thị Plant/WorkCenter/ValidFrom/ValidTo và tên để giải thích dòng trùng mã. Không lấy tùy ý MAX(WorkerName) để giả lập master duy nhất. Không thêm email/UUID tài khoản nhạy cảm vào popup.
4. Công đoạn history: dùng toàn bộ phiên bản từ `ZI_MD_CongDoan`; giữ MaCongDoan + ValidFrom ở key. Filter chỉ mã có thể áp dụng cho nhiều phiên bản, popup cần thể hiện điều đó. Không dùng `$session.system_date` cho lịch sử.
5. Ca history: reuse `ZI_PP_Shift` với đầy đủ Plant + ShiftID + ValidFrom, không active/today filter. Binding Plant theo #FILTER cho filter bar. Không tự trả ValidFrom vào WorkDate. Khi bổ sung tên ca cho dòng ledger, nối đúng Plant + ShiftID + ShiftValidFrom; legacy thiếu version phải vẫn hiện dữ liệu gốc, không bị inner join làm mất.
6. ProductionOrder/Operation admin: ưu tiên `ztb_pp_op_alloc`/view allocation có sẵn, vì màn này thao tác dữ liệu đã được phân bổ, không phải khám phá mọi lệnh SAP. Provider operation giữ OperationUUID làm định danh và trả Operation theo filter ProductionOrder; kiểm tra nhiều MaCongDoan cho cùng order/operation. Không SELECT DISTINCT trên toàn ledger chỉ để lấy danh sách lệnh.
7. Confirm transaction help: provider admin riêng, key TransactionUUID; prefilter CONFIRM/POSTED và loại đã reverse. Không tính tổng correction cho mọi dòng khi mở F4; chỉ thêm số lượng hiện tại nếu có query được đo và kiểm chứng. Chỉ dùng trường đã có, không sửa ledger.
8. Code list nhỏ: Role/Work A/I, 6 transaction types, POSTED, MOBILE/FIORI/SYSTEM đã xác minh từ validator và `zcl_pp_txn_type`. Account Status phải đọc hết nguồn tạo/khóa/đăng nhập trước khi chốt, không dùng nhầm enum của Role. Nguồn enum phải cung cấp đủ mã ngay cả khi chưa có dữ liệu; không DISTINCT từ bảng giao dịch làm danh mục chuẩn.
9. Nếu repo/tenant không có code-list CDS phù hợp, dùng custom entity read-only nhỏ với query provider từ constant whitelist. Implement filter/count/sort/paging đúng framework và kiểm chứng trong Fiori. Chỉ dùng cho enum nhỏ, không dùng custom query ABAP để tải master/ledger lớn vào memory. Không tạo bảng cấu hình mới trong hạng mục này.

Tên provider mới dự kiến (chưa tồn tại, cần kiểm tra collision trước khi tạo): `ZI_PP_WorkerHist_VH`, `ZI_MD_CongDoanHist_VH`, `ZI_PP_OrderAdm_VH`, `ZI_PP_OperationAdm_VH`, `ZI_PP_CONFIRM_TXN_VH`. Không đổi tên provider hiện hữu. Với master filter gợi ý inactive, chỉ thêm wrapper khi FE không thể reuse entity master an toàn.

### 5.2. Service phải đồng bộ

| Service tại ROOT | Giữ nguyên | Bổ sung khi consumer dùng |
| --- | --- | --- |
| `ZUI_MOB_USER_ADM` | Accounts, UserRoles, RoleValueHelp, WorkerValueHelp | Worker history cho Accounts filter nếu tách được với action; code list tài khoản |
| `ZUI_MOB_RBAC_ADM` | Roles, RoleFunctions, RoleWorkContexts, Functions, WorkContexts và VH hiện có | A/I list, gợi ý module/bộ phận/địa điểm, text provider SAP nếu thật sự có association |
| `ZUI_MD_CONGDOAN_ADM` | CongDoans | Công đoạn lịch sử/gợi ý bộ phận theo annotation thực tế |
| `ZUI_PP_ALLOC_ADM` | OperationAllocations, AllocationTransactions và các alias VH hiện có | Shift history, worker/công đoạn history, order/operation, confirm transaction, code lists |
| `ZUI_PP_SHIFT_ADM` | Shifts, PlantValueHelp, binding `ZUI_PP_SHIFT_ADM_O4` | Shift provider nếu filter cần, code list A/I; tuyệt đối không thêm CRUD |

Không xóa provider cũ chỉ vì consumer vừa đổi sang provider mới trong một màn hình; phải kiểm tra tất cả usages và tương thích service trước. API mobile `ZUI_PP_OPALLOC`, `ZUI_MOB_AUTH` là phạm vi kiểm tra hồi quy, không tự expose thêm danh mục nhạy cảm vào đó.

## 6. Trình tự triển khai

### Giai đoạn 1 — Chốt coverage và khôi phục regression đã biết

Đầu vào: baseline mục 1 và F01–F14. Skill cần dùng: ABAP + CDS + OData; đọc đúng SKILL.md trước khi làm.

1. Kiểm tra HEAD/status và nội dung hiện tại lần nữa. Đọc `git show f5e8c2e:serialized/<object>` rồi đối chiếu DDLS/DDLX mới theo object name, không theo đường dẫn cũ.
2. Lập coverage có một dòng cho mọi property của 11 entity và 3 abstract parameter: label, visible/hidden, list/detail/filter, search, provider, text, usage create/history, service alias, test ID. Unlock không có abstract parameter nhưng có dòng action riêng.
3. Chỉnh F01/F02/F03 có chọn lọc, bỏ duplicate F05, sửa header path F09. Mỗi edit giữ action/binding/key và field nghiệp vụ hiện hữu.
4. Ghi snapshot danh sách entity/key/property/action trong EDMX từ môi trường test nếu có; chưa có tenant thì đánh dấu chưa xác minh, không bịa file metadata.

Đầu ra: patch regression nhỏ, coverage inventory, không di chuyển package. Gate: diff chỉ đúng object dự kiến; lint/pattern/XML/whitespace pass; không mất annotation/action cũ.

### Giai đoạn 2 — Hoàn thiện các provider và hợp đồng tham chiếu

1. Reuse Work/Role/Function VH, sửa WorkCenter label trùng và xác minh text join đúng key/ngôn ngữ.
2. Làm provider history worker/công đoạn và expose shift history; tách rõ active selection với lịch sử.
3. Thêm order/operation/confirm help và code lists theo mục 5, kèm DDLS/XML serializer tương ứng. Không tự tạo baseinfo giả; tuân theo mẫu object hiện hữu/serialize từ ADT.
4. Xác minh released API/annotation trên tenant; dùng một popup PoC cho composite key và một action parameter trước khi nhân rộng.
5. Review quyền đọc provider mới độc lập: không mặc định mọi VH đều `#NOT_REQUIRED`, không giả định DCL của root tự bảo vệ mọi endpoint provider. Dùng cơ chế IAM/DCL phù hợp service đang có.

Gate: provider keys duy nhất theo dữ liệu; không mất lịch sử, không trả sai Plant; DB preview + OData paging không trùng/mất dòng. Provider action không expose dữ liệu ngoài quyền.

### Giai đoạn 3 — Hoàn thiện 11 metadata extension

1. Làm theo thứ tự AUTH/UserRoles → ROLE/RoleFunctions → WC/RoleWorkContexts → CD → PP allocation/ledger → SHIFT.
2. Bổ sung label, header, facet, identification/fieldGroup, cột chính/phụ, filter và search theo ma trận. Giữ UI layout tập trung ở MDE, không để label tiếng Anh trong MDE override nhãn Việt đúng ở DDLS.
3. Nối text cho field đã có mô tả. Text association mới chỉ được thêm khi key đúng và không nhân bản row; không thêm field persist hoặc mapping draft chỉ để có tên hiển thị.
4. Kiểm tra parent keys/computed text readonly; không bật update field do thêm identification. Tách cột audit khỏi list mặc định, không dùng UI.hidden như cơ chế phân quyền.
5. Đưa F4 vào cả filter và nơi nhập phù hợp, giữ free-entry lúc tạo mã master. Không thay đổi boolean/char status type để lấy checkbox.

Gate: 11/11 MDE có coverage rõ cho mọi field; list/detail/bảng con không còn field nghiệp vụ hiện bằng tên kỹ thuật; không có trùng vị trí vô tình trong cùng collection; facet trỏ đúng association đang expose.

### Giai đoạn 4 — Dialog action và kiểm tra metadata xuyên service

1. Hoàn thiện createUser/changePasswordAdmin/correctConfirm và label unlockUser.
2. Giữ annotations của abstract parameters trong DDLS nếu khả năng MDE cho loại entity/release chưa được xác minh; không tạo DDLX không activate được chỉ để “đủ file”.
3. Kiểm tra context binding của correctConfirm theo PoC; dùng fallback được mô tả tại mục 4.2 nếu cần, ghi rõ giới hạn UX.
4. Đồng bộ service definitions; activate provider → consumer CDS/BDEF phụ thuộc → MDE → SRVD → kiểm tra UI binding hiện hữu theo ADT. Với RAP composition có phụ thuộc vòng, activate tập object liên quan cùng nhau, không ép từng file riêng lẻ.
5. Kiểm tra EDMX: Common.ValueList/CollectionPath/Parameters, Common.Text, UI.HeaderInfo/Facets/LineItem/Identification/SelectionFields và action parameter annotations đúng namespace/case.

Gate: mọi provider/field text được tham chiếu có mặt trong service tương ứng; popup chọn trả đúng field; action contract không đổi. Không delete/recreate binding đang triển khai để refresh metadata.

### Giai đoạn 5 — Tối ưu performance trong phạm vi admin

1. Chỉ search mặc định 1–2 field mã/tên có giá trị; thêm field khác khi có nhu cầu và đo được. Không fuzzy search UUID/timestamp/quantity hay bật search toàn ledger/ReasonText mặc định.
2. `$filter`, `$search`, `$select`, `$top`, `$skip` do backend xử lý; không tải toàn bộ master rồi lọc phía ABAP/UI. Không dùng `resultSet.sizeCategory: #XS` cho danh mục lớn để ép dropdown.
3. Provider lấy cột cần cho popup; không SELECT * / expand sâu / tính ledger tổng chỉ để hiển thị text. Join ngôn ngữ và phiên bản phải giữ cardinality thật, không khai `[0..1]` để che dữ liệu nhiều dòng. SAP lưu ý cardinality đúng ảnh hưởng runtime. [SAP: CDS Associations](https://help.sap.com/docs/ABAP_PLATFORM_BW4HANA/9a281eac983f4f688d0deedc96b3c61c/8dca2bef147f490089c5001ee6b4d2de.html)
4. DISTINCT chỉ giữ nơi thực sự cần và giải thích vì sao. Đo query plan trước khi thay DISTINCT hoặc thêm index. Không thêm index/table change trong patch metadata khi chưa có bằng chứng và phê duyệt phạm vi.
5. Refactor ba assignment validators trong F13: READ ENTITIES lấy tập input, deduplicate key trong memory, đọc master theo tập một lần mỗi loại, tra bằng sorted/hashed table, trả failed/reported đúng `%tky`/`%element` từng dòng. Skip DB read nếu tập mã rỗng; giữ điều kiện A cho Role/Work và existence cho Function.
6. Không thay validator này bằng check UI hoặc SELECT SINGLE trong loop; không đổi global auth, transaction boundary hoặc query confirm/reverse ở lượt tối ưu admin.
7. Kiểm tra metadata typeahead sau thay đổi field phụ thuộc; dùng side effects phù hợp nếu tên dẫn xuất không refresh trong draft, không thêm SELECT N+1 để ép cập nhật text.
8. Bổ sung `validateWork` kiểm tra Plant/WorkCenter theo tập cặp mã trên nguồn released đang dùng. Chỉ kiểm tra tham chiếu khi tạo hoặc thay đổi Plant/WorkCenter; việc đổi tên/vô hiệu hóa master cũ không được bị chặn chỉ vì WorkCenter SAP cũ đã ngừng. Kiểm tra này thuộc cấu hình admin Work, không được đưa sang class mock hay sửa chính sách chọn operation của mobile.

Gate performance: ghi số đo trước/sau trên cùng tenant, quyền, bộ lọc và tập dữ liệu; tách cold metadata/cache khỏi warm requests. Dùng Browser Network và công cụ SQL trace được tenant cho phép, không mặc định ST05 có sẵn ở Cloud.

Mẫu workload: mỗi popup 30 lượt đo warm, trang đầu 20 dòng, chuyển trang thứ hai, mã chính xác, tên một phần, không kết quả, đổi Plant; kiểm tra 1 và 50 dòng gán role/work/function bằng dữ liệu test được phép dùng. Mục tiêu đề xuất: warm p95 không tăng quá 10% baseline nếu dao động đo cho phép; validator đọc master không tăng tuyến tính theo số dòng. Chưa có số đo thì ghi “chưa đo”, không khẳng định nhanh hơn.

### Giai đoạn 6 — Regression, tài liệu và bàn giao

1. Chạy gate local và các test tenant ở mục 7; lưu bằng chứng từng màn, không ghi mật khẩu/token/cookie vào repo.
2. Bổ sung check metadata chuyên biệt, ví dụ `scripts/check_admin_metadata.py`, để phát hiện field/target không tồn tại, thiếu provider theo service, nhãn Work ID sai, duplicate annotation trong cùng scope, property path sai case, action annotation trỏ sai BDEF. Không dùng regex đơn giản rồi tuyên bố kiểm chứng toàn bộ cú pháp CDS; EDMX parser trên snapshot test mới là kiểm chứng service thực tế.
3. Nối check vào `scripts/check_ci.sh` sau khi có test fixtures pass/fail. Giữ lint version/config hiện hữu, không tắt rule để qua CI. GitHub push workflow hiện chỉ match main/chatgpt/**; khi dùng codex/**, kiểm tra CI qua pull_request hoặc đề xuất sửa filter trong hạng mục CI riêng.
4. Cập nhật `docs/FIORI_ELEMENTS_ADMIN.md`, `docs/TECHNICAL_DOCUMENTATION.md`, `IMPLEMENTATION_STATUS.md`: mapping 5 service/11 entity, cách chọn/filter, action popup, provider active/history, giới hạn tenant và kết quả thật. Chỉ đánh dấu done phần đã nghiệm thu.
5. Bàn giao source diff theo giai đoạn và danh sách object activate; không tự commit/push/deploy production. Không ghi đè toàn bộ tài liệu kỹ thuật ngoài phần liên quan trong kế hoạch này.

Gate: coverage 100% field classification và mọi test bắt buộc đã pass hoặc được nêu rõ là blocked. “Code xong local” khác “đã nghiệm thu tenant”.

## 7. Ma trận kiểm thử bắt buộc

| ID | Kịch bản | Kết quả yêu cầu |
| --- | --- | --- |
| T01 | Activate DDLS/DDLX/BDEF/SRVD theo dependency; ATC theo Cloud variant tenant | Không duplicate annotation, invalid scope/path, unreleased API hoặc service reference lỗi |
| T02 | 5 admin service trả `$metadata`; so key/type/action/alias baseline | Thay đổi additive có chủ đích, không đổi contract hiện hữu, VH/text provider đầy đủ |
| T03 | Tạo Work ID/RoleID/FuncID/MaCongDoan mới chưa có trong danh mục | Không bị F4 validation chặn vì mã chưa tồn tại; validator nghiệp vụ cũ vẫn chạy |
| T04 | Gán Work ID và FuncID trên Roles, gán RoleID trên Accounts | Popup tìm mã/tên, chọn trả đúng key; text hiện ngay hoặc refresh draft đúng; save/discard không đổi master |
| T05 | Role/Work inactive, record cũ đã được gán | Không chọn để gán mới; bản gán cũ vẫn có text và xem được, không bị mất do join active-only |
| T06 | Hai Plant có cùng WorkCenter; đổi Plant sau khi chọn WC; Plant rỗng | Danh sách/cặp giá trị đúng, không tự chọn dòng tùy ý; không lưu cặp không hợp lệ |
| T07 | WorkerID nhiều placement/phiên bản/tên, hết hiệu lực hiện tại | Không nhầm định danh; gán mới dùng eligibility hiện tại, history vẫn lọc được mã cũ; đọc UoM không lỗi |
| T08 | Mã công đoạn nhiều ValidFrom, ca trùng ShiftID ở hai Plant | Không nhân bản dòng ledger/row count; ngày làm việc không bị gán bằng ValidFrom |
| T09 | Ca 22:00 07/09 → 06:00 08/09, xác nhận 02:00/05:30 ngày 08/09 | Filter WorkDate 07/09 + Plant + ShiftID vẫn thấy đúng; metadata không thay logic resolver |
| T10 | Ledger ca cũ đã inactive; ledger legacy ShiftID/ShiftValidFrom trống | Record vẫn thấy được khi bỏ filter ca; không join loại mất lịch sử, không gán tên phiên bản sai |
| T11 | createUser, changePasswordAdmin, unlockUser | Label rõ; Worker/Role VH có trong popup; password masked nếu release hỗ trợ và không lọt sang list/search/log |
| T12 | correctConfirm chọn CONFIRM hợp lệ, đã reverse, khác operation, UoM sai | Popup phù hợp; backend giữ đầy đủ check. NewQuantity là tổng mới; ReasonCode/ReasonText không bị mất |
| T13 | 50 dòng gán, key trùng trong request, tập rỗng, mã không tồn tại | Validator bảo toàn failed/reported và active rules, không SELECT theo từng dòng |
| T14 | User không có quyền gọi trực tiếp endpoint VH/action | Không lộ dữ liệu vượt phạm vi, UI.hidden không được tính là authorization |
| T15 | `$search`, `$filter`, `$top/$skip`, sort, count, tiếng Việt; master rỗng | Không dump, không trùng/mất trang; code lists đóng vẫn đủ giá trị; gợi ý mở vẫn cho nhập tự do |
| T16 | Basic search và filter từng màn; Object Page/bảng con; variant cũ | Field order/nhãn đúng; facet hoạt động; không mất action/navigation hoặc lỗi variant do đổi alias |
| T17 | Mobile getWorkHistory/submit và báo cáo trước/sau patch | Không đổi payload/action contract, số dư/ledger, nguyên tắc manager 67310035 không thành worker HD000001 |
| T18 | Ghi lại p50/p95, payload bytes, request count, DB reads trước/sau | Có bằng chứng performance; không ghi “tối ưu xong” nếu chỉ thay annotation |

Gate local tối thiểu mỗi giai đoạn:

```powershell
npx --yes @abaplint/cli@2.120.35
python scripts/check_rap_patterns.py
git diff --check
```

Chạy thêm XML parse cho file serializer thay đổi và check metadata mới khi đã triển khai. Trên CI Linux chạy `bash scripts/check_ci.sh`. ABAP Unit dành cho query provider/validator phải chạy trong SAP; Python static checks không thay được ABAP Unit hoặc ATC.

## 8. Hướng dẫn ngắn cho agent code tiếp

1. Đọc tài liệu này và skills ABAP/CDS/OData. Đọc RAP/ABAP Unit skill khi sửa validator hoặc thêm query provider/test.
2. Xác minh baseline và dirty diff. Bắt đầu Giai đoạn 1, không triển khai đồng loạt tất cả object bằng tìm/thay thế.
3. Mỗi field phải có provider/key/text/service và policy create/history rõ, hoặc lý do không dùng VH. Không thêm field vào bảng chỉ để UI có tên.
4. Không đổi label Work ID, không merge service ca, không sửa nghiệp vụ ca/ledger, không đổi key provider cũ, không tắt authorization/lint.
5. Chưa có access tenant: vẫn code/kiểm tra local được các phần chắc chắn; báo riêng gate activation/EDMX/performance còn chờ. Không khẳng định “không lỗi SAP” từ lint.
6. Kết thúc mỗi giai đoạn báo: file đã sửa, hành vi thay đổi, test đã chạy, phần chưa kiểm chứng và bước tiếp theo. Nếu cần thay API/schema mới đạt UX, dừng đúng hạng mục đó và xin quyết định, không tự mở rộng phạm vi.
