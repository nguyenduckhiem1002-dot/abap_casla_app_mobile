# Fiori Elements administration

Repository cung cấp sáu bề mặt quản trị IAM-protected, trong đó danh mục ca làm việc được tách thành app cấu hình riêng và vị trí/máy dùng chung một service. User/Role mapping và Role/Function/Work mapping là composition child trong app cha; không tạo app rời cho từng mapping row.

## 1. User Administration

- Service: ZUI_MOB_USER_ADM
- Binding: ZUI_MOB_USER_ADM_O4
- Entity chính: Accounts / ZC_MOB_User_Adm
- Composition: _Roles / UserRoles

Chức năng:

- createUser: tạo User + Credential + optional initial Role trong một RAP LUW; WorkerID bắt buộc (backend từ chối 'Mã nhân công là bắt buộc' khi trống, 2026-10-27; upload Excel vẫn cho trống);
- changePasswordAdmin: reset password cho một account, đặt PasswordChangeRequired và revoke session cũ;
- unlockUser: reset failed-login counter/lock fields;
- thêm/xóa Role assignment qua composition.

Credential và session không được expose trong mobile service. User admin dùng IAM, không dùng CASLA mobile token.

## 2. RBAC và Work Administration

- Service: ZUI_MOB_RBAC_ADM
- Binding: ZUI_MOB_RBAC_ADM_O4
- Root: Roles
- Child: RoleFunctions, RoleWorkContexts
- Secondary entities: Functions, WorkContexts, value helps.

Role Object Page gồm thông tin Role, Function assignments và Work assignments. Role/Work/Function có thể create/update theo draft nhưng hard-delete bị chặn ở handler; vô hiệu hóa bằng Status/IsActive = I để không làm mất lịch sử mapping.

Work Context được kiểm tra theo WorkCenter và bộ phận công đoạn khi mobile gọi PP command. Plant trên WorkID là thông tin tham khảo; thay đổi Plant không đổi phạm vi quyền. Value help chỉ hỗ trợ UX; direct OData/EML vẫn bị validate backend.

## 3. Master Công đoạn

- Service: ZUI_MD_CONGDOAN_ADM
- Binding: ZUI_MD_CONGDOAN_ADM_O4
- Entity: CongDoans / ZC_MD_CongDoan_Adm

Business key versioned: MaCongDoan + ValidFrom. Các rule:

- code/name/from/to bắt buộc;
- ValidTo >= ValidFrom;
- DonGiaXM, DonGiaGC không âm;
- cùng mã không overlap validity interval;
- không hard-delete phiên bản lịch sử.

Master dùng để enrichment tên/bộ phận/đơn giá cho OperationStandardTextCode; nó không thay thế live operation guard.

## 4. Production Allocation Correction & Audit

- Service: ZUI_PP_ALLOC_ADM
- Binding: ZUI_PP_ALLOC_ADM_O4
- OperationAllocations: ZC_PP_OpAlloc_Adm, chỉ action correctConfirm;
  cột tổng: Số dư thuần (cộng cả âm), Còn xác nhận được (chỉ cộng dương),
  Chưa giao (sản lượng − (đã giao − thu hồi)) từ 2026-10-28.
- AllocationTransactions: ZC_PP_AllocTxn_Adm, query ledger read-only.
- Cột "Bộ phận công nhân" (`WorkerBoPhan`, 2026-11-11) của sổ giao dịch lấy
  `BO_PHAN` từ Bảng khai báo nhân công theo xưởng (`ZTB_KB_NHANCONG`), join
  trái theo Work Center + Plant của công đoạn, mã công nhân `WORKER_ID` của
  dòng và Posting Date nằm trong [Từ ngày, Đến ngày] (Đến ngày trống = còn
  hiệu lực). Không có dòng khai báo khớp thì để trống. BO khai báo chặn chồng
  hiệu lực theo Work Center + Plant + mã công nhân nên không nhân dòng; dữ liệu
  khai báo chồng nhau (nhập thẳng bảng) sẽ làm một giao dịch hiện hai lần.
  Khác cột "Bộ Phận" (`WorkID`, bộ phận mobile ghi trên giao dịch).
- Value help bộ lọc (2026-11-06): Lệnh sản xuất `ZI_PP_ProductionOrder_VH`,
  Công đoạn LSX `ZI_PP_OrderOperation_VH` (lọc theo lệnh đã chọn), Loại giao
  dịch `ZI_PP_TxnType_VH`, Trạng thái `ZI_PP_TxnStatus_VH`, Nguồn
  `ZI_PP_SourceChannel_VH`; ba view sau lấy `distinct` từ ZTB_PP_ALLOC_TXN kèm
  diễn giải tiếng Việt, nên chỉ liệt kê giá trị đã có trong sổ. Thêm loại
  giao dịch mới ở `ZCL_PP_TXN_TYPE` thì thêm nhánh case ở `ZI_PP_TxnType_VH`.
