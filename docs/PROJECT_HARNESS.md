# Harness dự án CASLA (backend ABAP + app Flutter)

Khung làm việc cho mọi phiên sửa code (người hoặc agent): quy tắc bất biến,
bản đồ các phần ràng buộc lẫn nhau, checklist theo vùng, nợ kỹ thuật còn mở.
`CLAUDE.md` ở gốc mỗi repo là bản rút gọn, trỏ về đây. Chỉ ghi quy tắc đang
có hiệu lực; lịch sử quyết định nằm trong git log.

## 1. Hai repo, một luồng làm việc

| Repo | Đường dẫn | Vai trò |
| --- | --- | --- |
| ABAP | `G:\Android\abap_casla_app_mobile` | RAP BO, CDS, job, Fiori admin (`serialized/`), docs, guard scripts |
| Flutter | `G:\Android\casla_production` | App mobile quản đốc/công nhân (`lib/`, `test/`) |

- **Không commit, không push** khi chưa được bảo. Người dùng review trên
  tenant trước. Khi xung đột với tenant export: lấy GitHub.
- Code ABAP được **dán tay vào ADT**. Mọi thay đổi ABAP phải đi kèm **copy
  block theo method** (hoặc cả file khi sửa rải rác) và **thứ tự kích hoạt**
  (class được gọi trước, BO sau; CDS → MDE → service definition → binding).
- **Kết thúc mỗi lượt sửa phải liệt kê từng file đã sửa/tạo và từng phần đã
  thay đổi** (method, block BDEF, mục docs). Người dùng không xem diff, chỉ
  đọc tin nhắn. Không được chỉ nói "đã cập nhật docs".
- Tenant **lệch repo** (xem mục 5). Khi người dùng dán một method của tenant,
  đối chiếu với bản dán đó, không phải với repo.
- **Ghi lên tenant: không được tự ý.** Agent đọc tenant được qua `vsp`
  (profile `casla` và MCP `vsp` trong `.mcp.json` đều `--read-only`), nhưng
  mọi thao tác ghi (deploy, kích hoạt, transport, sửa text, chạy code, sửa
  `.vsp.json`/`.mcp.json`/cache SSO) chỉ làm khi người dùng **bảo rõ cho đúng
  object đó trong lượt đó**. Mặc định vẫn là đưa copy block để người dùng
  dán vào ADT. Duyệt một lần không áp cho lần sau. Khi được phép: đọc bản
  tenant trước, sửa trên bản đó (không ghi đè bằng repo), dùng profile
  `casla-rw` với transport đang chứa object, đọc lại để xác nhận, rồi báo
  object, transport và nội dung đã đổi.
- Hook `.claude/hooks/guard_tenant_write.py` (đăng ký trong
  `.claude/settings.json`, PreToolUse) trả `ask` cho các lệnh trên, nên Claude
  Code dừng lại chờ người dùng duyệt. Lệnh chỉ đọc (`search`, `source`,
  `transport list`, `sso status`...) đi qua. Hook là lớp chặn thứ hai, không
  thay quy tắc: lệnh ghi đi đường vòng (script tự viết gọi ADT) hook không bắt
  được, vẫn phải hỏi trước. Thêm subcommand vsp mới thì cập nhật `READ_ONLY`
  trong hook.
- **Đổi chữ ký class** (thêm/bỏ tham số, đổi tên method, đổi kiểu trả về):
  `grep -rn "ten_class=>ten_method" serialized`, đưa **từng file gọi** vào bộ
  copy block kể cả khi file gọi không đổi logic. Class dán trước, caller dán
  sau; thiếu caller là lỗi kích hoạt `The formal parameter ... does not exist`.
  Caller thường gặp: `zbp_r_pp_opalloc` locals, `zcl_pp_reassign_job`,
  `zcl_pp_position_api`, `zcl_pp_work_history`, `zcl_pp_output_upload`, các
  testclasses.
- Trước khi kết thúc một lượt sửa ABAP: `bash scripts/check_ci.sh` phải về
  **mốc lỗi có sẵn** (mục 6), không thêm lỗi mới. Flutter: `flutter analyze`
  sạch và `flutter test` xanh.
- Comment: `"` trong class ABAP; `//` trong CDS/BDEF/DCL/MDE; Service
  Definition không có comment.
- abaplint: không `CLASS-DATA` public (dùng getter); tên method ≤ 30 ký tự;
  không giữ tham số không dùng; `cl_abap_unit_assert` có `msg =` thì tham số
  đầu phải có tên (`act =`).
