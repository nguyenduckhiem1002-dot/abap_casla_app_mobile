# Metadata và value help cho màn quản trị

## Thay đổi

- Dùng nhãn `Work ID` trên danh mục, phần gán chức danh và value help.
- Bổ sung nhãn tiếng Việt cho field trong projection, metadata extension và tham số/kết quả action.
- Bảng gán chức năng hiển thị tên chức năng và phân hệ bên cạnh mã.
- Role, function và work value help hỗ trợ tìm theo mã/tên.
- Bổ sung bộ lọc mặc định cho danh mục công đoạn, phân bổ và sổ giao dịch.

| Trường | Nguồn chọn | Nơi sử dụng |
| --- | --- | --- |
| Work ID | ZI_MOB_Work_VH, vị trí active | Gán vị trí cho chức danh |
| Chức danh | ZI_MOB_Role_VH, role active | Gán role, tạo tài khoản |
| Chức năng | ZI_MOB_Func_VH | Gán quyền chức năng |
| Nhân công | ZI_PP_Worker_VH, tham chiếu còn hiệu lực | Tài khoản, popup tạo tài khoản, lọc giao dịch |
| Nhà máy | I_Plant | Danh mục vị trí và màn PP |
| Work Center | ZI_MOB_WorkCenter_VH từ I_WorkCenter | Danh mục vị trí và màn PP; lọc theo Plant |
| Mã công đoạn | ZI_MD_CongDoan_VH, master còn hiệu lực | Màn phân bổ và sổ giao dịch |
| Đơn vị tính | I_UnitOfMeasure | Màn PP và popup điều chỉnh |

Các view nhân công/công đoạn giữ thông tin phân biệt bản ghi khi một mã có nhiều
ngữ cảnh hoặc khoảng hiệu lực. Chọn nhân công chỉ trả WorkerID; không tự ghi đè họ tên tài khoản.
Danh sách công đoạn hiện hành có thể không chứa mã đã hết hiệu lực trong lịch sử;
người dùng vẫn có thể nhập mã để lọc dữ liệu cũ.

Các trường nhập tự do (tên, email, lý do, địa điểm), UUID kỹ thuật, ngày và số lượng
không được gắn danh sách chọn tùy tiện. Mã trạng thái/loại giao dịch vẫn giữ contract hiện có;
chưa bổ sung danh mục mã và mô tả riêng cho các trường này.

## Activate và kiểm tra

1. Activate các CDS value help mới và cập nhật:
   ZI_PP_Worker_VH, ZI_MD_CongDoan_VH, ZI_MOB_WorkCenter_VH,
   ZI_MOB_Work_VH, ZI_MOB_Role_VH, ZI_MOB_Func_VH.
2. Activate projection, abstract entity và metadata extension thay đổi.
3. Activate service definitions ZUI_MOB_RBAC_ADM, ZUI_MOB_USER_ADM,
   ZUI_MOB_AUTH, ZUI_PP_ALLOC_ADM, ZUI_PP_OPALLOC và cập nhật binding tương ứng.
4. Mở lại app; thử tạo dòng gán Work ID/FuncID/RoleID, tìm theo tên;
   thử chọn Plant rồi kiểm tra Work Center được lọc; thử popup tạo user và điều chỉnh sản lượng.
5. Kiểm tra metadata service có ValueList và entity set tương ứng.

abaplint kiểm tra tĩnh; không thay thế activation CDS, quyền truy cập danh mục chuẩn
và kiểm thử Fiori trên tenant SAP. Cần xác nhận I_Plant và I_UnitOfMeasure được
release cho use case trên tenant đích.

Nguồn: [SAP — Consumption annotations](https://help.sap.com/docs/CP/c0d02c4330c34b3abca88bdd57eaccfc/d60c0bf6798a481fb7412bc89934cb8a.html),
[SAP — Work Center](https://help.sap.com/docs/SAP_S4HANA_CLOUD/c0c54048d35849128be8e872df5bea6d/c90e05a792674f7d8bbae247c5200999.html).
