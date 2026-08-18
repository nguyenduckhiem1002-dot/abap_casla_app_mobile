# ABAP RAP Mobile Production Sync

Source bundle for the ABAP RAP backend described in
[`ABAP_RAP_MOBILE_SYNC_PLAN.md`](docs/ABAP_RAP_MOBILE_SYNC_PLAN.md).

## Target

- SAP S/4HANA Cloud Public Edition
- ABAP for Cloud Development
- Managed RAP, non-draft
- OData V4 service binding

## Import bằng abapGit

1. Dùng package `ZPK_XNSL_SM_BACKEND` trên hệ DEV.
2. Liên kết package với repository này và nhánh `main`.
3. Pull, chọn transport phù hợp và activate các bảng `ZTB_PP_*`.
4. Activate theo thứ tự: bảng → abstract/interface CDS → projection CDS →
   behavior pool/BDEF → service definition.
5. Tạo service binding OData V4 trong ADT sau khi service definition activate.

## abapGit repository layout

This folder is also prepared as a standalone abapGit repository:

```text
abap/
├── .abapgit.xml
└── serialized/   # nguồn duy nhất để abapGit deserialize
```

`.abapgit.xml` dùng `/serialized/` làm `STARTING_FOLDER`. Thư mục này chứa
metadata và source theo cặp định dạng chuẩn của abapGit (`*.ddls.xml` +
`*.ddls.asddls`, `*.bdef.xml` + `*.bdef.asbdef`, `*.clas.xml` + `*.clas.abap`).
Không duy trì bản sao table trong `/src/`; việc này tránh hai định nghĩa DDIC
lệch nhau theo thời gian.

## External dependencies (không thuộc repo này)

| Object | Chủ sở hữu | Ràng buộc |
|---|---|---|
| `ZTB_KB_NHANCONG` | Package đối tác | Chỉ đọc; không sửa cấu trúc và không tạo index |

Repo không self-contained. Trước khi pull bằng abapGit, bảng trên phải tồn tại,
active và được release/cho phép truy cập từ package `ZPK_XNSL_SM_BACKEND` trên
tenant đích. Mọi truy cập của repo tới bảng này phải đi qua
`ZI_PP_WORKERREF`; không class hoặc CDS nào khác được tham chiếu trực tiếp.

## Tách service

- `ZUI_PP_OPALLOC`: nghiệp vụ phân bổ sản lượng.
- `ZUI_MOB_AUTH`: login, refresh, logout và đổi mật khẩu; entity không cho đọc.
- `ZUI_MOB_USER_ADM`: Fiori quản trị cấp tài khoản giám sát.

Mỗi service cần một OData V4 service binding riêng trên tenant. IAM app/business
catalog của `ZUI_MOB_USER_ADM` là lớp bắt buộc bảo vệ action `createUser`.

## Current milestone

- Persistence tables (`ZTB_PP_OP_ALLOC`, `ZTB_PP_EMP_ALLOC`,
  `ZTB_PP_ALLOC_TXN`, `ZTB_PP_SYNC_H`, `ZTB_PP_SYNC_I`)
- Worker validation reference view `ZI_PP_WORKERREF`
- RAP action parameter abstract entities
- Domain interface/projection CDS và behavior definitions
- Behavior pool `ZBP_R_PP_OPALLOC`
- Worker validator `ZCL_PP_WORKER_VALIDATOR`
- Service definition `ZUI_PP_OPALLOC`

The bgPF worker, SAP production confirmation adapter, APJ recovery job, and
authorization implementation require target-tenant released-object checks and
are intentionally implemented after the base BO activates successfully.