- ABAP SQL `SELECT một_cột ... INTO TABLE @DATA(t)` trả bảng **cấu trúc một
  thành phần**: trong `FOR x IN t` phải dùng `x-một_cột` khi gán vào range,
  nếu không ADT báo "The type of X cannot be converted to the type of LOW".
  abaplint không bắt được vì không có DDIC bảng Z trong deps.
- Trong `LOOP AT t` không được `CLEAR`/`REFRESH`/gán đè/`DELETE` cả bảng `t`
  (kể cả khi là tham số EXPORTING): kích hoạt báo `The table "T" cannot be
  deleted or overwritten within a LOOP across itself`. Đặt cờ, `EXIT`, rồi xử
  lý bảng sau `ENDLOOP` (xem `check_machine` của `zcl_pp_position_api`).
  abaplint không bắt được lỗi này.
- CDS: cột số lượng tính bằng `case` phải cast cả hai nhánh sang
  `abap.dec( 15, 3 )` (kể cả literal `0`) trước khi `sum`/gán
  `@Semantics.quantity.unitOfMeasure`; nếu không DDIC báo
  `Reference Field UNITOFMEASURE has a wrong data type`.
- Script vá file: viết Python ra scratchpad, chạy `python -I -X utf8`, giữ
  CRLF/LF của file, không chạy lại script chèn khi chuỗi mới chứa chuỗi cũ.

## 2. Quy tắc nghiệp vụ hiện hành

Các quy tắc dưới đây là **nguồn sự thật**; code ở cả hai repo phải khớp.

### 2.1 Số dư cộng gộp

- Số dư công nhân trên một công đoạn (`ZTB_PP_EMP_ALLOC.RemainingQuantity`)
  = Giao ban đầu + Chuyển vào − Chuyển ra − Thu hồi − Hoàn thành − Lỗi.
  **Có thể âm.** `validateBalance` chỉ kiểm tra số dư khớp công thức.
- Tổng theo công đoạn: `TotalRemainingQuantity`/`RemainingQuantity` là tổng
  thuần (cộng cả âm); `TotalOpenQuantity`/`OpenQuantity` = Σ max(0, số dư công
  nhân) là số còn xác nhận được; `UnassignedQuantity` = sản lượng − (đã giao −
  thu hồi). Số âm của người xác nhận vượt không bù sang người khác.
- Xác nhận được phép **vượt** số giao (một dòng CONFIRM duy nhất, không chia
  lô). Chỉ chặn khi số dư trước xác nhận ≤ 0: `NO_REMAINING_QUANTITY`
  (`validate_worker_balance`). App: "Không còn số lượng để xác nhận".
- `CONFIRM_ORIGINAL_QUANTITY_EXCEEDED` và `RECALL_ORIGINAL_QUANTITY_EXCEEDED`
  không còn phát sinh (code đã comment); chỉ còn kiểm tra ngữ cảnh work/shift
  của nhóm gốc. App giữ mapping cũ cho dữ liệu lịch sử.
- `read_worker_balances` SELECT thẳng `ZTB_PP_EMP_ALLOC` theo `operation_uuid`
  + `worker_id`, không EML cả công đoạn. Được vì mobile gửi mỗi action một
  request (không `$batch`). Nếu gộp nhiều action vào một changeset thì phải
  quay lại EML để thấy buffer.

### 2.2 Thu hồi

- Mức thu hồi tối đa = **min(usable_quantity của nhóm giao gốc, số dư công
  nhân)**, không âm. Vượt: `RECALL_QUANTITY_EXCEEDED: <mức NUMBER = RAW> <UoM>`.
  App bóc chi tiết bằng `splitBusinessCode` (mã phải có dấu gạch dưới) và hiện
  "Không được thu hồi vượt mức. Tối đa thu hồi được 200 CHC."
- `RECALL_NOT_ALLOWED` chỉ còn nghĩa: gốc sai loại hoặc chưa có balance/khác UoM.
- `available_quantity` của nhóm: có REASSIGN → snapshot ngày mới nhất + phát
  sinh từ ngày đó; không có → cộng gộp thuần toàn thời gian; kẹp ≥ 0. **Không
  min với tổng toàn thời gian của gốc** (REASSIGN gộp cả seat qua nhiều gốc).
