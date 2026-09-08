# Kế hoạch sửa backend sau khi chuyển package dành cho Luna 5.6

## 1. Phạm vi và mốc đối chiếu

- Repository: abap_casla_app_mobile.
- Đã pull fast-forward ngày 08/09/2026: main từ f5e8c2e lên 4c1c114 (change package).
- Mốc trước thay đổi: f5e8c2e. Mốc đầu vào kế hoạch: 4c1c114.
- Mục tiêu: giữ cấu trúc package mới, sửa regression nghiệp vụ và khôi phục contract đã thống nhất.
- Kế hoạch chia theo dependency và cổng nghiệm thu, không theo ngày.
- Tài liệu này bắt đầu là handoff triển khai; các mục F01–F13 đã được áp dụng trong working tree và đã có kết quả kiểm tra ở mục 11.
- f5e8c2e là nguồn so sánh, không phải bản tuyệt đối đúng. Không restore toàn repository hoặc chép đè toàn handler từ commit này.
- Nếu HEAD đã đổi khi Luna bắt đầu, đọc delta từ 4c1c114 đến HEAD trước khi áp dụng plan. Giữ thay đổi người dùng.

Lệnh đối chiếu:

~~~powershell
git status --short
git log f5e8c2e..HEAD --oneline
git diff --find-renames f5e8c2e...4c1c114 -- serialized
git show f5e8c2e:serialized/zbp_r_pp_opalloc.clas.locals_imp.abap
~~~

Các đường dẫn bên dưới tương đối với root repository. Tên object SAP phải giữ nguyên khi di chuyển file.

## 2. Quy tắc nghiệp vụ bắt buộc

1. Manager 67310035 là actor giao việc; nhân công HD000001 là người nhận trong demo. Không tự tạo balance cho manager.
2. Ledger append-only; confirm ghi số lượng, CORRECTION ghi delta có dấu, REVERSE ghi số lượng hiệu lực cần đảo. Không sửa/xóa receipt gốc.
3. Remaining = InitialAssigned + TransferredIn - TransferredOut - Recalled - Completed; balance theo worker–operation, xuyên ca.
4. Ca 22:00 ngày 07/09 đến 06:00 ngày 08/09: 23:00, 02:00 và 05:30 thuộc WorkDate 07/09. Biên đầu có bao gồm, biên cuối loại trừ.
5. Offline dùng thời điểm thực hiện UTC, chuyển theo múi giờ SAP của nhà máy; không lấy giờ nhận request để xác định ca.
6. Reverse/correction kế thừa ngày và snapshot ca của CONFIRM gốc. CreatedAt phản ánh thời điểm ghi điều chỉnh.
7. Retry dùng SyncItemUUID ổn định. Cùng key khác payload phải bị từ chối; cùng key đúng payload không thêm receipt.
8. Xác thực token/device/function/work scope/worker không được bỏ qua để làm demo chạy.
9. Operation control profile đọc cấu hình PP_OPERATION_CONTROL_PROFILE. Không hardcode YBP1 cho mọi tenant.
10. Ca có service Fiori riêng ZUI_PP_SHIFT_ADM / ZUI_PP_SHIFT_ADM_O4, main entity Shifts, chỉ đọc. Giữ expose phụ trợ trong service khác để value help không hỏng.
11. Bảng/cột đã triển khai phải được nâng cấp giữ dữ liệu. Không giải quyết activation bằng xóa bảng.
12. Không gọi standard SAP confirmation API; nghiệp vụ hiện tại là ledger CASLA.

## 3. Findings đã xác nhận và điều cần kiểm tra thêm