- uploadExcel (static action trên OperationAllocations, 2026-11-04): upload Excel
  sản lượng xưởng may để bù khi hệ thống gián đoạn; tham số `zabs_file_crud_poc`
  như upload vị trí/tài khoản, kết quả `ZA_PP_UploadOutputResult`. Ghi
  INITIAL_ASSIGN/CONFIRM theo ngày thực hiện rồi chạy lại REASSIGN tới hôm nay;
  tất cả hoặc không gì. UI cần màn chọn file gọi action (app `ui5-upload/` hiện
  chưa có kind này). Xem `docs/OUTPUT_UPLOAD.md`.

Flow:

    Tìm POSTED CONFIRM trong AllocationTransactions
      -> chọn OperationAllocation
      -> correctConfirm(TransactionUUID, NewQuantity, UnitOfMeasure,
                        ReasonCode, ReasonText)
      -> validate effective quantity + balance
      -> update balance + append CORRECTION delta

Ví dụ:

    CONFIRM       100
    CORRECTION    -20  => effective 80
    CORRECTION    +10  => effective 90

Original CONFIRM không bị sửa. Nếu đã có REVERSE thì correction bị reject. CORRECTION ghi SourceChannel = FIORI, VerificationMethod = IAM, reason và lineage.

## 5. Working Shift Catalog

- Service: ZUI_PP_SHIFT_ADM
- Binding: ZUI_PP_SHIFT_ADM_O4
- Entity chính: Shifts / ZC_PP_Shift_Adm
- Cấu hình ca chỉ dùng WorkCenter, ShiftID và ValidFrom làm khóa; không có Plant trên entity Shifts.
- Quyền: tạo/sửa theo managed draft, Save/Discard, lọc theo WorkCenter, ShiftID, hiệu lực và trạng thái; không hard-delete.
- Audit: hiển thị người/thời điểm tạo và thay đổi cuối; ETag dùng các timestamp chuẩn RAP để chống ghi đè đồng thời.

Ca đêm được xác định theo `ExecutedAt` và timezone của Work Center. Ví dụ 22:00 ngày
07/09 đến 06:00 ngày 08/09 vẫn có `WorkDate = 07/09` cho các xác nhận lúc
23:00, 02:00 và 05:30. Không dùng thời điểm server nhận request khi đồng bộ offline.

## 6. Vị trí làm việc và danh mục máy

- Service: ZUI_PP_POS_ADM
- Binding: ZUI_PP_POS_ADM_O4
- Entity: Machines / ZC_PP_Machine_Adm (danh mục máy, 2026-11-04), Positions /
  ZC_PP_Position_Adm, PositionAssignments / ZC_PP_PosAssign_Adm; mỗi entity một
  app Fiori Elements riêng trên cùng binding.
- Máy: khóa MachineID (ô lọc có value help ZI_PP_MachineAll_VH, mọi máy kể
  cả ngừng dùng), tên bắt buộc, không hard-delete; chuyển I bị chặn khi máy
  còn gắn ở vị trí đang dùng. Static action `uploadExcel` (2026-11-04,
  `ZCL_PP_MACHINE_UPLOAD`, kết quả `ZA_PP_UploadMachineResult`): file 3 cột
  Mã máy | Tên máy | Trạng thái, máy đã có thì cập nhật, chưa có thì tạo; ghi
  tất cả hoặc không gì.
- Vị trí: khóa WorkCenter + PositionID; MachineID là khóa ngoại (value help
  ZI_PP_Machine_VH, chỉ máy đang dùng, hiện kèm tên máy), có thể trống; một máy
  chỉ gắn ở một vị trí đang dùng. Đổi máy là sửa MachineID trên chính dòng.
- Chi tiết luật và API mobile: `docs/POSITION_MANAGEMENT.md`.

## 7. Báo cáo sản lượng xưởng may theo nhân công

- Service: ZUI_PP_WORKER_RPT
- Binding: ZUI_PP_WORKER_RPT_O4
- Entity: WorkerOutputs / ZC_PP_WorkerOutput_Rpt (đọc-only, không BDEF)
- Package: ZPK_XNSL_SM > ZPK_XNSL_SM_REPORT > ZPK_XNSL_REPORT_WORKER (2026-11-09);
  đã đẩy lên tenant qua vsp, transport AK3K907028; IAM app/catalog làm tay.
