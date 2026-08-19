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
  - `ZA_MOB_LoginResult` is a deep abstract entity: `login` and `refresh`
    return the caller's effective functions in a `_Permissions` composition,
    so the app drives its menu from the same RBAC data the admin maintains
    without a second round trip.
  - `ZCL_MOB_TOKEN_VALIDATOR` owns the permission query
    (`get_permissions`, `has_function`) and accepts `required_func`, so the
    server-side check and the list shown to the device come from one query.

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

## Work history report

`getWorkHistory` on `ZR_PP_OpAlloc`, exposed through `ZC_PP_OpAlloc` on
`ZUI_PP_OPALLOC`. It is a read-only, token scoped query; the row filter lives
in ABAP because the mobile binding runs under one communication user, so CDS
access control cannot tell the end users apart.

Scope is decided by the caller's RBAC functions, never by anything the device
sends:

| Function | Scope | Rows returned |
| --- | --- | --- |
| `PP_HIST_TEAM` | supervisor | assignments/transfers booked by this account and posted descendants whose `OriginalTransactionUUID` points to that root |
| `PP_HIST_SELF` | worker | posted rows where the caller is the worker, the giver or the receiver |

Neither function present means `MISSING_PERMISSION`. A worker is resolved from
the account name, which is the worker id by convention; `Username` is therefore
`readonly` in the behaviour definition. A name that does not fit a worker id is
rejected with `WORKER_NOT_MAPPED` rather than truncated, since truncation would
silently point at somebody else's rows.

Both functions must exist as rows in `ZTB_MOB_FUNC` and be granted through a
role before anyone can open the screen.

### Where the numbers come from

Only transaction data: `ZTB_PP_ALLOC_TXN` joined to `ZTB_PP_OP_ALLOC`, counting
rows whose status is `POSTED`. The supervisor scope is lineage-based, not just
`OperationUUID + WorkerID`: two supervisors may assign the same worker on the
same operation, so every derived `CONFIRM` / `REVERSE` row must put the owning
assignment or transfer UUID in `OriginalTransactionUUID`. Missing lineage is
fail-closed and the row is not shown to a supervisor.

Per worker figures are folded in ABAP and keyed by `WorkerID + UoM` so values
with incompatible units are never added together:
`INITIAL_ASSIGN` adds to assigned, `TRANSFER` adds to the receiver and subtracts
from the giver, `CONFIRM` adds to completed, `REVERSE` subtracts from it, and
remaining is assigned minus completed. An unrecognised type is counted but not
booked, so introducing one later cannot quietly distort the figures.

`ZTB_KB_NHANCONG`, through `ZI_PP_WorkerRef`, supplies worker names and nothing
else. It never filters, so:

- a worker who moves to another work center keeps every past row, and the
  supervisor who booked the work still sees it;
- a worker who disappears from the partner table still appears in history, with
  a blank name rather than a lost row;
- names are picked from the master record valid on the day of the booking, so a
  rename reads correctly in old rows.

### Time filtering

`RangeCode` selects `D` today, `W` last 7 days, `M` last 30 days (the default,
also used for an unrecognised code) or `C` custom. A custom range may reach as
far back as wanted but may not span `max_custom_days` (92) or more, answering
`RANGE_TOO_WIDE`; an incomplete or inverted range answers `RANGE_INVALID`, and
a custom end date in the future answers `RANGE_IN_FUTURE`.
Reading stops at `max_scan_rows` (20000) with `IsTruncated` set, and the detail
list is capped at `max_entry_rows` (1000) - the per worker totals are computed
before that cap. `SummaryOnly` is phrased so that its initial value returns the
detail list, because an unsent boolean cannot be told apart from `false`.

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
| `ZUI_MOB_AUTH` | mobile communication user | `login`, `logout`, `refresh`, `changePassword` |
| `ZUI_MOB_USER_ADM` | Fiori, IAM app | `createUser`, assign / change / remove a user's roles |
| `ZUI_MOB_RBAC_ADM` | Fiori, IAM app | maintain roles, functions, role-to-function grants |
| `ZUI_PP_OPALLOC` | mobile communication user | read operation headers; `getWorkHistory` |