- `zcl_pp_alloc_lineage=>recall_error` không có tham số `quantity`.
- App S09: `Assignment.recallLimit` = min(có thể thu hồi của lệnh, số dư ghế
  `seatRemaining`); đỏ ngay khi gõ vượt; stream `watchAssignment` phải bọc
  `carrySeatRemaining` như S08.

### 2.3 Vị trí và máy

- Một công nhân một vị trí trên mỗi lệnh/công đoạn, bất kể ca/ngày:
  `submitInitialAssign` từ chối `POSITION_GROUP_MISMATCH` khi **số dư cộng gộp
  của một vị trí khác** > 0, tính theo (vị trí, UoM), không theo từng dòng
  giao; dòng tiêu thụ không ghi vị trí tính cho vị trí của dòng gốc; REASSIGN
  không cộng. **Dòng giao không có vị trí là một vị trí riêng**
  (`open_line_elsewhere`, trả `abap_bool`; request không gửi PositionID vẫn
  được kiểm tra). App `assignment_position_policy` mirror luật này.
- Khóa nhóm giao gốc (`find_allocation_root` / `find_group_root`): operation,
  worker, **work_id, shift, work_date, uom, position_id**. Đổi bất kỳ thành
  phần nào là gốc mới. Work Center đi theo operation_uuid, mobile không gửi.
- `get_original_position` (BO) và `get_original_machine` (position API) lần
  ngược `OriginalTransactionUUID` tối đa 5 bước nhưng **dừng tại dòng giao**
  (`zcl_pp_alloc_lineage=>is_source_type`) kể cả khi vị trí trống.
- Thu hồi/xác nhận không nhận PositionID từ mobile; lấy từ giao dịch gốc.
  Giao/chuyển nhận PositionID, chỉ kiểm tra `POSITION_NOT_ACTIVE`.
- Danh mục máy: bảng `ZTB_PP_MACHINE` (khóa `MACHINE_ID`, BO `ZR_PP_Machine`,
  Fiori `ZC_PP_Machine_Adm` trong service `ZUI_PP_POS_ADM`). `ZTB_PP_POSITION`
  khóa `(work_center, position_id)`, `MACHINE_ID` là khóa ngoại có thể trống;
  đổi máy là UPDATE `MachineID` trên chính dòng. Máy phải đang dùng trong danh
  mục (`MACHINE_NOT_ACTIVE`) và chỉ gắn ở một vị trí đang dùng. API mobile
  (`create_position`/`change_machine`) gắn máy đang ở vị trí khác là chuyển máy:
  vị trí cũ UPDATE `MachineID` trống trong cùng LUW, saver ghi lịch sử cả hai;
  chỉ `MACHINE_IN_USE` khi vị trí cũ ngoài phạm vi quyền (2026-11-10).
  `change_machine` với mã máy trống là gỡ máy: vị trí vẫn Active, trống mã máy
  (2026-11-10; app: dấu x ở thẻ mã máy S14, `PositionApi.detachMachine`). Fiori/
  upload vẫn chặn; ngừng máy còn gắn ở vị trí Active bị chặn ở BO máy.
- Mobile đọc danh mục máy qua static action `getMachines` trên `ZR_PP_Position`
  (`ZA_PP_MachineQuery` → `ZA_PP_MachineResult`/`ZA_PP_MachineItem`): không
  lọc theo Work Center, không phân trang; app chỉ báo máy đang gắn chỗ khác,
  backend quyết định chuyển máy hay chặn. Từ 2026-11-05 mỗi máy mang thêm `WorkerID`/
  `WorkerName` (phân công Active ở vị trí đang gắn máy) cho chế độ Danh mục
  máy trong tab Vị trí (S14) tra cứu máy; thêm cột vào `ZA_PP_MachineItem` thì sửa cả `zcl_pp_position_api`
  (type `machine`, `get_machines`, `fill_machine_workers`), handler
  `getMachines` trong `zbp_r_pp_position`, và app (`MachineOption.fromJson`).
- `PositionMachineID` ("Mã máy") trên sổ giao dịch `ZC_PP_AllocTxn_Adm` là máy
  chạy ở vị trí **tại thời điểm `CREATED_AT` của dòng** theo `ZTB_PP_MACH_HIST`
  (2026-11-06; trước đó join `ZTB_PP_POSITION` nên ra máy hiện tại); không có
  đoạn lịch sử khớp thì lấy `MachineID` đóng dấu lúc post trên chính dòng.
  Báo cáo sản lượng (`ZUI_PP_WORKER_RPT`, `ZUI_PP_PROD_RPT`) chưa có cột máy.
