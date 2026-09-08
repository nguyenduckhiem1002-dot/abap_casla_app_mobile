# Ca làm việc và sản lượng qua nửa đêm

## Quy tắc ngày làm việc

Ngày làm việc là ngày bắt đầu ca, tính theo múi giờ SAP của nhà máy.
Khoảng ca là [bắt đầu, kết thúc): 22:00 thuộc ca đêm, 06:00 thuộc ca tiếp theo.
Ngày hiệu lực cấu hình được kiểm tra theo ngày bắt đầu ca; ca cuối ngày hết hiệu lực
vẫn có thể kết thúc vào sáng hôm sau.

Ví dụ tại nhà máy UTC+07:00:

| Giờ địa phương | ExecutedAt (UTC) | WorkDate | ShiftID |
| --- | --- | --- | --- |
| 07/09/2026 23:00 | 2026-09-07T16:00:00Z | 2026-09-07 | NIGHT |
| 08/09/2026 02:00 | 2026-09-07T19:00:00Z | 2026-09-07 | NIGHT |
| 08/09/2026 05:30 | 2026-09-07T22:30:00Z | 2026-09-07 | NIGHT |

## Cấu hình và GET

### Service riêng cho ứng dụng Fiori

- Read/value-help view: `ZI_PP_Shift`.
- Transactional root/projection: `ZR_PP_Shift` → `ZC_PP_Shift_Adm` (managed RAP draft; create/update, không hard-delete).
- Service definition: `ZUI_PP_SHIFT_ADM`.
- Service binding: `ZUI_PP_SHIFT_ADM_O4`, OData V4 UI.
- Main entity: `Shifts`; `PlantValueHelp` chỉ phục vụ chọn nhà máy.
- Metadata extension: `ZC_PP_SHIFT_ADM`, gồm danh sách, bộ lọc, facet chi tiết,
  nhãn tiếng Việt, tìm kiếm mã/tên ca và text trạng thái.

Activate consumption view và metadata, service definition, rồi binding trong ADT.
Publish binding trên tenant đích và lấy URL thực tế từ binding; trạng thái publish
không được coi là đã triển khai chỉ vì có file trong Git.
Khi tạo app Fiori elements List Report/Object Page, chọn service riêng này và
main entity `Shifts`. App cho phép tạo/sửa trong draft, sau đó Save để activate hoặc
Discard để bỏ thay đổi. Không expose hard-delete; dùng `IsActive = 'I'` để ngừng hiệu lực.

Service mobile cũ vẫn expose `ZI_PP_Shift` để giữ value help và tương thích API;
app ca làm việc mới không phụ thuộc vào các entity phân bổ đó.
Không xóa hay tạo lại bảng để thêm service này; dữ liệu ca hiện có được dùng nguyên trạng.

ZTB_PP_SHIFT có khóa CLIENT/PLANT/SHIFT_ID/VALID_FROM, cùng SHIFT_NAME,
START_TIME, END_TIME, END_DAY_OFFSET (0 hoặc 1), TIME_ZONE, VALID_TO, IS_ACTIVE (A/I).
Năm trường audit managed RAP là CREATED_BY, CREATED_AT, LAST_CHANGED_BY,
LAST_CHANGED_AT và LOCAL_LAST_CHANGED_AT. `ZTD_PP_SHIFT` lưu bản nháp và chứa
standard include `SYCH_BDL_DRAFT_ADMIN_INC`. `LastChangedAt` là total ETag;
`LocalLastChangedAt` là entity ETag để kiểm soát cập nhật đồng thời.
TIME_ZONE phải là khóa múi giờ SAP được cấu hình trong tenant, không phải tự điền chuỗi IANA.
Ca cùng ngày phải có giờ kết thúc lớn hơn giờ bắt đầu; ca qua ngày dài tối đa 24 giờ.

ZI_PP_Shift được expose tên `Shifts` trong `ZUI_PP_OPALLOC`; danh mục ca dành cho Fiori admin dùng riêng `ZUI_PP_SHIFT_ADM`.
Entity này chỉ đọc, không có behavior create/update/delete.

```http
GET <service-root>/Shifts?$filter=Plant eq '1000' and IsActive eq 'A'&$orderby=ShiftID,ValidFrom
```

GET trả các phiên bản cấu hình, kể cả lịch sử, để app lựa chọn theo ngày làm việc.
App nên lưu danh mục khi có mạng để chọn ca lúc offline; backend kiểm tra lại lúc nhận request.
Không sửa giờ/múi giờ của phiên bản đã dùng: kết thúc hiệu lực phiên bản cũ và thêm phiên bản mới.
Giữ phiên bản cũ active trong thời gian còn nhận dữ liệu offline hợp lệ thuộc kỳ đó.
Nếu nhiều phiên bản của cùng Plant/ShiftID cùng khớp thời điểm, backend từ chối.

Class ZCL_PP_SHIFT_SETUP cung cấp mẫu ba ca 06–14, 14–22, 22–06.
Điền constants PLANT, TIME_ZONE và VALID_FROM theo thực tế rồi chạy F9 trong ADT.
Class không tự đoán nhà máy/múi giờ, không ghi đè phiên bản đã có.
Đây là cách khởi tạo cấu hình, không phải màn quản trị lịch nhân viên.

## Action giao/chuyển/thu hồi/xác nhận

Cả bound action và submit action nhận thêm ShiftID và ExecutedAt.
ExecutedAt là thời điểm thực hiện thực tế UTC, không phải thời điểm gửi hoặc đồng bộ.
Ví dụ bổ sung vào payload submitConfirm hiện có:

