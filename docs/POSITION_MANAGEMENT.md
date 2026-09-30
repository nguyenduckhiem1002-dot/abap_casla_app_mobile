# Quản lý vị trí làm việc của công nhân

Mục tiêu: biết mỗi công nhân đang ngồi vị trí (ghế/máy) nào, điều chuyển vị trí
có kiểm soát, và giữ lịch sử để về sau trả lời được "lúc phát sinh giao dịch thì
công nhân ngồi đâu".

## Quy tắc nghiệp vụ

- Vị trí được định danh bởi **Work Center + Vị trí**. Không quản lý Plant; điều
  kiện là mã work center không trùng giữa các nhà máy.
- Không tính theo ca. Một vị trí có tối đa **1** công nhân, một công nhân ngồi
  tối đa **1** vị trí tại một thời điểm.
- **Điều chuyển W vào vị trí P** (một LUW):
  1. Ghế cũ của W (nếu có) được giải phóng — lịch sử ghi `TRANSFERRED`.
  2. Người đang ngồi ở P (nếu có) rời ghế và **không tự được xếp chỗ khác** —
     lịch sử ghi `BUMPED`.
  3. W ngồi vào P.
- **Cho rời vị trí**: gỡ người đang ngồi mà không xếp chỗ mới — `RELEASED`.
- W phải thuộc work center của P theo master nhân công còn hiệu lực. Chuyển khác
  work center phải đổi master nhân công trước.
- Vị trí không bị xóa; ngừng dùng bằng `Status = I`. Không ngừng dùng được vị trí
  đang có người ngồi. Một mã máy chỉ gắn với một vị trí đang dùng.
- **Fiori quản trị có toàn quyền** (cổng vào là IAM app). **Chỉ kênh mobile kiểm
  tra quyền theo work center.**

## Thiết kế

| Object | Vai trò |
| --- | --- |
| `ZTB_PP_POSITION` | Danh mục vị trí, kèm người đang ngồi và thông tin sự kiện gần nhất |
| `ZTB_PP_POS_ASGN` | Lịch sử ngồi, append-only: mỗi dòng là một khoảng thời gian một người ngồi một vị trí |
| `ZR_PP_Position` | BO managed + draft + additional save; action `transferWorker`, `releasePosition` |
| `ZI_PP_PosAssign` | View đọc lịch sử, hiển thị ở trang chi tiết vị trí |
| `ZC_PP_Position_Adm`, `ZUI_PP_POS_ADM(_O4)` | App Fiori quản trị |

Người đang ngồi lưu ngay trên dòng vị trí, nên mỗi lần điều chuyển là một lần
update dòng vị trí và RAP khóa ghế đó: hai thao tác đồng thời không thể xếp hai
người vào một ghế. Ghế cũ của người được điều chuyển cũng bị update (và khóa)
trong cùng LUW.

Lịch sử được ghi ở `save_modified` (additional save) từ các trường `Last*` mà
action đặt. Hai lệnh ghi đều idempotent — chỉ đóng dòng còn mở, chỉ insert khi
khóa chưa tồn tại — nên draft activation gửi lại dữ liệu cũ không sinh lịch sử
trùng. Người ngồi và các trường sự kiện là readonly; mọi thay đổi người ngồi đều
phải đi qua action, vì vậy luôn có lịch sử.

Action bị từ chối trên bản nháp: phải lưu/hủy bản nháp của vị trí trước khi điều
chuyển. Khi một vị trí đang được sửa ở chế độ nháp, điều chuyển vào/ra vị trí đó
bị khóa cho tới khi lưu hoặc hủy.

## Việc cần làm trên tenant

1. Pull và activate theo thứ tự: 3 bảng → `ZI_PP_PosAssign` → `ZR_PP_Position` →
   BDEF + `ZBP_R_PP_POSITION` → projection + MDE → service → publish binding
   `ZUI_PP_POS_ADM_O4`.
2. Tạo IAM app + business catalog cho app quản trị vị trí và gán cho vai trò quản
   trị (như các app admin khác).
3. Kiểm tra: association `_Assignments` từ projection draft sang
   `ZI_PP_PosAssign` (không thuộc BO) hiển thị được bảng lịch sử trên object page.
4. Smoke-test: tạo 2 vị trí cùng work center; điều chuyển A vào ghế 1, B vào ghế
   2, rồi A vào ghế 2 → ghế 1 trống, B không có ghế, lịch sử có
   `TRANSFERRED` (A rời ghế 1) và `BUMPED` (B rời ghế 2), dòng mới của A trỏ
   `PreviousAssignUUID` về lượt ngồi ở ghế 1.

## Còn lại

- **Giai đoạn 2 — mobile:** `getPositionBoard` (sơ đồ ghế + người ngồi trong các
  work center giám sát được quyền) và `submitPositionTransfer` /
  `submitPositionRelease`, xác thực token và kiểm tra function `PP_POS_TRANSFER`
  theo work center của work context. Facade gọi lại đúng `perform_transfer` /
  `perform_release` để hai kênh dùng chung một bộ quy tắc.
- **Giai đoạn 3 — ledger:** thêm `POSITION_ID`, `MACHINE_ID` vào
  `ZTB_PP_ALLOC_TXN`; lúc post giao dịch backend tra lượt ngồi còn hiệu lực tại
  `EXECUTED_AT` và ghi ảnh chụp vị trí/máy vào dòng ledger.
- Tên công nhân chưa hiển thị cạnh mã ở danh sách vị trí.
- Value help chọn công nhân trong hộp thoại điều chuyển chưa lọc theo work center
  của vị trí đang chọn (tham số action không nhận được ngữ cảnh instance); backend
  vẫn từ chối công nhân khác work center.