| ID | Mức | Bằng chứng tại 4c1c114 | Tác động |
| --- | --- | --- | --- |
| F01 | P1 | scripts/check_rap_patterns.py đọc serialized/zi_mob_user.bdef.asbdef; file đã chuyển vào package AUTH | Chạy script thực tế lỗi FileNotFoundError trước bước lint |
| F02 | P1 | Test include của zcl_mob_hasher và zcl_mob_token_validator ở root, class/XML ở AUTH | Bộ file serialize của class bị chia thư mục, cần ghép lại để import/test nhất quán |
| F03 | P1 | ZTB_PP_ALLOC_TXN mất 7 field ca; root CDS/BDEF/abstract input/result cũng bị bỏ field; resolver vẫn còn | Source phụ thuộc cấu trúc đã bị mất; ca không còn hoạt động xuyên suốt |
| F04 | P1 | initialAssign/transfer/recall/confirm mất resolve ca, EML snapshot và so sánh shift/timestamp khi retry | Ngày ca và retry không còn theo contract |
| F05 | P1 | reverse/correctConfirm đổi ExecutionDate sang ngày hệ thống, bỏ snapshot gốc | Điều chỉnh hôm sau lệch báo cáo ca gốc |
| F06 | P1 | zcl_pp_work_history mất expand_roots, cộng CORRECTION và filter WorkDate/ShiftID | Team bỏ sót giao dịch dẫn xuất, tổng completed sai |
| F07 | P1 | unique_workers dùng VALUE vào sorted table unique key từ summary theo worker+UoM | Một worker có nhiều UoM có thể phát sinh duplicate-key exception |
| F08 | P1 | zcl_pp_operation_guard kiểm tra OperationControlProfile <> 'YBP1' | Bỏ cơ chế cấu hình đã chấp thuận |
| F09 | P1 | AUTH/zcl_mob_config chứa literal cho PASSWORD_PEPPER và TOKEN_SECRET, dùng MODIFY cấu hình | Rủi ro ghi đè secret hiện hữu; không sao chép giá trị vào docs/log |
| F10 | P2 | password predicate tối thiểu 6 ký tự nhưng create/change message nói 12 và có hoa/thường/số | UI mô tả sai điều kiện; password_upper không dùng |
| F11 | P2 | Nhiều label, text association, value help bị mất trong CDS/MDE | Fiori và action input mất trải nghiệm đã bổ sung |
| F12 | P1 | History test vẫn gọi root_keys/txn_links/expand_roots đã mất; XML class mất WITH_UNIT_TESTS | Test và implementation lệch nhau |
| F13 | P2 | Admin password reset đọc updated_users với comment result $self, nhưng BDEF action không có result | Code thừa/ý định chưa thống nhất; giữ contract hiện có và dùng reported/side effect phù hợp |

Không kết luận mọi thay đổi authorization callback là lỗ hổng chỉ vì chuyển sang gán auth-allowed trực tiếp: baseline cũng có cơ chế này. Cần kiểm tra service/projection, DCL và IAM thực tế.

Những thay đổi mới phải giữ và hoàn thiện:
- Các subpackage AUTH, ROLE, WC, CD và FOLDER_LOGIC FULL.
- ZAPI_PP_OPALLOC, service authorization descriptor và communication scenario ZCS_MOBILE_XNSL mới.
- Login trả FullName/Email/WorkerID. Kiểm tra refresh để cùng result contract trả giá trị nhất quán.
- forward_action_failure và thông báo UNIT_OF_MEASURE_MISMATCH rõ ràng. Không làm mất khi khôi phục ca.

## 4. Giai đoạn 1 — Chuẩn hóa package và đường kiểm tra

### File và việc cần làm

- .abapgit.xml; serialized/package.devc.xml; package.devc.xml trong bốn subpackage.
- scripts/check_rap_patterns.py; scripts/check_ci.sh; .github/workflows/abaplint.yml; abaplint.json.
- Bộ file của zcl_mob_hasher, zcl_mob_token_validator; rà toàn bộ class/CDS/BDEF/DCL/MDE.