- `WorkerBoPhan` ("Bộ phận công nhân") trên sổ giao dịch `ZC_PP_AllocTxn_Adm`
  (2026-11-11) = `ZTB_KB_NHANCONG.BO_PHAN` khớp Work Center + Plant của công
  đoạn, `WORKER_ID` của dòng, `POSTING_DATE` trong [FROM_DATE, TO_DATE] (TO_DATE
  trống = mở); không khớp thì trống. Chi tiết `FIORI_ELEMENTS_ADMIN.md`.
- Lịch sử máy theo vị trí (2026-11-06): `ZTB_PP_MACH_HIST`, mỗi đoạn (vị trí,
  máy) một dòng `VALID_FROM`–`VALID_TO` (0 = đang gắn). Chỉ ghi ở saver
  `lsc_zr_pp_position=>save_modified` (BO `with additional save with full
  data`), không ghi tay ở `zcl_pp_position_api`/upload; mọi đường ghi vị trí
  phải đi qua EML của `ZR_PP_Position`, không UPDATE thẳng `ZTB_PP_POSITION`.

### 2.4 Job REASSIGN qua đêm

- Khóa gộp (`seat`): operation_uuid, worker_id, **work_id**, position_id, uom.
  **Ca không vào khóa.** Mỗi khóa cộng gộp (giao +, xác nhận/thu hồi −, hoàn
  tác +), chỉ số dư **> 0** mới mang sang, không bù chéo giữa các khóa.
- Vị trí và bộ phận của một sự kiện lấy theo **chính dòng đó**; dòng không
  ghi thì theo dòng giao gốc. Hệ quả đã chấp nhận: xác nhận ghi sai vị trí
  làm vị trí đó âm mà vị trí thật vẫn mang sang.
- `calculate` của job chỉ dựng entry; handler `reassignOvernight`
  (`zbp_r_pp_opalloc` locals) gán `PostingDate = ngày mục tiêu`,
  `EntryDate`/`EntryTime` = lúc chạy theo múi giờ ca, `MachineID` ưu tiên
  `entry-machine_id` từ dòng giao gốc rồi mới `machine_of_position`. **Mọi
  dòng `ZTB_PP_ALLOC_TXN` đều có `posting_date`**; báo cáo và lịch sử lọc
  thẳng theo cột này, không fallback `work_date`.
- `root_of` dừng ở dòng giao đầu tiên; REASSIGN/REVERSE mang `event-source` =
  gốc; không bao giờ ghi REASSIGN không có mã gốc (`REASSIGN_SOURCE_MISSING`).
- Chạy lại: `rerun_day` repoint các dòng trỏ vào REASSIGN của ngày đó về gốc
  của REASSIGN, DELETE cứng, rồi `run`. Không có trạng thái CANCELLED. Console
  `ZCL_PP_REASSIGN_RERUN` (hằng `target_date`, `repair_lineage`), chạy F9.
  Chẩn đoán: `last_failure`, `failed_operation`, `diagnose_lineage`.
- Test lại từ đầu: console `ZCL_PP_TEST_RESET` xóa cứng `ZTB_PP_ALLOC_TXN`,
  `ZTB_PP_EMP_ALLOC`, `ZTB_PP_OP_ALLOC` (tùy chọn `ZTB_PP_POS_ASGN`), toàn bộ
  hoặc theo `production_order`; mặc định `confirm_delete = abap_false` chỉ
  đếm. Danh mục giữ nguyên. Sau khi xóa phải xóa dữ liệu app trên máy test rồi
  đăng nhập lại.

### 2.5 Lịch sử, ngày, ca

- `zcl_pp_work_history`: ba SELECT lọc `posting_date BETWEEN`. Remaining trong
  summary là cộng gộp thuần.
- Mobile gửi PostingDate/EntryDate/EntryTime giờ địa phương; facade đổi sang
  UTC qua `zcl_pp_shift_resolver=>to_executed_at`. Không ghi giờ địa phương
  vào cột utclong.
- Ca làm việc: khóa `WorkCenter + ShiftID + ValidFrom`; MDE `ZC_PP_SHIFT_ADM`
  annotate `WorkCenter` (không có `Plant` trong projection). Object page có
  bốn field group.

### 2.6 Tài khoản mobile

- `createUser`: WorkerID bắt buộc ở backend ("Mã nhân công là bắt buộc"),
  FullName/Email chỉ mandatory ở bdef; upload Excel vẫn cho trống WorkerID.
