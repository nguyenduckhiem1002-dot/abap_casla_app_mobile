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
4. Các commit sau sẽ bổ sung CDS/RAP theo đúng thứ tự dependency.

## abapGit repository layout

This folder is also prepared as a standalone abapGit repository:

```text
abap/
├── .abapgit.xml
├── src/          # design/ADT source drafts; ignored by abapGit deserializer
└── serialized/   # object metadata chuẩn để abapGit deserialize
```

`.abapgit.xml` dùng `/serialized/` làm `STARTING_FOLDER`. Thư mục này hiện có
`package.devc.xml` và 5 object `*.tabl.xml` hợp lệ. Các file trong `/src/` là
source thiết kế, không tham gia deserialize.

## Current milestone

- Persistence tables (`ZTB_PP_OP_ALLOC`, `ZTB_PP_EMP_ALLOC`,
  `ZTB_PP_ALLOC_TXN`, `ZTB_PP_SYNC_H`, `ZTB_PP_SYNC_I`)
- Worker validation reference view
- RAP action parameter entities
- Domain interface/projection CDS and behavior definitions

The bgPF worker, SAP production confirmation adapter, APJ recovery job, and
authorization implementation require target-tenant released-object checks and
are intentionally implemented after the base BO activates successfully.