- Nguồn số liệu: ZI_PP_WorkerOutput_Agg gộp ZTB_PP_ALLOC_TXN theo nhân
  công × bộ phận × công đoạn LSX × ĐVT × ngày thực hiện; SL dải chuyền /
  hoàn thành / lỗi / thu hồi cộng theo loại giao dịch như lịch sử mobile.
- Bộ lọc theo FS: mã/tên nhân công, xưởng, work center, mã/tên bộ phận,
  LSX, mã công đoạn, mã/tên hàng, đơn hàng, ngày thực hiện, ngày đồng bộ;
  value help mới: ZI_PP_WorkerName_VH, ZI_MOB_Work_Location_VH,
  ZI_PP_ProductionOrder_VH, ZI_PP_OrderProduct_VH, ZI_PP_OrderSales_VH.
- Chi tiết ánh xạ cột, quy tắc ngày và rủi ro kích hoạt:
  `docs/WORKER_OUTPUT_REPORT.md`.

## 8. Báo cáo tiến độ hàng ngày xưởng may

- Service: ZUI_PP_PROD_RPT
- Binding: ZUI_PP_PROD_RPT_O4
- Entity: ProductionDailySummary / ZC_PP_ProdDaily_Sum (tổng hợp LSX × công
  đoạn × bộ phận trong khoảng ngày) và ProductionDailyDetails /
  ZC_PP_ProdDaily_Dtl (thêm ngày ghi sổ). Cả hai là custom entity đọc-only,
  query class ZCL_PP_PROD_DAILY_QUERY, không BDEF.
- Nguồn số liệu: ZI_PP_ProdDaily (ZTB_PP_ALLOC_TXN POSTED có posting_date,
  chỉ CONFIRM thô, không trừ REVERSE) + ZTB_PP_OP_ALLOC
  (SL kế hoạch) + ZTB_MOB_WORK (tên bộ phận, tên xưởng) + I_ManufacturingOrder
  (mã hàng, SO/SO item). Số CN biên chế đếm từ ZTB_KB_NHANCONG theo Work Center
  của bộ phận; Số CN làm việc = count distinct mã nhân công có CONFIRM.
- Bộ lọc theo FS: mã bộ phận, mã hàng, tên hàng, SO/SO item (multi, dùng lại
  ZI_MOB_Work_Hist_VH, ZI_PP_OrderProduct_VH, ZI_PP_OrderSales_VH), Từ ngày /
  Đến ngày bắt buộc (posting date).
- Chi tiết ánh xạ cột FS, giả định và thứ tự kích hoạt:
  `docs/PRODUCTION_DAILY_REPORT.md`.

## 9. Service boundary

| Surface | Identity | Mutation |
| --- | --- | --- |
| ZUI_MOB_AUTH | mobile communication user + action validation | login/session/password self-service |
| ZUI_PP_OPALLOC | CASLA token/session/device | controlled production commands |
| ZUI_MOB_USER_ADM | SAP IAM | user + role administration |
| ZUI_MOB_RBAC_ADM | SAP IAM | role/function/work administration |
| ZUI_MD_CONGDOAN_ADM | SAP IAM | versioned master maintenance |
| ZUI_PP_ALLOC_ADM | SAP IAM | correction + audit read + upload Excel sản lượng |
| ZUI_PP_SHIFT_ADM | SAP IAM | working-shift configuration (create/update, deactivate) |
| ZUI_PP_POS_ADM | SAP IAM | machine catalog, positions, position assignments (create/update, deactivate) |
| ZUI_PP_WORKER_RPT | SAP IAM | read-only worker output report |
| ZUI_PP_PROD_RPT | SAP IAM | read-only daily production progress report (custom entity) |

Không thêm admin service binding vào mobile communication scenario. Không expose generic update/delete cho ZTB_PP_EMP_ALLOC hoặc ZTB_PP_ALLOC_TXN.

## 10. Tenant setup checklist

1. Import và activate DDIC/CDS/BDEF/class theo dependency order.
2. Publish các OData V4 admin bindings, trong đó `ZUI_PP_SHIFT_ADM_O4` là binding riêng cho app ca và `ZUI_PP_WORKER_RPT_O4` là binding riêng cho báo cáo sản lượng theo nhân công, `ZUI_PP_PROD_RPT_O4` cho báo cáo tiến độ hàng ngày.
3. Gán IAM business catalogs/roles theo từng trách nhiệm admin.
4. Tạo Fiori Elements shell từ binding thật trên tenant; không commit URL/semantic object giả vào backend repo.
5. Test create account + initial Role, mapping assignments, deactivate Role/Work, validity overlap, correction/audit và raw CRUD denial.