- Mật khẩu mặc định Excel 123456, bắt đổi lần đầu. `WORKER_NO_ACCOUNT` khi
  worker chưa có tài khoản; `MANAGER_WORKER_NOT_ALLOWED` khi role quản lý và
  role công nhân không chung bộ phận.

### 2.7 Upload Excel sản lượng và báo cáo

- `uploadExcel` (static action trên `ZR_PP_OpAlloc`, chỉ expose ở
  `ZC_PP_OpAlloc_Adm`, logic `ZCL_PP_OUTPUT_UPLOAD`): template 9 cột, dữ liệu
  từ dòng 3; mỗi dòng ghi INITIAL_ASSIGN (SL dải chuyền) và/hoặc CONFIRM (SL
  hoàn thành + SL lỗi) theo Ngày thực hiện, `SourceChannel = FIORI`,
  `ReasonCode = EXCEL_UPLOAD`, không ca, vị trí/máy theo phân công A; số dư
  cùng luật mobile; chặn upload trùng; sau khi ghi chạy `reassignOvernight`
  từng ngày tới hôm nay trong cùng LUW; tất cả hoặc không gì. Chi tiết
  `docs/OUTPUT_UPLOAD.md`.
- Báo cáo theo nhân công `ZUI_PP_WORKER_RPT` (`ZI_PP_WorkerOutput_Agg`): cộng
  theo loại giao dịch như `summarize` (kể cả `*_ADJUST`, `CORRECTION`, trừ
  `REVERSE`, bỏ `TRANSFER`); ngày báo cáo = `posting_date`.
- Báo cáo tiến độ ngày `ZUI_PP_PROD_RPT` (`ZI_PP_ProdDaily`, custom entity
  `ZC_PP_ProdDaily_Sum`/`_Dtl`, `zcl_pp_prod_daily_query`): SL hoàn thành =
  CONFIRM thô (không trừ REVERSE, không cộng CORRECTION, người dùng chốt);
  `DateFrom`/`DateTo` bắt buộc theo posting date.

## 3. Bản đồ ràng buộc: sửa chỗ này phải sửa chỗ kia

