# Quản lý vị trí làm việc của công nhân

Mục tiêu: biết mỗi công nhân đang ngồi vị trí (ghế/máy) nào và điều chuyển vị trí
có kiểm soát. Thiết kế giữ ở mức tối thiểu: chỉ quan tâm dòng đang Active.

## Bảng

**`ZTB_PP_POSITION` — danh mục vị trí**

| Field | Kiểu | Key | Ghi chú |
| --- | --- | --- | --- |
| `WORK_CENTER` | CHAR 8 | ✅ | |
| `POSITION_ID` | CHAR 10 | ✅ | Vị trí |
| `MACHINE_ID` | CHAR 10 | ✅ | Mã máy |
| `POSITION_NAME` | CHAR 60 | | Tên/mô tả vị trí |
| `STATUS` | `ZDE_IS_ACTIVE` (A/I) | | |
| audit | | | `CREATED_BY/AT`, `LAST_CHANGED_BY/AT`, `LOCAL_LAST_CHANGED_AT` |

**`ZTB_PP_POS_ASGN` — phân công công nhân vào vị trí**

| Field | Kiểu | Key | Ghi chú |
| --- | --- | --- | --- |
| `WORK_CENTER` | CHAR 8 | ✅ | |
| `POSITION_ID` | CHAR 10 | ✅ | |
| `WORKER_ID` | CHAR 8 | ✅ | Mã công nhân |
| `STATUS` | `ZDE_IS_ACTIVE` (A/I) | | A đang ngồi / I đã rời |
| audit | | | như trên |

`ZTD_PP_POSITION`, `ZTD_PP_POS_ASGN` là bảng draft tương ứng.

## Quy tắc

- Không quản lý Plant, không tính theo ca. Không xóa dòng; ngừng dùng bằng `I`.
- **Một vị trí chỉ có một máy đang dùng.** Tạo dòng Active mới cho vị trí với máy
  mới thì dòng chứa máy cũ của cùng vị trí **tự chuyển I**. Một máy không được
  Active ở hai vị trí; muốn chuyển máy sang vị trí khác thì ngừng dùng ở vị trí
  cũ trước.
- **Một công nhân ngồi một vị trí, một vị trí có một công nhân.** Tạo (hoặc kích
  hoạt lại) phân công Active thì:
  - phân công Active cũ của công nhân đó ở vị trí khác **tự chuyển I**
    (điều chuyển);
  - người đang ngồi ở vị trí đó **tự chuyển I** và không được xếp chỗ khác.
- Chỉ tạo phân công Active được khi vị trí đang có dòng Active, và công nhân
  thuộc work center của vị trí theo master nhân công tại ngày hiện tại.
- **"Đang ngồi" = phân công Active và vị trí có dòng Active.** Vị trí bị ngừng dùng
  thì phân công trên đó không còn được tính, không cần sửa phân công.
- Gán lại một công nhân về vị trí cũ: mở dòng phân công cũ (key trùng) và đổi
  trạng thái về `A`, không tạo dòng mới.
- **Fiori quản trị có toàn quyền.** Quyền theo work center chỉ áp cho mobile.

## Cơ chế

Việc chuyển dòng cũ sang I nằm ở determination `on save` của từng BO
(`deactivateReplacedMachine`, `deactivateSuperseded`). Validation tương ứng đọc
lại qua buffer RAP: nếu vì lý do nào đó dòng cũ vẫn còn Active (ví dụ đang có
người mở bản nháp dòng đó) thì việc lưu bị từ chối, không để lọt hai dòng Active.

Hai thao tác đồng thời trên hai key khác nhau (ví dụ hai quản lý cùng lúc xếp
hai người vào một ghế) không khóa lẫn nhau; validation bắt được phần lớn trường
hợp, còn khe hở đồng thời tuyệt đối không được xử lý ở phiên bản đơn giản này.

## Object

| Object | Vai trò |
| --- | --- |
| `ZR_PP_Position`, `ZBP_R_PP_POSITION` | BO danh mục vị trí (managed, draft) |
| `ZR_PP_PosAssign`, `ZBP_R_PP_POSASSIGN` | BO phân công (managed, draft) |
| `ZI_PP_Position_VH` | Value help vị trí đang dùng |
| `ZC_PP_Position_Adm`, `ZC_PP_PosAssign_Adm` + MDE | Hai màn Fiori |
| `ZUI_PP_POS_ADM`, `ZUI_PP_POS_ADM_O4` | Service + binding OData V4 UI (Fiori) |
| `ZC_PP_Position`, `ZC_PP_PosAssign` | Projection mobile: chỉ `use action` facade, đọc bị DCL chặn |
| `ZUI_PP_POS`, `ZAPI_PP_POS` | Service + binding OData V4 Web API cho mobile |
| `ZCL_PP_POSITION_API` | Logic + kiểm tra token/phạm vi của API mobile |

## Việc cần làm trên tenant

1. Pull và activate: 4 bảng → CDS + DCL → BDEF + behavior pool → projection +
   MDE → service → publish binding `ZUI_PP_POS_ADM_O4` và `ZAPI_PP_POS`.