Consequences that must stay true:

- `ZC_MOB_User` declares no `use update`, no `use action createUser` and no
  `_Roles` association. Adding any of them would put an administrative
  operation on the device API.
- `ZC_MOB_User` additionally reads nothing: it inherits the deny-all
  condition of `ZI_MOB_User`, so a GET on the auth service returns an empty
  set even for a valid communication user.
- `changePassword` is the one write a device may perform on its own account,
  and it acts only on the user behind the presented token.
- The function list inside `ZA_MOB_LoginResult` is self-scoped: it is
  resolved from the token, never from anything the caller sends, and shows
  only that account's own functions.
- That list is **display data, not an authorization decision**. A device can
  replay, edit or fabricate it, so no backend path may read it back. Every
  protected operation calls
  `zcl_mob_token_validator=>validate_token( ... required_func = '<FUNC>' )`,
  which re-reads the grants and returns `MISSING_PERMISSION` when the caller
  lacks the function. `has_function` is available where a token has already
  been validated.
- A role assignment survives deactivating the role, but the permission query
  counts active roles only, so setting `Status` to inactive revokes the
  functions immediately without touching the assignment rows - on the next
  `refresh` for what the app displays, and on the very next call for what the
  backend enforces.

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
   - `ZTB_PP_ALLOC_TXN`: `MANDT + ACTOR_USER_UUID + TRANSACTION_TYPE +
     TRANSACTION_STATUS + EXECUTION_DATE` for supervisor scope roots.
   - `ZTB_PP_ALLOC_TXN`: `MANDT + OPERATION_UUID + WORKER_ID + EXECUTION_DATE +
     TRANSACTION_STATUS` for scoped descendants.
   - If worker self-history is slow on production volume, add the same
     date/status suffix separately for `FROM_WORKER_ID` and `TO_WORKER_ID`;
     the self query checks all three worker columns so transfers cannot vanish.
4. Confirm the released Production Order read interface used for live quantity,
   UoM, Plant, Work Center, TECO and CLSD checks.
5. Decide and verify `I_ProductionOrdConfirmationTP` versus
   `API_PROD_ORDER_CONFIRMATION_2_SRV`.
6. Bind the Fiori admin service to an IAM app/business catalog; enforce mobile
   authorization through token validation in the sync entry point.
7. After publishing `ZUI_PP_OPALLOC`, confirm the metadata contains no
   `EmployeeAllocations`, `AllocationTransactions`, `_Employees` or
   `_Transactions`. The child consumption projections were deleted, and the
   associations/child behaviors were removed from the root projection; the
   report action is the only worker-level read path. The internal `ZR_*`
   entities remain for the future sync worker.
8. Create the `PP_HIST_TEAM` and `PP_HIST_SELF` rows in `ZTB_MOB_FUNC` and
   grant them through the supervisor and worker roles. Without the grant the
   history screen answers `MISSING_PERMISSION` for everyone.
9. Keep the service bindings separated per audience. The communication
   arrangement used by the mobile device may contain only the device-facing
   bindings: `ZUI_MOB_AUTH` and `ZUI_PP_OPALLOC`. Never add
   `ZUI_MOB_USER_ADM` or `ZUI_MOB_RBAC_ADM` to that scenario: doing so would
   hand the device user `createUser` and role assignment. Code cannot repair
   a binding/IAM mistake because authorization is granted per business object,
   not per service URL.

## Next implementation slice

1. Implement `initialAssign` atomically with balance and ledger creation.
2. Add ABAP Unit tests for capacity and worker validity rules.
3. Implement `transfer`, including auto-create of the target employee balance.
4. Build the Sync Inbox RAP BO and `submitSync` idempotency flow, together
   with a read-only projection over the inbox. The action result cannot
   report a partial batch on its own, so the app needs a status read path.
5. Run the bgPF per-header versus per-item PoC.