| Khi đổi | Phải đổi/kiểm tra cùng lúc |
| --- | --- |
| Công thức số dư (`confirm`, `reverse`, `recall`, `transfer`) | `validateBalance`, `validate_worker_balance`, `zcl_pp_work_history=>summarize`, `zcl_pp_output_upload=>plan_balance`, app `seat_balance.dart` + `Assignment.remaining/groupRemaining/recallLimit`, docs `TECHNICAL_DOCUMENTATION.md` mục RemainingQuantity |
| Tổng theo công đoạn (`ZI_PP_EmpAlloc_Agg`) | `ZR_PP_OpAlloc` + BDEF readonly, `ZC_PP_OpAlloc_Adm` + MDE, SELECT SUM trong `checkOperationAccess`, `ZA_PP_OperationAccessResult`, app `operation_access.dart`, docs `TECHNICAL_DOCUMENTATION.md` mục Tổng theo công đoạn |
| Mã lỗi mới của BO | `docs/MOBILE_ERROR_MAPPING.md` (hai bảng) + `docs/TECHNICAL_DOCUMENTATION.md` bảng mã; app `sync_failure.dart` (`_sapBusinessMessages`, `_codeFirstBusinessCodes`, `_sapRetryableBusinessCodes` nếu retry được, `_sapDetailMessage` nếu có chi tiết), `mutation_feedback.dart` (`_requiresDataCorrection`, `_recoveryGuidance`), test `test/core/sync_failure_test.dart` |
| Mã lỗi có chi tiết sau dấu hai chấm | `odata_error.dart::splitBusinessCode` (mã phải có `_`), `odataSafeDiagnostic` chỉ trả mã, `_quantityDetail` parse số RAW + UoM |
| Chữ ký method của `zcl_pp_alloc_lineage` | mọi lời gọi trong `zbp_r_pp_opalloc` locals, job, `zcl_pp_output_upload`, testclasses lineage; abaplint `unused_variables` nếu bỏ check mà giữ tham số |
| Khóa nhóm giao gốc (`allocation_group`) | `find_group_root` WHERE, `find_allocation_root` lời gọi trong `initialAssign`, testclasses lineage (`group_key`, `isolate_group_and_owner`), docs `DAILY_REASSIGN_JOB.md` mục PositionID, `POSITION_MANAGEMENT.md` |
| Khóa gộp của job (`seat`) | kiểu `event`/`seat`, `collect_day`, `settle_seats` (SORT + READ/INSERT), `calculate` (entry + thông báo), `deduct_unlinked` (thứ tự khóa), test `preserve_work_and_shift`, `separate_lines_keep_position`, docs `DAILY_REASSIGN_JOB.md` |
| Cột mới trên `ZTB_PP_ALLOC_TXN` | `ZR_PP_OpAlloc` + BDEF fields, `ZC_PP_AllocTxn_Adm` + MDE, `ZA_PP_HistEntry`/`zcl_pp_work_history` nếu lộ ra mobile, `read_allocation_lineage` FIELDS, `zcl_pp_output_upload` (`ledger_line`, FIELDS trong `write_row`/`read_ledger`), app `WorkHistoryEntry` + parser + fixture test |
| Loại giao dịch mới trên ledger hoặc đổi nghĩa số lượng theo loại | `zcl_pp_txn_type`, `zcl_pp_work_history=>summarize`, job `collect_day`, `ZI_PP_WorkerOutput_Agg` (case theo `transaction_type`), `ZI_PP_ProdDaily` (WHERE chỉ CONFIRM thô), docs `WORKER_OUTPUT_REPORT.md`, `PRODUCTION_DAILY_REPORT.md` |
| Báo cáo tiến độ hàng ngày (`ZUI_PP_PROD_RPT`) | `ZI_PP_ProdDaily` (cột + WHERE), custom entity `ZC_PP_ProdDaily_Sum`/`_Dtl` (phần tử phải khớp `summary_row`/`detail_row` của `zcl_pp_prod_daily_query`), `build_scope` (tên phần tử lọc viết hoa; mọi phần tử khóa đều phải lọc được, khoảng ngày nằm trong khóa, nếu không object page 404), hai SELECT trong `read_rows` (FIELDS + GROUP BY cùng danh sách), MDE, service definition, `scripts/check_admin_metadata.py`, docs `PRODUCTION_DAILY_REPORT.md` |
| Tham số action mobile (`ZA_PP_*`) | bdef abstract (`mandatory:execute`), handler đọc `input-*`, app gateway payload, `docs/appendix_odata_contract.md` bên Flutter, `MOBILE_ERROR_MAPPING.md` |
| Vị trí/máy trên ledger | `initialAssign`/`transfer` (lookup theo PositionID mobile gửi), `recall`/`confirm` (`get_original_position`/`get_original_machine`), `reverse` (chép), job (`seat-position_id`, `source-machine_id`), upload (`assigned_position`/`machine_of_position`), Fiori adjust (chỉ origin) |
| Khóa/cột của `ZTB_PP_POSITION`, danh mục máy | `ZTD_PP_POSITION` (draft đủ cột CDS, kể cả `MACHINENAME` từ association), `ZR_PP_Position` + BDEF, `ZC_PP_Position_Adm` + MDE + value help `ZI_PP_Machine_VH`, `ZC_PP_Machine_Adm` + `ZI_PP_MachineAll_VH`, `ZC_PP_Position` (mobile), `ZI_PP_Position_VH`, `zbp_r_pp_position` locals (`check_machine`), `zcl_pp_position_api` (`active_position`, `check_machine`, `save_position`), `zcl_pp_position_upload`, `zcl_pp_machine_upload` (độ dài, luật ngừng máy), `ZC_PP_AllocTxn_Adm` (join `ZTB_PP_MACH_HIST` cho `PositionMachineID`), `zbp_r_pp_machine` (`validateMachine`), saver `lsc_zr_pp_position` + `ZTB_PP_MACH_HIST`/`ZC_PP_MachHist_Adm` + `ZCL_PP_MACH_HIST_SEED` (lịch sử máy), service `ZUI_PP_POS_ADM`, `scripts/check_admin_metadata.py`, docs `POSITION_MANAGEMENT.md`, app S14 mã lỗi |
| Loại giao dịch / trạng thái / nguồn mới trên ledger (giá trị mới) | nhánh `case` diễn giải ở `ZI_PP_TxnType_VH`, `ZI_PP_TxnStatus_VH`, `ZI_PP_SourceChannel_VH` (value help bộ lọc admin, `distinct` từ `ZTB_PP_ALLOC_TXN`, 2026-11-06) |
| Value help mới trên projection admin (`@Consumption.valueHelpDefinition`) | phải `expose` view đó trong service definition tương ứng (`ZUI_PP_ALLOC_ADM`, ...), `scripts/check_admin_metadata.py` bắt lỗi thiếu expose; cùng bộ copy block: view VH → projection → service definition |
| MDE admin (`*_adm.ddlx`) | mọi trường annotate phải tồn tại trong projection, `scripts/check_admin_metadata.py` (`@Metadata.layer: #CORE`), service definition không comment |
| Tên/field của action trong BDEF | projection `zc_*_adm.bdef` `use action`, MDE `dataAction`, app gateway tên action |
| Upload Excel sản lượng (`ZCL_PP_OUTPUT_UPLOAD`) | Luật số dư/vị trí phải khớp bound action mobile: `plan_balance` mirror `validate_worker_balance`, `check_row` dùng `open_line_elsewhere`; đổi tham số `reassignOvernight` thì sửa `rerun`; đổi template thì sửa `input`, `build_row`, test và `docs/OUTPUT_UPLOAD.md` |
| Luật app chặn trước (S07 vị trí, S09 thu hồi, S15 xác nhận) | phải **không chặt hơn backend** và **không lỏng hơn** ở ca thường: S07 `groupPositionConflict`, S09 `recallLimit`, S15/`grouped_confirmation.dart` `canConfirm` = `groupRemaining > 0` |

