# Implementation status

## Implemented in this milestone

- Five custom persistence tables.
- `ZI_PP_WorkerRef` validation view over existing `ZTB_KB_NHANCONG`.
- Flat and deep abstract entities for RAP action contracts.
- Operation allocation composition tree:
  - `ZR_PP_OpAlloc`
  - `ZR_PP_EmpAlloc`
  - `ZR_PP_AllocTxn`
- Projection entities and projection behavior.
- Managed RAP interface behavior with root locking and ETag.
- Root validation and worker validation utility class.
- Service definition `ZUI_PP_OPALLOC`.
- Mobile authentication RAP foundation:
  - `ZI_MOB_User` composition with credential and sessions.
  - `ZC_MOB_User` API projection exposing actions only.
  - Managed BDEF and behavior pool `ZBP_I_MOB_USER`.
  - Abstract contracts for login, refresh, logout, create user and password change.
  - Token/session lookup helper `ZCL_MOB_TOKEN_VALIDATOR`.
  - `ZCL_MOB_HASHER` và `ZCL_MOB_SEC_CONFIG` được xây mới, không phụ thuộc
    implementation login cũ.
  - `ZTB_MOB_CONFIG` lưu cấu hình môi trường; không serialize giá trị secret.
  - Auth actions đã có implementation EML: `createUser`, `login`, `logout`,
    `refresh`, `changePassword`, failed-login lock và refresh-token rotation.

## Deliberately fail-closed

The following actions are declared but currently return an error message:

- `initialAssign`
- `transfer`
- `confirm`
- `reverse`

This prevents incomplete logic from changing production quantities. They will be
enabled incrementally after the base objects activate on the target tenant.
Global authorization also denies direct create/update/action calls. The future
sync worker must call the domain BO using privileged/local EML only after token,
idempotency and worker validation have succeeded.

## Required target-system checks

1. Confirm all built-in types and released objects in the tenant release.
2. Generate/adjust behavior-pool method signatures using ADT quick fixes.
3. Create database secondary indexes on tables owned by this repository:
   - `ZTB_PP_SYNC_H`: `MANDT + DEVICE_ID + EXTERNAL_ID` unique.
   - `ZTB_PP_SYNC_I`: `MANDT + SYNC_UUID + EXTERNAL_ITEM_ID` unique.
   - `ZTB_PP_OP_ALLOC`: `MANDT + PRODUCTION_ORDER + OPERATION_NO` unique.
4. Confirm the released Production Order read interface used for live quantity,
   UoM, Plant, Work Center, TECO and CLSD checks.
5. Decide and verify `I_ProductionOrdConfirmationTP` versus
   `API_PROD_ORDER_CONFIRMATION_2_SRV`.
6. Bind the Fiori admin service to an IAM app/business catalog; enforce mobile
   authorization through token validation in the sync entry point.

## Next implementation slice

1. Implement `initialAssign` atomically with balance and ledger creation.
2. Add ABAP Unit tests for capacity and worker validity rules.
3. Implement `transfer`, including auto-create of the target employee balance.
4. Build the Sync Inbox RAP BO and `submitSync` idempotency flow.
5. Run the bgPF per-header versus per-item PoC.
