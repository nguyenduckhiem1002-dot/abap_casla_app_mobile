# Job chuyển tồn phân công lúc 04:00

`ZCL_PP_REASSIGN_JOB` triển khai `IF_APJ_RT_RUN`. Job giữ cùng worker, đọc các
giao dịch `POSTED` của **ngày nghiệp vụ hôm qua**, ưu tiên `WorkDate`, fallback
`ExecutionDate` cho dữ liệu cũ. Nó không lấy toàn bộ `RemainingQuantity` tích lũy.

## Cách tính và tích hợp logic mới

Ngày D nhận số dư mở đầu từ các giao dịch ngày D-1:

```text
REASSIGN(D) = max(0,
  REASSIGN(D-1) + INITIAL_ASSIGN + TRANSFER_IN - TRANSFER_OUT
  - CONFIRM - RECALL + REVERSE - CORRECTION
  + ALLOC_ADJUST - RECALL_ADJUST - CONFIRM_ADJUST)
```

Các adjustment/correction lưu **delta có dấu**, không phải tổng số mới.
Job tính tách biệt từng operation–worker–UoM; lần giao bổ sung được quy về gốc
qua `OriginalTransactionUUID`, không phụ thuộc thứ tự SELECT. Snapshot giữ
`WorkID`, `ShiftID` của gốc, nên không gộp mất các nhóm mới thêm trong commit
`323a8c5`. Giao dịch từ ngày cũ chỉ được đọc để tìm gốc, không tự động đưa số
lượng cũ vào tồn nếu ngày hôm qua không có giao dịch hoặc REASSIGN tương ứng.

TRANSFER hiện không có liên kết tới lần giao của người chuyển. Các giảm trừ
không có gốc (transfer-out, adjustment) được trừ vào các nhóm của worker cùng
UoM theo ngày giao gốc rồi UUID. Tổng của worker được bảo toàn; phân bổ giảm
trừ giữa các nhóm là quy ước kỹ thuật, không chứng minh nhóm nào đã chuyển.
Muốn truy vết chính xác theo từng lần giao cần bổ sung lineage cho transfer.

REASSIGN là snapshot báo cáo, không làm tăng `InitialAssignedQuantity` hay
`RemainingQuantity`, và không phải một lần giao mới để tiêu thụ thêm capacity.
Các lệnh confirm/recall tiếp tục dùng giao dịch phân công gốc theo logic hiện có.
Không dùng UUID của dòng snapshot làm `OriginalTransactionUUID` cho command.
Snapshot trỏ về gốc để lịch sử team vẫn áp dụng kiểm tra lineage hiện tại.
Snapshot có `WorkDate/ExecutionDate = D`, `ExecutedAt = thời điểm job ghi`;
không giả tạo thời gian bắt đầu/kết thúc ca cho một giao dịch hệ thống.

Trong tổng quan, Giao cộng INITIAL_ASSIGN của khoảng chọn và tổng REASSIGN
(gồm các delta chạy lại) **chỉ ở ngày From**. REASSIGN giữa khoảng vẫn có trong
chi tiết nhưng không làm tổng Giao tăng lặp mỗi ngày. Các transfer, điều chỉnh,
xác nhận, thu hồi tiếp tục theo quy tắc tổng hợp hiện tại.

## Ghi dữ liệu và chạy lại

- Action `reassignOvernight` chỉ ở interface behavior, không expose trong mobile
  hoặc admin projection. Job gọi EML qua action để dùng khóa operation của RAP.
- Đọc transaction buffer sau khi lấy khóa; hai job chạy đồng thời không cùng
  vượt qua kiểm tra số đã ghi. Job bị lỗi khóa sẽ FAILED và có thể chạy lại.
- Mỗi operation là một LUW. Lỗi action hoặc commit sẽ rollback operation đó và
  làm job FAILED; các operation đã commit trước đó được giữ và chạy lại an toàn.
- Chạy lại cùng ngày so sánh số cần có với tổng REASSIGN đã ghi. Chênh lệch bằng
  0 không ghi thêm; thay đổi tạo delta mới, kể cả delta âm. Ledger cũ bất biến.
- Gốc bị thiếu, vòng tham chiếu, worker/UoM không khớp, hoặc loại giao dịch chưa
  hỗ trợ làm operation lỗi thay vì ghi một số tồn không kiểm chứng được.

