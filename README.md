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
├── src/          # design/ADT source drafts; ignored by abapGit deserializer
└── serialized/   # object metadata chuẩn để abapGit deserialize
```

`.abapgit.xml` dùng `/serialized/` làm `STARTING_FOLDER`. Thư mục này chứa
metadata và source theo cặp định dạng chuẩn của abapGit (`*.ddls.xml` +
`*.ddls.asddls`, `*.bdef.xml` + `*.bdef.asbdef`, `*.clas.xml` + `*.clas.abap`).
Các file còn lại trong `/src/` chỉ là tài liệu thiết kế và không tham gia
deserialize.

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
