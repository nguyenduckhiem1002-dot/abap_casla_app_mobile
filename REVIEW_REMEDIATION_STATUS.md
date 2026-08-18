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