## 4. Checklist theo vùng

**Sửa bound action mobile (`initialAssign/confirm/recall/transfer/reverse`)**
1. Giữ số câu lệnh (abaplint trần 80 statement/method): mở rộng câu lệnh có
   sẵn, hạn chế thêm `DATA`/`IF` mới; cân nhắc gộp vào `COND`.
2. Mọi nhánh lỗi: `report_instance_failure` + `CONTINUE`; mã lỗi là chuỗi
   `^[A-Z][A-Z0-9_]{2,80}$` hoặc `MÃ: chi tiết`.
3. Ghi thêm mã vào hai bảng docs + app mapping + test.
4. abaplint, copy block, thứ tự kích hoạt.

**Sửa `zcl_pp_alloc_lineage`**
1. Chữ ký đổi → sửa BO, job, upload cùng lúc; kích hoạt lineage trước.
2. Testclasses lineage (`open_line_elsewhere_cases`, `open_seat_balance_cases`,
   `open_position_blocks_new_seat`).
3. `is_source_type` là nơi duy nhất định nghĩa "dòng giao".

**Sửa job REASSIGN**
1. Cửa sổ tính: giao dịch ngày hôm trước + REASSIGN đã ghi cho ngày mục tiêu.
2. Không ghi REASSIGN không có gốc; mọi lineage lỗi phải ra `error_detail`.
3. Test `confirm_at_other_seat`, `reassign_chain_keeps_root`,
   `assignment_after_clear_carries`, `preserve_work_and_shift` là các ca đã
   chốt với người dùng, không đổi kỳ vọng nếu chưa có quyết định mới.
4. Sau khi dán lên tenant: rerun ngày đang mở bằng console nếu job đã chạy.

**Sửa app Flutter**
1. Luật số liệu nằm trong `lib/domain/policies/` (seat_balance,
   grouped_confirmation, assignment_position_policy, production_math); màn
   hình chỉ gọi, không tự tính.
2. `watchAssignment` trả dòng DB **không có** `seatRemaining`: màn nào cần số
   dư ghế phải `carrySeatRemaining` như S08/S09.
3. Thông điệp người dùng tiếng Việt, mã-first; không lộ body OData/token.
4. `flutter analyze` + `flutter test`.

**Sửa upload Excel sản lượng (`ZCL_PP_OUTPUT_UPLOAD`, handler `uploadExcel`)**
1. Kiểm tra nghiệp vụ mới trên mobile (`initialAssign`/`confirm`) phải cân
   nhắc áp vào `check_row`/`plan_balance`; upload không được lỏng hơn mobile.
2. Class ghi EML `IN LOCAL MODE` ngoài behavior pool (tiền lệ
   `zcl_pp_position_api=>get_original_machine`); tenant từ chối thì chuyển bốn
   method EML (`read_ledger`, `read_balance`, `write_row`, `rerun`) vào locals.
3. Chạy lại REASSIGN trong LUW dựa vào `calculate` tính delta theo `posted`;
   bỏ delta ở job thì upload phải đổi cách chạy lại.
4. Test include `zcl_pp_output_upload.clas.testclasses` (LOCAL FRIENDS); dán
   class trước handler; publish lại binding `ZUI_PP_ALLOC_ADM_O4`.

