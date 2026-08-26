# Implementation status

This file records the implementation that exists in the repository. It deliberately distinguishes mobile custom APIs, internal RAP domain actions and IAM-protected Fiori administration.

## Current architecture

CASLA records production-allocation business state in custom Z tables hosted on SAP. There is **no standard SAP Production Confirmation adapter** in this business flow and there is **no SAP-side sync queue/background worker**.

Mobile handles offline/pending/retry. SAP exposes direct idempotent commands plus reconciliation by `SyncItemUUID`.

## Authentication/session

Implemented:

- create user, login, logout, refresh, change password;
- hashed access/refresh tokens; plaintext tokens are not persisted;
- refresh-token rotation and session revocation;
- device-bound token validation;
- failed-login rule: 5 failures inside 1 minute -> lock 10 minutes;
- password change can revoke active sessions.

Every post-login mobile production API validates access token + active session + device. Authenticated `ActorUserUUID` is derived server-side; it is not accepted from the client payload.

## RBAC + Work Context

Implemented persistence:

- `ZTB_MOB_FUNC`
- `ZTB_MOB_ROLE`
- `ZTB_MOB_ROL_FNC`
- `ZTB_MOB_USR_ROL`
- `ZTB_MOB_WORK`
- `ZTB_MOB_ROL_WRK`

Effective Work Context is resolved from active UserRole -> active Role -> RoleWork -> active Work and is checked by exact `Plant + WorkCenter` for protected PP mutations.

There is no shift/end-time/60-minute assignment rule. Assignment may remain open for days or weeks.

## Fiori identity/RBAC administration

Implemented:

- `ZUI_MOB_USER_ADM` / `ZUI_MOB_USER_ADM_O4`
- `ZUI_MOB_RBAC_ADM` / `ZUI_MOB_RBAC_ADM_O4`

User creation requires an active initial Role and creates User + Credential + initial UserRole in one RAP LUW. Additional Role/Function/Work mappings are maintained as create/delete assignments, not by updating mapping keys.

## Production-order live guard

Implemented `ZCL_PP_OPERATION_GUARD`.

Before a command mutates custom allocation data it resolves the SAP operation from the business keys supplied by mobile:

```text
ProductionOrder + Operation
```

Checks:

- `I_ManufacturingOrderStatus`: REL active; TECO/CLSD/DLFL blocked;
- `I_ManufacturingOrderOperation`: match `ManufacturingOrderOperation_2`;
- `OperationControlProfile = YBP1`;
- operation must not be marked for deletion;
- `OperationStandardTextCode` must exist;
- Plant, Work Center, planned quantity and UoM must be resolvable;
- `I_WorkCenter` resolves Work Center code.

`OperationStandardTextCode` is saved as `ZTB_PP_OP_ALLOC-MA_CONGDOAN`.

## Production allocation persistence

Implemented:

- `ZTB_PP_OP_ALLOC` – live-validated operation snapshot;
- `ZTB_PP_EMP_ALLOC` – current worker balance;
- `ZTB_PP_ALLOC_TXN` – append-only transaction/audit ledger.

Removed from the current architecture:

- `ZTB_PP_SYNC_H`
- `ZTB_PP_SYNC_I`
- `ZA_PP_SubmitSync*`
- SAP-side sync workflow/demo worker.

Balance invariant:

```text
Remaining
= InitialAssigned
+ TransferredIn
- TransferredOut
- Recalled
- Completed
```

## Domain actions

Implemented internal bound actions:

- `initialAssign`
- `transfer`
- `recall`
- `confirm`
- `reverse`
- `correctConfirm` (Fiori/IAM correction only)

Transaction types:

- `INITIAL_ASSIGN`
- `TRANSFER`
- `RECALL`
- `CONFIRM`
- `REVERSE`
- `CORRECTION`

Successful domain mutations update current balance and append a `POSTED` ledger transaction in the same RAP transaction boundary.

### Confirm

`confirm` is a CASLA custom-table operation:

```text
Completed += qty
Remaining -= qty
append CONFIRM
```

It validates token/session/device, work scope, worker, worker password, quantity/UoM and idempotency.

### Reverse

Current reverse implementation targets a prior POSTED `CONFIRM`:

- original transaction remains immutable;
- already-reversed confirmation is rejected;
- prior `CORRECTION` deltas are included when calculating the effective quantity;
- Completed/Remaining is restored;
- a new `REVERSE` row points to `OriginalTransactionUUID`.

### Controlled correction

`correctConfirm` changes an effective confirmation quantity only through a controlled action:

- validates original POSTED CONFIRM;
- rejects reversed confirmations;
- computes current effective quantity = original CONFIRM + CORRECTION deltas;
- validates new balance;
- updates current balance;
- appends a signed `CORRECTION` delta with ReasonCode/ReasonText and `SourceChannel = FIORI`.

