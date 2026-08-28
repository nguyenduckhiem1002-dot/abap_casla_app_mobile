# Fiori Elements administration

Repository cung cấp bốn bề mặt quản trị IAM-protected. User/Role mapping và Role/Function/Work mapping là composition child trong app cha; không tạo app rời cho từng mapping row.

## 1. User Administration

- Service: ZUI_MOB_USER_ADM
- Binding: ZUI_MOB_USER_ADM_O4
- Entity chính: Accounts / ZC_MOB_User_Adm
- Composition: _Roles / UserRoles

Chức năng:

- createUser: tạo User + Credential + optional initial Role trong một RAP LUW;
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

Work Context là cặp Plant + WorkCenter được kiểm tra exact khi mobile gọi PP command. Value help chỉ hỗ trợ UX; direct OData/EML vẫn bị validate backend.

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
- AllocationTransactions: ZC_PP_AllocTxn_Adm, query ledger read-only.

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

## 5. Service boundary

| Surface | Identity | Mutation |
| --- | --- | --- |
| ZUI_MOB_AUTH | mobile communication user + action validation | login/session/password self-service |
| ZUI_PP_OPALLOC | CASLA token/session/device | controlled production commands |
| ZUI_MOB_USER_ADM | SAP IAM | user + role administration |
| ZUI_MOB_RBAC_ADM | SAP IAM | role/function/work administration |
| ZUI_MD_CONGDOAN_ADM | SAP IAM | versioned master maintenance |
| ZUI_PP_ALLOC_ADM | SAP IAM | correction + audit read |

Không thêm admin service binding vào mobile communication scenario. Không expose generic update/delete cho ZTB_PP_EMP_ALLOC hoặc ZTB_PP_ALLOC_TXN.

## 6. Tenant setup checklist

1. Import và activate DDIC/CDS/BDEF/class theo dependency order.
2. Publish bốn OData V4 admin bindings.
3. Gán IAM business catalogs/roles theo từng trách nhiệm admin.
4. Tạo Fiori Elements shell từ binding thật trên tenant; không commit URL/semantic object giả vào backend repo.
5. Test create account + initial Role, mapping assignments, deactivate Role/Work, validity overlap, correction/audit và raw CRUD denial.
