# Mapping mã lỗi mobile – phân bổ và xác nhận sản lượng

Tài liệu này là hợp đồng mã lỗi giữa RAP service và mobile app. Mobile nên map theo
`code`, không map theo nội dung tiếng Việt của message. Với các action RAP bị lỗi,
backend hiện trả mã lỗi trong `%msg` của `reported`/`failed`; với static facade,
mã lỗi được forward từ bound action.

## Nguyên tắc xử lý trên mobile

| Nhóm | Cách hiển thị | Cho phép retry ngay? |
| --- | --- | --- |
| `*_INPUT_*`, `*_REQUIRED`, `*_MISMATCH` | Hiển thị lỗi tại field hoặc bước nhập liệu | Không, sửa dữ liệu rồi gửi lại |
| `*_AUTH_*`, `TOKEN_*`, `SESSION_*` | Yêu cầu xác thực lại hoặc đăng nhập lại | Có, sau khi xác thực lại |
| `*_NOT_ALLOWED`, `*_EXPIRED` | Hiển thị không có quyền/phân công | Không, đổi người hoặc nhờ quản lý cấp quyền |
| `*_NOT_FOUND`, `*_AMBIGUOUS` | Yêu cầu quét/chọn lại dữ liệu SAP | Có, sau khi chọn lại |
| `*_EXCEEDED`, `*_INSUFFICIENT`, `*_INCONSISTENT` | Hiển thị số dư hiện tại và yêu cầu nhập lại | Có, sau khi refresh |
| `*_DUPLICATE`, `ALREADY_*`, `IDEMPOTENCY_*` | Đồng bộ lại trạng thái; không tạo giao dịch mới | Không gửi lặp cùng request |
| `SHIFT_*`, `OUTSIDE_SHIFT` | Yêu cầu chọn đúng ca/ngày làm việc | Có, sau khi chọn lại |

## Authentication và session

| Code | Ý nghĩa | UI/action đề xuất |
| --- | --- | --- |
| `AUTH_FAILED` | Không thể xác thực request | Hiển thị lỗi chung, cho đăng nhập lại |
| `EMPTY_TOKEN` | Request không có access token | Xóa session cục bộ và đăng nhập lại |
| `TOKEN_INVALID_OR_EXPIRED` | Token không hợp lệ hoặc hết hạn | Refresh token hoặc đăng nhập lại |
| `DEVICE_MISMATCH` | Token không thuộc thiết bị hiện tại | Đăng nhập lại trên thiết bị này |
| `PASSWORD_CHANGE_REQUIRED` | Tài khoản phải đổi mật khẩu | Chuyển sang màn hình đổi mật khẩu |
| `USER_INACTIVE` | Tài khoản đã bị khóa/ngừng hoạt động | Không retry; báo quản trị |
| `WORKER_AUTH_FAILED` | Mật khẩu công nhân sai hoặc tài khoản công nhân không hợp lệ | Giữ màn hình xác nhận công nhân, cho nhập lại |

## Quyền quản lý và công nhân

| Code | Đối tượng | Ý nghĩa | UI/action đề xuất |
| --- | --- | --- | --- |
| `MANAGER_OPERATION_NOT_ALLOWED` | Quản lý | Quản lý không có function tương ứng tại WorkID/bộ phận công đoạn/Plant/Work Center | Ẩn hoặc khóa nút thao tác; yêu cầu chọn vị trí làm việc có quyền |
| `WORKER_OPERATION_NOT_ALLOWED` | Công nhân | Công nhân không có role WorkID phù hợp với bộ phận của công đoạn | Yêu cầu chọn công nhân khác hoặc cấp lại role |
| `WORKER_ASSIGNMENT_EXPIRED` | Công nhân | Bản ghi công nhân tại Plant/Work Center không hiệu lực trong ngày làm việc | Báo phân công hết hiệu lực; không retry mù |
| `MISSING_PERMISSION` | User | Thiếu function tổng quát được yêu cầu | Hiển thị không có quyền chức năng |
| `WORK_NOT_FOUND` | WorkID | WorkID không tồn tại hoặc không active | Mở lại value help/chọn WorkID khác |
| `WORK_CONTEXT_MISMATCH` | WorkID | WorkID không khớp Plant/Work Center của công đoạn | Yêu cầu quét lại QR hoặc chọn đúng vị trí |
| `WORK_OPERATION_MISMATCH` | WorkID | Vị trí làm việc không khớp dữ liệu operation | Không cho tiếp tục |
| `OPERATION_DEPARTMENT_MISMATCH` | WorkID/công đoạn | Bộ phận của WorkID khác bộ phận master công đoạn | Không cho tiếp tục; sửa cấu hình master |