No generic balance/ledger update is exposed by the Fiori service.

## Mobile command API

`ZUI_PP_OPALLOC` exposes the safe static facade actions through `ZC_PP_OpAlloc`:

- `submitInitialAssign`
- `submitTransfer`
- `submitRecall`
- `submitConfirm`
- `submitReverse`
- `getSyncStatus`
- `getWorkHistory`

The facade accepts `ProductionOrder + Operation`; mobile does not need to discover internal `OperationUUID`.

Employee balance and transaction ledger entity sets remain hidden from the mobile service.

## Idempotency and timeout reconciliation

Mobile creates a stable `SyncItemUUID` before sending a mutation.

Each bound mobile mutation checks existing ledger rows for that key:

- no row -> execute mutation;
- exactly one row with matching business payload -> idempotent replay/success;
- same key with different payload -> `IDEMPOTENCY_KEY_REUSED`;
- duplicate receipts -> fail closed with `SYNC_RECEIPT_DUPLICATE`.

`getSyncStatus(AccessToken, DeviceID, SyncItemUUID)` checks the authenticated actor's POSTED ledger receipt:

- `SUCCESS` -> backend proves the mutation committed;
- `NOT_FOUND` -> backend cannot prove a commit; this is **not** business FAILED.

Mobile should keep an ambiguous timeout as `UNKNOWN/PENDING_CONFIRMATION`, reconcile, then retry the exact same command/key if appropriate.

## Master Công đoạn

Implemented versioned master `ZTB_MD_CONGDOAN`:

```text
CLIENT + MA_CONGDOAN + VALID_FROM
```

Fields include name, department, `DONGIA_XM`, `DONGIA_GC`, `VALID_TO` and managed audit fields.

Validation:

- mandatory code/name/ValidFrom;
- ValidTo >= ValidFrom when supplied;
- nonnegative prices;
- no overlapping validity interval for the same MaCongDoan;
- hard delete denied.

Fiori:

- service `ZUI_MD_CONGDOAN_ADM`
- OData V4 binding `ZUI_MD_CONGDOAN_ADM_O4`

The master enriches SAP `OperationStandardTextCode`; it is for future wage/price reporting and is not a replacement for the live operation validation.

## Fiori Production Allocation Correction / Audit

Implemented:

- operation projection `ZC_PP_OpAlloc_Adm` with only `correctConfirm` mutation action;
- read-only ledger root `ZC_PP_AllocTxn_Adm`;
- service `ZUI_PP_ALLOC_ADM`;
- OData V4 binding `ZUI_PP_ALLOC_ADM_O4`.

The service is intended for IAM-protected Fiori administration and must not be added to the mobile communication scenario.

## Legacy ledger columns

`SAP_CONFIRMATION_GROUP`, `SAP_CONFIRMATION_COUNT`, `SAP_ERROR_CODE` and `SAP_ERROR_TEXT` remain in `ZTB_PP_ALLOC_TXN` for now to avoid an unnecessary destructive DDIC migration. They are legacy/misnamed fields and are not used as proof of a standard SAP Production Confirmation integration.

## Data model

The current table model and execution flows are documented in:

- `docs/CASLA_DATA_MODEL.drawio`
- `docs/ABAP_RAP_MOBILE_SYNC_PLAN.md`
- `docs/FIORI_ELEMENTS_ADMIN.md`

## Validation

The repository now contains `.github/workflows/abaplint.yml`, running:

```text
@abaplint/cli 2.120.35
ABAP language version: Cloud
```

GitHub static validation is a quality gate, not proof of target-tenant activation. Before deployment, deserialize/activate in ADT and run ATC/ABAP Cloud checks on the actual tenant.

## Target-system verification checklist

1. Activate new/changed DDIC tables before dependent CDS/BDEF artifacts.
2. Verify the target release exposes every SAP CDS field referenced by `ZCL_PP_OPERATION_GUARD`.
3. Activate/publish the four IAM admin bindings:
   - `ZUI_MOB_USER_ADM_O4`
   - `ZUI_MOB_RBAC_ADM_O4`
   - `ZUI_MD_CONGDOAN_ADM_O4`
   - `ZUI_PP_ALLOC_ADM_O4`
4. Protect admin bindings using intended IAM business catalogs/business roles.
5. Verify mobile communication setup exposes `ZUI_MOB_AUTH` and `ZUI_PP_OPALLOC`, not admin services.
6. Test session/device invalidation for every mobile command and status API.
7. Test idempotent retry after simulated response loss.
8. Test same SyncItemUUID + different payload is rejected.
9. Test initial assign / transfer / recall / confirm balance invariants.
10. Test Fiori correction followed by reverse and verify immutable lineage.
11. Test Master Công đoạn validity overlap and future effective versions.