2. Tạo IAM app + business catalog cho hai màn quản trị.
3. Smoke-test: tạo vị trí G05 máy M1; đổi sang máy M2 (dòng M1 thành I). Gán A vào
   G05, B vào G06, rồi A vào G06 → phân công A@G05 và B@G06 thành I, chỉ còn
   A@G06 Active.

## API mobile

Service mobile riêng `ZUI_PP_POS` (binding `ZAPI_PP_POS`), tách khỏi API phân bổ
sản lượng. Static action nằm trên chính BO vị trí, logic trong
`ZCL_PP_POSITION_API`. Mỗi request một lệnh.

| Entity set | BO | Action |
| --- | --- | --- |
| `Positions` | `ZR_PP_Position` | `getPositionBoard`, `submitPositionCreate`, `submitMachineChange` |
| `PositionAssignments` | `ZR_PP_PosAssign` | `submitPositionTransfer` |

Mobile chỉ gọi được bốn action này: projection không expose create/update/draft,
và đọc trực tiếp entity set trả rỗng (DCL `ZR_PP_POSITION`/`ZR_PP_POSASSIGN` chặn,
projection mobile kế thừa). Fiori quản trị đọc qua projection `_Adm` nên không
bị ảnh hưởng.

**Xác thực (cả bốn action):** `AccessToken` + `DeviceID` được kiểm tra đầy đủ —
token hash còn hạn, khớp thiết bị của session, tài khoản Active, không đang bị
bắt đổi mật khẩu, có function `PP_POS_MANAGE`. Sau đó chỉ cho phép trên Work
Center mà function đó được cấp qua work context của cùng chức danh.

| Action | Tham số | Kết quả |
| --- | --- | --- |
| `getPositionBoard` | `AccessToken`, `DeviceID`, `WorkCenter` (trống = mọi Work Center được quyền) | `WorkCenterCount`, `PositionCount`, `_Positions[]`: `WorkCenter`, `PositionID`, `MachineID`, `PositionName`, `WorkerID`, `WorkerName`, `IsOccupied` |
| `submitPositionCreate` | `AccessToken`, `DeviceID`, `WorkCenter`, `PositionID`, `MachineID`, `PositionName` | `ZA_PP_PosCommandResult` |
| `submitMachineChange` | `AccessToken`, `DeviceID`, `WorkCenter`, `PositionID`, `MachineID` (máy mới) | `ZA_PP_PosCommandResult` |
| `submitPositionTransfer` | `AccessToken`, `DeviceID`, `WorkCenter`, `PositionID`, `WorkerID` | `ZA_PP_PosCommandResult` |

`ZA_PP_PosCommandResult`: `Status = SUCCESS`, `WorkCenter`, `PositionID`,
`MachineID`, `WorkerID`, `Message`.

- **Tạo vị trí:** tạo dòng Active mới. Vị trí đã đang dùng thì phải đổi máy,
  không tạo lại (`POSITION_EXISTS`).
- **Đổi máy:** tạo dòng Active với máy mới (giữ tên vị trí), dòng máy cũ tự
  chuyển I. Người đang ngồi vị trí đó giữ nguyên phân công.
- **Xếp công nhân:** phân công cũ của công nhân và người đang ngồi vị trí đó tự
  chuyển I.
- Gọi lại một lệnh đã có hiệu lực (vị trí đã tạo đúng máy đó, vị trí đã dùng
  đúng máy đó, công nhân đã ngồi đúng vị trí đó) vẫn trả `SUCCESS`, nên retry
  sau timeout an toàn.

**Lỗi** trả theo cùng hợp đồng với các facade PP khác: request lỗi, message là
mã lỗi.

| Mã lỗi | Ý nghĩa |
| --- | --- |
| `AUTH_FAILED` | Thiếu token/thiết bị hoặc lỗi cấu hình băm |
| `TOKEN_INVALID_OR_EXPIRED`, `DEVICE_MISMATCH`, `USER_INACTIVE`, `PASSWORD_CHANGE_REQUIRED` | Từ bước xác thực token |
| `MISSING_PERMISSION` | Không có function `PP_POS_MANAGE` |
| `NO_WORK_CENTER_SCOPE` | Work Center (của vị trí, hoặc của ghế hiện tại của công nhân) ngoài phạm vi quyền |
| `INPUT_INVALID` | Thiếu tham số bắt buộc |
| `POSITION_EXISTS` | Tạo vị trí đang dùng máy khác — dùng đổi máy |
| `POSITION_NOT_ACTIVE` | Vị trí chưa có hoặc đang ngừng dùng |
| `MACHINE_IN_USE` | Máy đang dùng ở vị trí khác |
| `WORKER_NOT_IN_WORK_CENTER` | Công nhân không thuộc Work Center theo master nhân công hôm nay |
| `POSITION_LOCKED` | Dòng đang được mở bản nháp trên Fiori |
| `POSITION_SAVE_FAILED` | Không ghi được vị trí/phân công |

Việc cần làm: tạo function `PP_POS_MANAGE` trong `ZTB_MOB_FUNC` và gán cho chức
danh giám sát; work context của chức danh đó phải có Work Center tương ứng.

## Còn lại

- **Ledger:** đóng dấu vị trí/máy vào `ZTB_PP_ALLOC_TXN` lúc post giao dịch.