1. Lập object manifest: object name, type, các file liên quan, thư mục sở hữu.
2. AUTH chứa identity/credential/session; ROLE chứa role/function/mapping liên quan; WC chứa work context/worker reference; CD chứa master công đoạn. Giữ PP và shift tại root như commit hiện tại, trừ khi manifest chỉ ra lỗi cụ thể.
3. Di chuyển hai test include auth về cùng thư mục class. Không tạo class bản sao ở root.
4. Phân biệt companion cùng object và object khác type: DCL/MDE có thể cùng tên CDS nhưng là object riêng. Không tự động gom mọi file cùng stem nếu chưa đối chiếu package ownership.
5. Thay path hardcode của script bằng resolver tìm đệ quy theo filename. Không có hoặc nhiều hơn một kết quả phải báo lỗi rõ, không chọn file đầu tiên tùy ý.
6. Đổi glob kiểm tra MDE sang recursive; chấp nhận UTF-8 BOM khi đọc export.
7. abaplint đã dùng /serialized/**/*.*; giữ phạm vi đó. Không exclude package/test để làm CI xanh.
8. Kiểm tra trigger workflow với branch sửa codex/...; PR đã được hỗ trợ, thêm push codex/** nếu cần chạy trực tiếp trên branch sửa.
9. Chạy check để ghi baseline lỗi còn lại. Giai đoạn này chưa yêu cầu lint sạch khi F03/F12 chưa được sửa.

### Nghiệm thu

- Mỗi object có chủ sở hữu rõ, không có source orphan hoặc file trùng identity.
- Script hết FileNotFoundError và thực sự quét package con.
- Test include import cùng class.
- Chỉ thay cấu trúc/kiểm tra ở giai đoạn này, không thay công thức sản lượng.

## 5. Giai đoạn 2 — Cấu hình và authentication

### File

- serialized/zpk_xnsl_sm_backend_auth/zcl_mob_config.clas.abap
- serialized/zpk_xnsl_sm_backend_auth/zbp_i_mob_user.clas.locals_imp.abap
- serialized/zpk_xnsl_sm_backend_auth/za_mob_loginresult.ddls.asddls
- AUTH/za_mob_changepwd_admin.ddls.asddls và zi_mob_user.bdef.asbdef
- Các class hash/config/token validator và test include tương ứng.

### Thực hiện

1. Loại literal secret khỏi source, dùng input cấu hình an toàn theo khả năng tenant. Chạy mặc định thiếu input phải không ghi DB.
2. Bootstrap chỉ insert key còn thiếu; key đã tồn tại không bị overwrite tự động. Không chạy class setup vào tenant trong bước sửa source.
3. Nếu tenant đã dùng literal trong Git: ghi task vận hành thay secret có kiểm soát. Đổi pepper có thể làm password hash cũ không còn verify được; phải chuẩn bị migration/reset password. Không tự rotate trong lần sửa này và không tự rewrite lịch sử Git.
4. Giữ policy đã thống nhất: tối thiểu 6 ký tự, không chứa username; đổi mật khẩu self phải khác mật khẩu cũ. Đồng bộ predicate/message; bỏ biến password_upper thừa.
5. Giữ các field profile mới trong LoginResult, đọc và map nhất quán ở login và refresh. Không expose credential hoặc secret.
6. Giữ revoke session, lockout, token rotation. Nếu tách lại helper revoke_login_sessions để đáp ứng độ dài method, chứng minh behavior không đổi.
7. changePasswordAdmin hiện không có result: loại read-back thừa hoặc sử dụng đúng yêu cầu UI với contract rõ ràng. Không tự thêm result $self ở một phía mà quên BDEF/projection/metadata.
8. Rà permission đường mobile/admin; giữ current status và password-change-required rules.

### Nghiệm thu

- Default setup không overwrite PASSWORD_PEPPER/TOKEN_SECRET.
- Login và refresh có cùng field profile đúng user.
- Password 6 ký tự hợp lệ theo predicate không bị UI báo policy 12.
- Password reset revoke session; login/refresh/permission tests còn hoạt động sau chuyển package.

## 6. Giai đoạn 3 — Khôi phục contract ca và transaction command

### File

- serialized/ztb_pp_alloc_txn.tabl.xml
- serialized/zr_pp_alloctxn.ddls.asddls; zr_pp_opalloc.bdef.asbdef
- serialized/za_pp_initialassign.ddls.asddls; za_pp_transfer.ddls.asddls
- serialized/za_pp_recall.ddls.asddls; za_pp_confirm.ddls.asddls
- serialized/za_pp_histquery.ddls.asddls; za_pp_histentry.ddls.asddls
- serialized/za_pp_syncstatusresult.ddls.asddls
- serialized/zc_pp_alloctxn_adm.ddls.asddls
- serialized/zcl_pp_shift_resolver.clas.abap và test
- serialized/zbp_r_pp_opalloc.clas.locals_imp.abap
- serialized/zcl_pp_operation_guard.clas.abap

### Thứ tự sửa

1. Khôi phục đủ SHIFT_ID, WORK_DATE, EXECUTED_AT, SHIFT_START_AT, SHIFT_END_AT, SHIFT_TIME_ZONE, SHIFT_VALID_FROM trong DDIC → CDS → BDEF readonly/mapping → projection/result.
2. Khôi phục ShiftID/ExecutedAt ở bốn input command; ShiftID ở history filter.
3. Rà resolver hiện hữu trước khi tái sử dụng: timestamp UTC, timezone SAP, hiệu lực theo ngày bắt đầu ca, đúng một cấu hình, xử lý biên [start,end), tương lai và config overlap.
4. Trong từng handler: validate session + operation → resolve shift → normalize ExecutionDate → validate worker theo ngày đó → kiểm tra receipt/balance → EML update + append.
5. Giữ nhánh legacy: cả hai field mới initial thì yêu cầu ExecutionDate; chỉ một field mới thì reject. Không dùng upload timestamp làm fallback.
6. EML CREATE BY _Transactions phải khai báo và gán đủ bảy field. Chỉ thêm cột DDIC hoặc CDS là chưa hoàn tất.
7. Idempotency so sánh shift/timestamp cùng payload nghiệp vụ. Replay hợp lệ dùng snapshot đã lưu, không tính lại theo config mới. Check duplicate/cross-actor key phải fail closed, không để lộ receipt khác actor.
8. Reverse/correctConfirm đọc snapshot từ CONFIRM gốc rồi copy toàn bộ; ExecutionDate kế thừa gốc, CreatedAt mới.
9. getSyncStatus trả đủ snapshot với kiểm tra actor. Legacy cần định nghĩa WorkDate fallback nhất quán với history, không giả timestamp.
10. Khôi phục PP_OPERATION_CONTROL_PROFILE: thiếu config cho phép profile không rỗng; config active có value thì yêu cầu khớp. Giữ REL/TECO/CLSD/DLFL và WorkCenter validation.
11. Giữ forward_action_failure; áp dụng mapping instance %tky sang static %cid cho năm submit facade khi phù hợp. Giữ chi tiết lỗi, không forward nhầm lỗi item khác.
12. Không COMMIT WORK trong RAP handler. Balance và ledger cùng LUW; receipt trong buffer đọc EML.

### Nghiệm thu

- Ca NIGHT 23:00 / 02:00 / 05:30 có WorkDate 07/09; 06:00 bị loại khỏi NIGHT.
- Date payload sai, chỉ một field, config chồng lấn hoặc timestamp tương lai bị từ chối.
- Retry cùng key giữ một receipt; đổi shift/time với cùng key bị từ chối.
- Correction ngày hôm sau vẫn ở ca CONFIRM gốc.
- Config không ép YBP1 khi không có rule đó; không bỏ operation guard.
- Legacy row giữ nguyên dữ liệu, không xóa bảng để activate.

## 7. Giai đoạn 4 — History và tính nhất quán số liệu

### File

- serialized/zcl_pp_work_history.clas.abap
- serialized/zcl_pp_work_history.clas.xml
- serialized/zcl_pp_work_history.clas.testclasses.abap
- getWorkHistory trong serialized/zbp_r_pp_opalloc.clas.locals_imp.abap
- ZA_PP_HistQuery/HistEntry/HistResult/HistWorker và các CDS ledger liên quan.

### Thực hiện

1. Khôi phục field/type/signature shift và mapping trả kết quả.
2. Filter bằng WorkDate, fallback ExecutionDate cho row legacy; filter ShiftID khi có.
3. Team scope bắt đầu từ assignment/transfer do actor tạo, mở rộng theo OriginalTransactionUUID và worker, bao gồm correction/reverse nhiều cấp. Chống vòng lặp và không mở rộng sang booking manager khác.
4. Khôi phục CORRECTION cộng delta vào completed; REVERSE trừ effective quantity.
5. Thay VALUE vào sorted unique worker table bằng insert/deduplicate an toàn. Summary vẫn theo worker+UoM, WorkerCount theo worker duy nhất.
6. Khôi phục metadata test WITH_UNIT_TESTS và các helper/type mà test đang dùng, hoặc sửa test phù hợp interface mới nhưng giữ cùng behavior assertion.
7. Giữ quyền self/team, cap scan 20.000, cap entries 1.000 và IsTruncated. Không quảng bá cap như pagination đầy đủ; đọc team hiện có giới hạn trước sort, ghi rõ nếu chưa bảo đảm newest toàn bộ.
8. RECALL giảm assigned trong summary để `Remaining` khớp balance theo worker–operation; giữ ledger append-only.
9. Range D vẫn là ngày hệ thống; app xem ca đêm dùng C và WorkDate. Không đổi mặc định range trong đợt sửa này.

### Bộ dữ liệu nghiệm thu

| Kịch bản | Kết quả mong đợi |
| --- | --- |
| Assign 100 → confirm 25 | Balance còn 75 |
| Correct 25 thành 35 | Ledger correction +10; completed 35, remaining 65 |
| Reverse sau correction | Reverse 35; completed 0, remaining 100 |
| Chuỗi assignment → confirm → correction → reverse, child đọc trước parent | Team vẫn thấy chuỗi hợp lệ |
| Manager khác giao cùng worker/operation | Không lọt vào scope team actor hiện tại |
| Một worker có ST và KG | Hai summary, WorkerCount=1, không duplicate-key exception |
| Row legacy và row có ca trong cùng khoảng | WorkDate fallback đúng; filter ca không gán ca cho legacy |
| Giao ca trước, confirm ca sau | Balance đúng; summary kỳ có thể âm và được mô tả đúng |

## 8. Giai đoạn 5 — Metadata, Fiori và service

### File

- Tất cả *.ddls.asddls và *.ddlx.asddlxs bị đổi trong root/AUTH/ROLE/WC/CD.
- serialized/zc_pp_shift_adm.*; zui_pp_shift_adm.*; zui_pp_shift_adm_o4.srvb.xml.
- ZUI_MOB_AUTH, ZUI_PP_OPALLOC, ZUI_PP_ALLOC_ADM và service admin.
- ZAPI_PP_OPALLOC cùng authorization descriptor và ZCS_MOBILE_XNSL mới.

### Thực hiện

1. Đối chiếu annotation với baseline theo object identity, không theo path cũ.
2. Khôi phục label tiếng Việt, text/value help cần thiết; WorkID giữ label chính xác 'Work ID'.
3. Work/Role/Function/Worker/Plant/WorkCenter/UoM phải trỏ đúng value-help view được expose trong service sử dụng.
4. Khôi phục metadata ledger WorkDate/ShiftID/ExecutedAt và action correction.
5. Shift value help có Plant/validity: kiểm tra binding theo context khi consumer có Plant, tránh chọn ca nhầm nhà máy; backend vẫn validate.
6. Giữ service ca riêng chỉ GET. Không thêm CRUD ca trong phạm vi sửa regression.
7. Giữ metadata profile login mới và communication object mới; xác nhận service name/version/reference nhất quán.
8. Kiểm tra activation CDS annotation theo tenant; không bỏ annotation hàng loạt chỉ để qua lint.
9. DCL/IAM: không đổi #MANDATORY thành #NOT_REQUIRED để tránh lỗi activation. Rà role gán entity, catalog/service authorization theo package.
10. Dùng $metadata tenant để xác nhận qualified action URL. getWorkHistory là static collection-bound action; không tài liệu hóa URL có operation instance key.

### Nghiệm thu

- Fiori app ca chọn ZUI_PP_SHIFT_ADM → Shifts và thấy danh sách/filter/detail.
- Value help phục vụ create/edit/filter trong các app admin.
- Mobile chỉ expose facade; correction chỉ ở admin.
- Không mất endpoint/binding mới sau sửa.

## 9. Giai đoạn 6 — Kiểm thử tổng, tài liệu và bàn giao activate

### Kiểm tra local

~~~powershell
python scripts/check_rap_patterns.py
git diff --check
~~~

Trong shell hỗ trợ CI:

~~~bash
bash scripts/check_ci.sh
~~~

- Lint đúng phiên bản 2.120.35 và toàn cây serialized.
- Parse XML, kiểm tra manifest companion, reference service/CDS, test discovery.
- Không giảm rule, loại test, tắt check_ddic hoặc tăng threshold chỉ để che lỗi.
- Nếu không tải được dependency thì báo riêng lỗi hạ tầng; không ghi là lint đã pass.

### Kiểm thử SAP

- Activate graph DDIC → CDS/abstract entities → behavior/classes → projections/MDE → service/binding (activate nhóm phụ thuộc lẫn nhau khi ADT yêu cầu).
- Chạy ABAP Unit cho auth hash/token, resolver và history.
- Thử login/refresh/reset/revoke; giao/chuyển/thu hồi/confirm/correct/reverse.
- Thử hai request cạnh tranh cùng balance và cùng sync key: không double count; rollback không để orphan receipt/balance.
- Thử timeout sau commit và getSyncStatus.
- Thử operation không REL, inactive user/role, sai worker/password/work scope.
- Record rõ tenant-only tests chưa chạy. Lint không thay cho activation/ABAP Unit.

### Tài liệu cần đồng bộ

README.md, IMPLEMENTATION_STATUS.md, docs/TECHNICAL_DOCUMENTATION.md,
docs/WORKING_SHIFTS.md, docs/FIORI_ELEMENTS_ADMIN.md, docs/METADATA_UX_AUDIT.md,
docs/PP_DEMO_DATA_QUERIES.md và bản Word liên quan.

Sửa các sai lệch tài liệu đã thấy:
- Code source sau đổi package phải được link đúng.
- ZAPI_PP_OPALLOC hiện có trong repo.
- CORRECTION lưu delta; không viết rằng Quantity chứa số lượng mới tuyệt đối.
- URL getWorkHistory không có instance key.
- Profile login/refresh và policy password khớp implementation.
- Tách kết quả local test, tenant activation và test runtime; không tuyên bố coverage đầy đủ bằng số lượng heading.

### Đầu ra bắt buộc của Luna

- Diff theo giai đoạn, danh sách file và lý do.
- Bảng F01–F13: fixed / verified / pending tenant với bằng chứng.
- Kết quả kiểm tra thực tế và test cases chưa chạy.
- Danh sách object activate theo package, thay đổi metadata app cần nhận.
- Mô tả migration giữ dữ liệu cũ; không delete table, không tự backfill ca.
- Không push/deploy/rotate secret trừ khi người dùng yêu cầu.

## 10. Prompt thực thi để giao Luna 5.6

~~~text
Đọc docs/LUNA_56_PACKAGE_REMEDIATION_PLAN.md và triển khai tuần tự giai đoạn 1–6.
Mốc đầu vào đã review là 4c1c114, baseline so sánh f5e8c2e.
Nếu HEAD khác, rà delta mới trước; giữ thay đổi người dùng.
Giữ package AUTH/ROLE/WC/CD hiện tại và các service/communication object mới.
Không restore toàn bộ file từ baseline: khôi phục từng rule, giữ profile login mới,
forward_action_failure và lỗi UoM chi tiết.
Ưu tiên sửa manifest/CI, cấu hình/auth, rồi contract ca + command, history, metadata.
Với mỗi giai đoạn: đọc đúng file, sửa, chạy check phù hợp, ghi kết quả/gap;
không dừng xin xác nhận giữa các giai đoạn nếu vẫn trong scope.
Không làm mất dữ liệu, bỏ validation, thay policy hoặc mở thêm CRUD.
Không che lỗi bằng tắt lint/test. Không tự push hoặc deploy.
Cuối cùng báo mapping F01–F13, tests thực sự đã chạy và việc cần làm trong ADT.
~~~

## 11. Trạng thái triển khai

- Đã pull fast-forward lên `4c1c114`; giữ nguyên cấu trúc package AUTH/ROLE/WC/CD.
- F01–F13 đã được xử lý ở source hoặc metadata tương ứng; các kiểm tra tenant/ADT vẫn là pending.
- `python scripts/check_rap_patterns.py`: PASS.
- Comment rule cho CDS/BDEF/service definition: PASS.
- Parse toàn bộ XML trong `serialized/`: PASS.
- `npx --yes @abaplint/cli@2.120.35`: PASS, 0 issue, 351 file.
- `bash scripts/check_ci.sh` chưa chạy được vì môi trường Windows hiện không có Bash; các bước tương đương đã chạy thủ công.
- Chưa chạy ABAP Unit, activation, publish binding hoặc API runtime trên tenant SAP.
- Chưa chạy `zcl_pp_shift_setup`; không tự backfill ca và không ghi đè secret/cấu hình hiện hữu.
