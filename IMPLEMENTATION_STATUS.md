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
- Mobile RBAC layer:
  - Tables `ZTB_MOB_FUNC`, `ZTB_MOB_ROLE`, `ZTB_MOB_ROL_FNC`,
    `ZTB_MOB_USR_ROL`.
  - Root BOs `ZI_MOB_Func` and `ZI_MOB_Role` (`ZBP_I_MOB_FUNC`,
    `ZBP_I_MOB_ROLE`), with `ZI_MOB_RolFunc` as composition child of the role
    and `ZI_MOB_UsrRol` as composition child of `ZI_MOB_User`.
  - Admin projections plus service `ZUI_MOB_RBAC_ADM`; the per-user role
    assignment is exposed on `ZUI_MOB_USER_ADM` next to the account itself.
  - `getPermissions` static action on the mobile auth service returns the
    effective function list for the token holder, so the app drives its menu
    from the same RBAC data the admin maintains.

## CDS access control convention

Applied consistently across the MOB objects so that a new view has one obvious
choice instead of a per-object decision:

| Layer | Annotation | DCL |
| --- | --- | --- |
| Interface view, root (`ZI_*`) | `#NOT_REQUIRED` | none |
| Interface view, composition child | `#NOT_REQUIRED` | none |
| Admin projection, root (`ZC_*_Adm`) | `#MANDATORY` | full access rule |
| Admin projection, composition child | `#NOT_REQUIRED` | none |

Two deliberate exceptions, both on the mobile authentication path:

- `ZI_MOB_User` is `#MANDATORY` with a deny-all DCL, because `ZC_MOB_User`
  inherits its conditions and the auth service must expose actions only.
- `ZC_MOB_User_Adm` overrides that inherited deny with a full access rule; the
  real gate for the admin service is its IAM app / business catalog.

Composition children never get their own DCL. They are reached by navigation
from their root, which already carries the check, and `#MANDATORY` on a child
would only demand a rule that grants everything.

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

## Sync inbox status contract

`ZTB_PP_SYNC_H-SYNC_STATUS` and `ZTB_PP_SYNC_I-ITEM_STATUS` are free-form
`CHAR` fields. The accepted values are fixed here so that the mobile client
and the backend do not invent their own spelling per call site.

Header (`SYNC_STATUS`):

| Value | Meaning |
| --- | --- |
| `QUEUED` | Accepted and persisted, not picked up yet. |
| `IN_PROCESS` | A worker holds the header; `PROCESS_STARTED_AT` is set. |
| `SUCCESS` | Every item reached `SUCCESS`. |
| `PARTIAL` | Mixed outcome; see `SUCCESS_ITEMS` / `ERROR_ITEMS`. |
| `FAILED` | No item was applied. |
| `DEAD` | Retry budget exhausted, manual action required. |

Item (`ITEM_STATUS`): `QUEUED`, `SUCCESS`, `FAILED`, `DEAD`, same meaning per
row.

Retry rules, because they decide which status a row ends in:

- Transient failures (lock not granted, confirmation API timeout) raise
  `RETRY_COUNT` and set `NEXT_RETRY_AT`.
- Business validation failures (quantity exceeds the allocation ledger,
  unknown worker, closed operation) are permanent: set `FAILED` immediately
  and return the message. Retrying them only reproduces the same error.
- Exceeding the retry budget moves a row to `DEAD`.

`submitSync` is an accept-only contract: validate the token, check
idempotency, write the inbox as `QUEUED`, return. Business processing runs in
the background worker, so the app reads status back instead of inferring
success from the action response.

## Service exposure boundary

Creating accounts and assigning permissions are administrative operations and
are reachable from the Fiori apps only. The device-facing API carries
self-service operations and nothing else. The projection layer is what
enforces this: an operation that a projection does not declare cannot be
called through the service that exposes it, no matter what the underlying
business object allows.

| Service | Binding | Exposed operations |
| --- | --- | --- |
| `ZUI_MOB_AUTH` | mobile communication user | `login`, `logout`, `refresh`, `changePassword`, `getPermissions` |
| `ZUI_MOB_USER_ADM` | Fiori, IAM app | `createUser`, assign / change / remove a user's roles |
| `ZUI_MOB_RBAC_ADM` | Fiori, IAM app | maintain roles, functions, role-to-function grants |

Consequences that must stay true:

- `ZC_MOB_User` declares no `use update`, no `use action createUser` and no
  `_Roles` association. Adding any of them would put an administrative
  operation on the device API.
- `ZC_MOB_User` additionally reads nothing: it inherits the deny-all
  condition of `ZI_MOB_User`, so a GET on the auth service returns an empty
  set even for a valid communication user.
- `changePassword` is the one write a device may perform on its own account,
  and it acts only on the user behind the presented token.
- `getPermissions` is read-only and equally self-scoped: it resolves the
  token to a user and returns that user's own effective functions. It grants
  nothing and cannot see another account's assignments.
- A role assignment survives deactivating the role, but `getPermissions`
  counts active roles only, so setting `Status` to inactive revokes the
  functions immediately without touching the assignment rows.

## Required target-system checks

1. Confirm all built-in types and released objects in the tenant release.
2. Generate/adjust behavior-pool method signatures using ADT quick fixes.
3. Create database secondary indexes on tables owned by this repository:
   - `ZTB_PP_SYNC_H`: `MANDT + DEVICE_ID + EXTERNAL_ID` unique.
   - `ZTB_PP_SYNC_I`: `MANDT + SYNC_UUID + EXTERNAL_ITEM_ID` unique.
   - `ZTB_PP_OP_ALLOC`: `MANDT + PRODUCTION_ORDER + OPERATION_NO` unique.
   - `ZTB_PP_ALLOC_TXN`: `MANDT + SYNC_ITEM_UUID` unique, initial values
     excluded. Without it a worker that runs twice (retry after a timeout, a
     redelivered bgPF task) can post the same ledger row a second time.
     Application-level idempotency alone always leaves a race window; this
     index makes the duplicate physically impossible.
4. Confirm the released Production Order read interface used for live quantity,
   UoM, Plant, Work Center, TECO and CLSD checks.
5. Decide and verify `I_ProductionOrdConfirmationTP` versus
   `API_PROD_ORDER_CONFIRMATION_2_SRV`.
6. Bind the Fiori admin service to an IAM app/business catalog; enforce mobile
   authorization through token validation in the sync entry point.
7. Keep the service bindings separated per audience. The communication
   arrangement used by the mobile device must contain the `ZUI_MOB_AUTH`
   binding and nothing else. Adding `ZUI_MOB_USER_ADM` or `ZUI_MOB_RBAC_ADM`
   to the same communication scenario would hand the device user
   `createUser` and role assignment - the code cannot prevent that, because
   authorization is granted per business object, not per service.

## Next implementation slice

1. Implement `initialAssign` atomically with balance and ledger creation.
2. Add ABAP Unit tests for capacity and worker validity rules.
3. Implement `transfer`, including auto-create of the target employee balance.
4. Build the Sync Inbox RAP BO and `submitSync` idempotency flow, together
   with a read-only projection over the inbox. The action result cannot
   report a partial batch on its own, so the app needs a status read path.
5. Run the bgPF per-header versus per-item PoC.