**Sửa MDE/Fiori admin**
1. Trường trong ddlx phải có trong projection; đổi khóa projection thì đổi
   ddlx cùng lượt.
2. Object page cần `@UI.facet` (identification hoặc fieldGroup).
3. Chạy `python scripts/check_admin_metadata.py`.

## 5. Hạn chế và nợ kỹ thuật còn mở

- Tenant lệch repo: scope check (`has_func_op_scope`, `has_worker_op_scope`)
  bị comment trên tenant; `transfer` bị comment toàn bộ trên tenant;
  `MACHINE_ID` trên tenant là string còn repo là CHAR 10; `reassignOvernight`
  trên tenant báo lỗi job chỉ có `error_code` và `MachineID` của REASSIGN luôn
  lấy `machine_of_position`. Không có cách tự đồng bộ; khi kết quả tenant khác
  dự đoán, hỏi người dùng bản đang chạy.
- Gateway trả `/IWBEP/CM_V4S_RUN/000` khi handler dump; app không log body nên
  phải xem Feed Reader (Runtime Errors) trên ADT hoặc gọi lại bằng Postman.
- Xác nhận vượt làm số dư âm, job tính riêng từng khóa: tổng mang sang có thể
  lớn hơn thực tế khi xác nhận ghi sai vị trí/bộ phận. Lựa chọn đã chốt.
- REASSIGN không cộng vào số dư vị trí trong `open_line_elsewhere` (effect 0,
  giống `available_quantity`); số mang sang đã nằm trong tổng thuần của vị trí.
- Công nhân đổi Work Center của công đoạn sau khi đã giao: `operation_uuid`
  không đổi, các dòng cũ vẫn chung nhóm; chưa xử lý.
- Upload Excel sản lượng chưa kích hoạt/test trên tenant; chưa có màn UI gọi
  action `uploadExcel` (`ui5-upload/` import từng dòng phía client). Dòng
  upload không có ca nên không nối nhóm với dòng mobile cùng ngày; CONFIRM chỉ
  có SL hoàn thành ghi ở vị trí của dòng giao nguồn (chủ ý).
- Báo cáo nhân công `ZUI_PP_WORKER_RPT` đã đẩy lên tenant 2026-11-09 qua `vsp`
  (package mới `ZPK_XNSL_SM_REPORT` > `ZPK_XNSL_REPORT_WORKER` dưới
  `ZPK_XNSL_SM`, transport `AK3K907028`); còn IAM app/catalog và app Fiori làm
  tay. Báo cáo tiến độ `ZUI_PP_PROD_RPT` và `getMachines` chờ kích hoạt/publish;
  bộ copy block nằm ở các file `*_copy_ADT.md` tại gốc repo, xóa khi đã dán xong.
- Bài học `vsp` 2026-11-09: `deploy` chỉ nhận DDLS/BDEF/SRVD/CLAS/...; DCL, MDE,
  package, binding đi `vsp adt request` (POST tạo, LOCK → PUT source → UNLOCK →
  POST `/sap/bc/adt/activation`). Mỗi lần gọi `--stateful` là **một phiên ADT
  mới**: UNLOCK ở lệnh sau không giải phóng khóa của lệnh LOCK trước, kích hoạt
  báo "User ... is currently editing" cho tới khi phiên cũ hết hạn. Package có
  transport cần `--allow-transportable-edits`. Publish V4: POST
  `/sap/bc/adt/businessservices/odatav4/publishjobs?servicename=&serviceversion=`.
- ABAP Unit chỉ chạy được trên tenant; abaplint không chạy test. Test mới chưa
  được xác nhận xanh cho tới khi người dùng chạy trên ADT.
- Nhiều file modified/untracked chưa commit từ nhiều ngày; khi commit cần tách
  theo chủ đề.

## 6. Mốc abaplint (11 lỗi có sẵn, không được tăng)

```
zbp_r_pp_opalloc locals        Cannot apply ALPHA (CSequenceType)
zbp_r_pp_shift locals          cyclomatic_complexity validateShift
zcl_pp_alloc_lineage           unused "quantity" trong confirmation_error
zcl_pp_reassign_job            if_apj_rt_run~execute not found (interface không có trong deps)
zcl_pp_shift_resolver          cyclomatic_complexity resolve
zbp_i_mob_user locals          method_length login (87 > 80)
zcl_mob_token_validator        unused "plant" x3
zbp_i_mob_work locals          unused set_failed, set_reported
```