```json
{
  "ShiftID": "NIGHT",
  "ExecutedAt": "2026-09-07T19:00:00Z",
  "ExecutionDate": "2026-09-07"
}
```

Các trường xác thực, lệnh, công đoạn, nhân công, số lượng, đơn vị và SyncItemUUID
vẫn bắt buộc theo contract hiện có. ExecutionDate nếu gửi phải bằng ngày bắt đầu ca;
nếu để initial, resolver xác định từ ExecutedAt. Không gửi ngày lịch 08/09 cho ví dụ trên.

Backend xác định Plant từ operation, tra cấu hình và lưu snapshot vào ledger:
SHIFT_ID, WORK_DATE, EXECUTED_AT, SHIFT_START_AT, SHIFT_END_AT,
SHIFT_TIME_ZONE, SHIFT_VALID_FROM.
EXECUTION_DATE được ghi bằng WORK_DATE để giữ tương thích với consumer hiện có.
CREATED_AT vẫn biểu thị thời điểm ghi nhận trên server.

Nếu ShiftID và ExecutedAt cùng initial, request cũ vẫn dùng ExecutionDate:
không suy đoán ca cho dữ liệu cũ. Nếu chỉ có một trong hai trường mới, request bị từ chối.
Khi chuyển app sang version mới, kiểm tra lại payload OData sau khi refresh metadata;
có thể cần gửi trường mới với giá trị initial theo khả năng nullable của binding.
Request mới có timestamp tương lai bị từ chối. Đồng bộ muộn không làm đổi ca.

Replay cùng SyncItemUUID sử dụng snapshot đã ghi nhận, không tính lại theo cấu hình mới.
Thay ca/thời điểm hoặc các dữ liệu nghiệp vụ với cùng khóa bị từ chối bởi idempotency checks.
Các kiểm tra quyền, worker và operation hiện có vẫn áp dụng cả khi retry.

## Lịch sử, hủy và điều chỉnh

getWorkHistory nhận thêm ShiftID. Để xem ca đêm ngày 07/09, dùng:

```json
{
  "RangeCode": "C",
  "DateFrom": "2026-09-07",
  "DateTo": "2026-09-07",
  "ShiftID": "NIGHT",
  "SummaryOnly": false
}
```

Bổ sung AccessToken/DeviceID theo contract hiện có.
RangeCode D vẫn là ngày hệ thống hiện tại; lúc sau nửa đêm muốn xem ca đêm đang làm
thì app phải gửi custom range là ngày bắt đầu ca, không dùng D.
Không chọn ShiftID thì báo cáo tổng hợp các ca; dữ liệu cũ không có ca vẫn được tính.
SQL lọc WORK_DATE, fallback EXECUTION_DATE khi WORK_DATE initial.
Entries và getSyncStatus trả thêm các field snapshot ca.

Reverse/correctConfirm kế thừa ca, WorkDate, ExecutionDate và snapshot của CONFIRM gốc;
CreatedAt của dòng điều chỉnh ghi thời điểm điều chỉnh. ExecutedAt được kế thừa để phản ánh
lần thực hiện sản xuất gốc, không phải thời điểm nhấn điều chỉnh.
Team history lần theo chuỗi giao dịch gốc để bao gồm correction/reversal;
correction được cộng theo delta và reverse trừ sản lượng hiệu lực.

ZTB_PP_EMP_ALLOC giữ số dư nhân công/công đoạn xuyên ca.
RemainingQuantity trong báo cáo vẫn là giao trừ hoàn thành trong khoảng lọc,
không phải số dư tích lũy toàn bộ. Nếu giao ở ca trước và làm ở ca sau thì số này có thể âm;
app cần phân biệt chỉ tiêu kỳ với số dư thực tế từ bảng phân bổ.

## Triển khai và kiểm chứng

1. Activate `ZTB_PP_SHIFT`, `ZTD_PP_SHIFT` và phần mở rộng `ZTB_PP_ALLOC_TXN`.
2. Activate `ZI_PP_Shift`, `ZR_PP_Shift`, `ZR_PP_AllocTxn`, abstract entities thay đổi và các BDEF root.
3. Activate behavior pool `ZBP_R_PP_SHIFT`, `ZCL_PP_SHIFT_RESOLVER`, `ZCL_PP_WORK_HISTORY` và behavior implementation phân bổ.
4. Activate projection behavior, admin projection/metadata và hai service definitions; cập nhật binding/metadata app.
5. Chạy ABAP Unit cho ZCL_PP_SHIFT_RESOLVER và ZCL_PP_WORK_HISTORY trong ADT.
6. Khởi tạo cấu hình đúng nhà máy/múi giờ, thử GET Shifts rồi thử các thời điểm trong bảng ví dụ.
7. Xác nhận offline, retry cùng khóa, đổi timestamp khi retry, hủy/điều chỉnh ngày hôm sau
   và kiểm tra tổng hợp team/cá nhân vẫn phản ánh đúng ca gốc.

Không tự backfill ca cho ledger cũ vì không có thời điểm thực hiện đáng tin cậy.
Các unit test kiểm tra biên giờ, ngày hiệu lực, legacy input, tổng correction/reverse
và chuỗi scope; cần chạy thực tế trên SAP, không coi kết quả lint là kết quả ABAP Unit.

Tham khảo: [SAP — chuyển đổi ngày/giờ theo múi giờ](https://help.sap.com/docs/ABAP_Cloud/abap-cloud-docs_abap-keyword-documentation_abap-for-cloud-development/abapconvert_date_time-stamp.html).