## Thiết lập trên SAP

1. Import và activate `ZCL_PP_TXN_TYPE`, `ZA_PP_ReassignDay`, class job,
   `ZR_PP_OpAlloc`/behavior implementation và history trong cùng activation set.
   Class job và behavior tham chiếu lẫn nhau qua EML.
2. Trong ADT tạo **Application Job Catalog Entry**, chọn class
   `ZCL_PP_REASSIGN_JOB`, rồi tạo **Application Job Template** từ catalog đó.
3. Trong ứng dụng **Application Jobs**, chọn template, đặt lần chạy đầu
   **04:00**, lặp **hàng ngày**, không đặt ngày kết thúc nếu muốn chạy liên tục.
4. Cấu hình múi giờ của user chạy nền đúng ngày nghiệp vụ (ví dụ múi giờ Việt Nam
   được cấu hình trong SAP), và chọn cùng múi giờ khi đặt lịch. Class lấy ngày
   từ `cl_abap_context_info=>get_user_time_zone()`, không dùng ngày UTC của server.
5. Chỉ tạo một lịch cho cùng phạm vi client. Kiểm tra trạng thái job sau lần đầu.

Repository chứa mã nguồn; không có kết nối SAP trong workspace để tạo catalog,
template hay kích hoạt lịch thực tế. Class dùng interface `IF_APJ_RT_RUN` theo
[hướng dẫn Application Jobs của SAP](https://help.sap.com/docs/sap-btp-abap-environment/abap-environment/creating-abap-class-with-interface-if-apj-rt-run).

## Nhập muộn, ca đêm và ngày bị bỏ lỡ

Logic ca mới cho phép nhập muộn tới hết ngày ca kết thúc. Vì vậy **04:00 là thời
điểm chụp dữ liệu, không chứng minh hôm qua đã đóng sổ**. Job chỉ gồm các giao
dịch đã commit lúc nó đọc. Khi nhập muộn hoặc sửa dữ liệu cũ, cần chạy lại ngày
nhận tồn tương ứng rồi các ngày tiếp theo theo thứ tự tăng dần; job không tự
backfill mọi ngày cũ và không sửa ngày nghiệp vụ của giao dịch nguồn.

Trong một classrun/consumer ABAP nội bộ, có thể gọi (và xử lý `CX_APJ_RT_CONTENT`):

```abap
zcl_pp_reassign_job=>run( target_date = '20260924' ).
```

Ví dụ này tính lại tồn mở đầu ngày 24 từ ngày 23. Bỏ `target_date` để dùng ngày
hôm nay theo user nền. Nếu bỏ lỡ lịch, chạy bù các ngày thiếu trước khi chạy ngày
hiện tại; nếu lần đầu vận hành chỉ muốn tồn hôm qua thì không backfill ngày cũ.

## Kiểm tra

ABAP Unit trong `zcl_pp_reassign_job.clas.testclasses.abap` bao phủ giao bổ sung,
đảo/correction, thứ tự transaction, chạy lại sau nhập muộn, transfer giữa worker,
fallback ngày cũ, adjustment và lineage lỗi. Test history kiểm tra khoảng nhiều
ngày chỉ cộng opening balance ngày From. Cần chạy ABAP Unit và activate trên SAP;
abaplint tại workspace chỉ là kiểm tra tĩnh, không thay thế RAP runtime.

Đối chiếu tại workspace với commit `323a8c5`: abaplint **2.120.35** báo cùng
**8 lỗi có sẵn** ở baseline và bản sửa, không thêm diagnostic mới. Bộ deps
của abaplint chưa có `IF_APJ_RT_RUN`/`CX_APJ_RT_CONTENT`, nên phép so sánh dùng
khai báo chữ ký tối thiểu chỉ trong thư mục lint tạm, không đưa vào source SAP.
Chạy config nguyên bản sẽ báo thêm interface Application Job chưa được tooling biết.

Hai kiểm tra repository cũng fail ở baseline và bản sửa: `check_rap_patterns.py`
ở quy tắc key `MaCongDoan/ValidFrom`, `check_admin_metadata.py` ở label `Work ID`.
Những lỗi này thuộc code vừa pull và chưa được sửa trong thay đổi job.
ABAP Unit đã bổ sung vào source nhưng **chưa chạy**, do không có ABAP runtime.