## SAP manufacturing operation

| Code | Ý nghĩa | UI/action đề xuất |
| --- | --- | --- |
| `MANUFACTURING_ORDER_NOT_FOUND` | Không tìm thấy lệnh sản xuất | Báo QR/LSX không hợp lệ |
| `MANUFACTURING_OPERATION_NOT_FOUND` | Không tìm thấy công đoạn trong LSX | Yêu cầu quét lại |
| `MANUFACTURING_OPERATION_AMBIGUOUS` | LSX/công đoạn trả nhiều bản ghi không xác định | Báo quản trị xử lý dữ liệu SAP |
| `MANUFACTURING_ORDER_NOT_RELEASED` | LSX chưa được release | Không cho giao/xác nhận |
| `OPERATION_MARKED_FOR_DELETION` | Công đoạn đã bị đánh dấu xóa | Không cho thao tác |
| `OPERATION_CONTROL_PROFILE_REQUIRED` | Thiếu control profile | Báo dữ liệu cấu hình SAP |
| `OPERATION_CONTROL_PROFILE_INVALID` | Control profile không được phép cho flow | Không cho thao tác |
| `OPERATION_STANDARD_TEXT_REQUIRED` | Công đoạn thiếu mã chuẩn `OperationStandardTextCode` | Báo dữ liệu master công đoạn |
| `OPERATION_MASTER_NOT_FOUND` | Không tìm thấy master công đoạn nội bộ | Báo cấu hình `ztb_md_congdoan` |
| `OPERATION_MASTER_AMBIGUOUS` | Master công đoạn có nhiều dòng cùng hiệu lực | Báo quản trị xử lý ngày hiệu lực |
| `OPERATION_MASTER_DATA_INCOMPLETE` | Master công đoạn thiếu dữ liệu bắt buộc | Báo quản trị |

## Ca làm việc và thời gian

| Code | Ý nghĩa | UI/action đề xuất |
| --- | --- | --- |
| `SHIFT_AND_EXECUTED_AT_REQUIRED` | Thiếu mã ca và thời điểm thực hiện | Gửi đủ `ShiftID` và `ExecutedAt` |
| `EXECUTION_DATE_REQUIRED` | Thiếu ngày thực hiện khi không suy ra được từ timestamp | Bổ sung ngày hoặc timestamp |
| `SHIFT_CONFIG_INVALID` | Cấu hình ca không hợp lệ | Báo quản trị cấu hình ca |
| `SHIFT_CONFIG_AMBIGUOUS` | Có nhiều cấu hình ca cùng hiệu lực | Báo quản trị xử lý dữ liệu |
| `SHIFT_NOT_APPLICABLE` | Ca không áp dụng cho thời điểm thực hiện | Chọn ca đúng hoặc gửi lại timestamp |
| `SHIFT_WORK_DATE_MISMATCH` | Ngày làm việc không khớp ca, đặc biệt với ca qua nửa đêm | Dùng `WorkDate` backend trả về, không tự lấy ngày nhận sync |
| `OUTSIDE_SHIFT` | Thời điểm thực hiện nằm ngoài ca | Hiển thị ca/ngày làm việc hợp lệ |
| `EXECUTED_AT_IN_FUTURE` | Thời điểm thực hiện ở tương lai | Kiểm tra đồng hồ thiết bị và gửi lại |

## Dữ liệu, UoM và số dư

| Code | Ý nghĩa | UI/action đề xuất |
| --- | --- | --- |
| `UNIT_OF_MEASURE_MISMATCH` | UoM request khác UoM của operation/balance | Không tự đổi UoM; đọc lại UoM SAP rồi nhập lại |
| `OPERATION_QUANTITY_EXCEEDED` | Tổng giao vượt sản lượng công đoạn | Hiển thị sản lượng công đoạn và số còn có thể giao |
| `CONFIRM_QUANTITY_EXCEEDED` | Xác nhận vượt số dư công nhân | Refresh số dư rồi nhập lại |
| `SOURCE_BALANCE_INSUFFICIENT` | Nguồn chuyển/thu hồi không đủ số dư | Hiển thị số khả dụng hiện tại |
| `WORKER_BALANCE_NOT_FOUND` | Chưa có phân bổ cho công nhân | Không cho xác nhận/thu hồi trước khi giao |
| `WORKER_BALANCE_DUPLICATE` | Có nhiều balance cho cùng worker-operation | Dừng thao tác, báo quản trị |
| `REVERSE_BALANCE_INCONSISTENT` | Balance không nhất quán khi hoàn tác | Không retry mù; cần kiểm tra ledger |
| `CONFIRM_ORIGINAL_TRANSACTION_INVALID` | Giao dịch gốc không hợp lệ cho xác nhận | Chọn đúng giao dịch gốc |
| `CONFIRM_ORIGINAL_QUANTITY_EXCEEDED` | Xác nhận vượt số lượng còn dùng được của chính giao dịch gốc | Hiển thị số còn lại của giao dịch gốc |

## Idempotency và ledger

| Code | Ý nghĩa | UI/action đề xuất |
| --- | --- | --- |
| `SYNC_ITEM_REQUIRED` | Thiếu khóa idempotency offline | Tạo `SyncItemUUID` mới cho request mới |
| `SYNC_RECEIPT_DUPLICATE` | Một `SyncItemUUID` tạo nhiều receipt | Dừng và báo lỗi dữ liệu |
| `SYNC_RECEIPT_NOT_FOUND` | Chưa tìm thấy receipt sau khi dispatch | Query trạng thái, không tự tạo lại ngay |
| `IDEMPOTENCY_KEY_REUSED` | Cùng khóa nhưng payload khác request cũ | Tạo khóa mới sau khi người dùng xác nhận |
| `TRANSACTION_ALREADY_REVERSED` | Giao dịch đã hoàn tác | Cập nhật trạng thái local, không gửi lại |
| `NOTHING_TO_REVERSE` | Không có giao dịch hợp lệ để hoàn tác | Cập nhật lại lịch sử |
| `ORIGINAL_TRANSACTION_INVALID` | Giao dịch gốc không tồn tại/không thuộc flow | Chọn lại giao dịch |
| `ORIGINAL_TRANSACTION_TYPE_INVALID` | Loại giao dịch gốc không được phép | Không cho thao tác |
| `ORIGINAL_TRANSACTION_WORKER_MISMATCH` | Giao dịch gốc thuộc công nhân khác | Yêu cầu chọn đúng công nhân |

## Gợi ý model cho mobile

```dart
class SapBusinessError {
  final String code;
  final String message;
  final bool retryable;
  final String? field;
  final String? action;

  const SapBusinessError({
    required this.code,
    required this.message,
    required this.retryable,
    this.field,
    this.action,
  });
}
```

Mobile nên lưu cả `code` và message gốc vào log đồng bộ. `code` dùng cho điều hướng
và thiết kế UI; message chỉ dùng làm nội dung hiển thị/fallback, không dùng làm khóa
logic.

## Mã cũ cần chuyển tiếp

`WORK_CONTEXT_NOT_ALLOWED` và `WORKER_NOT_ALLOWED` là mã chung của phiên bản trước.
Backend mới không nên phát sinh thêm hai mã này. Mobile có thể giữ mapping tạm thời:

| Mã cũ | Mã mới ưu tiên |
| --- | --- |
| `WORK_CONTEXT_NOT_ALLOWED` | `MANAGER_OPERATION_NOT_ALLOWED` |
| `WORKER_NOT_ALLOWED` | `WORKER_OPERATION_NOT_ALLOWED` hoặc `WORKER_ASSIGNMENT_EXPIRED` tùy nguyên nhân |
