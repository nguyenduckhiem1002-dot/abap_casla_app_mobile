# Implementation status

This document records what is actually implemented in the repository. It intentionally separates **internal domain logic** from **device-exposed API** so an implemented behavior method is not mistaken for a public mobile endpoint.

## Current milestone

### Authentication and session

Implemented:

- `createUser`, `login`, `logout`, `refresh`, `changePassword`.
- Password KDF/hash implementation shared through the security layer.
- Access/refresh token hashing; plaintext tokens are not persisted.
- Refresh-token rotation and session revocation.
- Failed-login rule aligned with the supplied flow: **5 failures inside 1 minute -> lock 10 minutes**.
- `LAST_FAIL_AT` persisted so the failure window is not an accumulated lifetime counter.
- Device-bound token validation.

### RBAC + Work Context

Implemented persistence:

- `ZTB_MOB_FUNC` – Function catalog.
- `ZTB_MOB_ROLE` – Role catalog.
- `ZTB_MOB_ROL_FNC` – Role -> Function.
- `ZTB_MOB_USR_ROL` – User -> Role.
- `ZTB_MOB_WORK` – Work Context master (`WorkID`, name, Plant, Work Center, department, location, active state).
- `ZTB_MOB_ROL_WRK` – Role -> Work Context N:M mapping.

Implemented RAP model:

```text
ZI_MOB_User
  +-- _Roles -> ZI_MOB_UsrRol

ZI_MOB_Role
  +-- _Functions       -> ZI_MOB_RolFunc
  +-- _WorkAssignments -> ZI_MOB_RolWork

ZI_MOB_Work
```

Rules:

- UserRole create validates that the target Role exists and is active.
- RoleWork create validates that the target Work Context exists and is active.
- Role value help returns active Roles only.
- Work value help returns active Work Contexts only.
- Value-help filtering is UX only; backend validation repeats the check.
- Role deactivation immediately removes its effective Functions and Work Contexts without deleting assignment rows.
- Work deactivation immediately removes its runtime scope without deleting RoleWork rows.
- Work master hard delete is denied; deactivate with `IsActive = 'I'`.

### User creation with initial Role

`ZA_MOB_CreateUser` now includes `RoleID`.

`createUser` requires an active initial Role and deep-creates in one RAP LUW:

```text
User
 + Credential
 + UserRole
```

Additional Roles are maintained through the `_Roles` composition on the same User Object Page.

### Effective Work Contexts at login/refresh

`ZA_MOB_LoginResult` contains two server-produced compositions:

- `_Permissions`
- `_WorkContexts`

`ZCL_MOB_TOKEN_VALIDATOR=>GET_WORK_CONTEXTS` resolves:

```text
UserRole
 -> active Role
 -> RoleWork
 -> active Work
```

The result is deduplicated by WorkID. It is display/selection data for the mobile app, not authorization proof.

`ZCL_MOB_TOKEN_VALIDATOR=>HAS_WORK_SCOPE` re-reads the database and checks exact `Plant + WorkCenter` for protected production mutations.

## Fiori Elements administration

The admin UX is consolidated into **two applications**, not one app per mapping table.

### User Administration

- Service: `ZUI_MOB_USER_ADM`
- OData V4 binding serialized in repo: `ZUI_MOB_USER_ADM_O4`
- Root entity set: `SupervisorAccounts`
- User Object Page facets:
  - account information;
  - Roles.
- `createUser` action dialog includes the initial Role.

### RBAC & Work Administration

- Service: `ZUI_MOB_RBAC_ADM`
- OData V4 binding serialized in repo: `ZUI_MOB_RBAC_ADM_O4`
- Root entity set: `Roles`
- Role Object Page facets:
  - Role information;
  - Functions;
  - Work Contexts.
- Work master is exposed by the same service and is intended as a secondary route/page in the same Fiori Elements application, not a third Launchpad tile.

See `docs/FIORI_ELEMENTS_ADMIN.md` for the target-tenant generation and publication steps.

The repository does not fabricate tenant-specific UI5 OData URLs, semantic objects or IAM catalogs. Generate/publish the two frontend shells from the activated bindings on the target tenant.

## Production allocation domain

Implemented persistence:

- `ZTB_PP_OP_ALLOC`
- `ZTB_PP_EMP_ALLOC`
- `ZTB_PP_ALLOC_TXN`
- `ZTB_PP_SYNC_H`
- `ZTB_PP_SYNC_I`

Implemented internally:

- `initialAssign`
- `transfer`
- `recall`

These actions include:

- token/device validation;
- worker validation;
- worker password verification;
- idempotency checks;
- duplicate-balance fail-closed behavior;
- quantity/UoM checks;
- transaction audit fields;
- **authenticated actor Work Context check by operation Plant + WorkCenter**.

`ActorUserUUID` is derived from the token/session. The client cannot supply the authenticated actor.

Worker verification audit stored in the transaction ledger includes:

- `VerifiedWorkerUserUUID`
- `WorkerVerifiedAt`
- `InitiatorSessionID`
- `DeviceID`
- `VerificationMethod`

### Mobile exposure boundary

`initialAssign`, `transfer` and `recall` are internal domain logic. They remain closed from the device projection so the mobile client cannot bypass the planned Sync Inbox/security boundary.

Global authorization denies direct external domain mutations; a future sync worker must invoke the domain behavior only after its own request/auth/idempotency processing succeeds.

## Confirm and Reverse

`confirm` and `reverse` remain **fail-closed**.

The repository does not yet contain a target-tenant-verified SAP Production Confirmation/reversal adapter. Writing local `CompletedQuantity` or a `POSTED` confirmation before SAP succeeds would create two conflicting production truths, so these actions must not be enabled yet.

## Work history

`getWorkHistory` is exposed through `ZUI_PP_OPALLOC` as a read-only token-scoped action.

RBAC scope:

| Function | Scope |
| --- | --- |
| `PP_HIST_TEAM` | Supervisor assignment roots + valid transaction descendants |
| `PP_HIST_SELF` | Rows involving the authenticated worker |

Only `POSTED` transaction ledger data is counted. `ZTB_KB_NHANCONG` through `ZI_PP_WorkerRef` enriches worker names; it does not decide historical ownership.

Supported ranges:

- `D` – today
- `W` – last 7 days
- `M` – last 30 days
- `C` – custom range, maximum 92 days per request

## CDS access-control convention

| Layer | Annotation | DCL |
| --- | --- | --- |
| Interface root/child (`ZI_*`) | normally `#NOT_REQUIRED` | none |
| Admin root projection (`ZC_*_Adm`) | `#MANDATORY` | full-access mapping role; real gate is IAM app/catalog |
| Admin composition child | `#NOT_REQUIRED` | none |

Deliberate auth-service exception:

- `ZI_MOB_User` is deny-all through DCL so the mobile auth service exposes actions but no account read surface.
- `ZC_MOB_User_Adm` is the IAM-protected admin projection.

## Service boundaries

| Service | Audience | Surface |
| --- | --- | --- |
| `ZUI_MOB_AUTH` | Mobile communication user | login/logout/refresh/changePassword |
| `ZUI_PP_OPALLOC` | Mobile communication user | operation read + `getWorkHistory` |
| `ZUI_MOB_USER_ADM` | Fiori/IAM | account + UserRole administration |
| `ZUI_MOB_RBAC_ADM` | Fiori/IAM | Role + Function + Work Context administration |

Never include the two admin bindings in the mobile communication scenario.

## Sync Inbox contract

Header statuses:

- `QUEUED`
- `IN_PROCESS`
- `SUCCESS`
- `PARTIAL`
- `FAILED`
- `DEAD`

Item statuses:

- `QUEUED`
- `SUCCESS`
- `FAILED`
- `DEAD`

Transient infrastructure failures may retry. Permanent business-validation failures fail immediately. Retry-budget exhaustion moves the item/header to `DEAD` as appropriate.

`submitSync` and the background-processing pipeline are not yet complete.

## Validation

Latest work-context branch validation:

```text
@abaplint/cli 2.120.35
ABAP language version: Cloud
0 issue(s) found, 191 file(s) analyzed
```

This run covered the Work Context RAP model and the runtime User/Role/Work + PP scope changes.

`abaplint` is not a substitute for target-system activation. Before deployment, deserialize and activate with ADT, run ATC/Cloud checks, then preview both OData V4 admin service bindings.

## Required target-system checks

1. Activate the new tables before CDS/BDEF objects:
   - `ZTB_MOB_WORK`
   - `ZTB_MOB_ROL_WRK`
2. Activate Role/User/Work interface and projection layers.
3. Deserialize/activate/publish:
   - `ZUI_MOB_USER_ADM_O4`
   - `ZUI_MOB_RBAC_ADM_O4`
4. Generate/publish only the two Fiori Elements admin apps described in `docs/FIORI_ELEMENTS_ADMIN.md`.
5. Protect admin bindings through the intended IAM business catalogs/business roles.
6. Create/verify required database indexes from `README.md`.
7. Seed active Function, Role and Work master data before assigning users.
8. Test create User + initial Role in one transaction.
9. Test add/remove User Roles, Role Functions and Role Work Contexts.
10. Test login/refresh returns correct effective Work Contexts after role/work activation changes.
11. Test `initialAssign`, `transfer` and `recall` reject a Plant/WorkCenter outside the authenticated actor's scope.
12. Keep `confirm`/`reverse` disabled until SAP integration is verified.

## Next implementation slice

1. Complete `submitSync` accept-only API and read-back status surface.
2. Complete the background worker/retry/dead-letter pipeline.
3. Define canonical external mutation Function IDs without guessing names.
4. Select and verify the released SAP Production Confirmation API on the target tenant.
5. Implement SAP confirmation/reversal adapters and integration tests.
6. Add ABAP Unit/integration tests for UserRole/RoleWork validation, work-scope enforcement, balance transitions and duplicate sync behavior.
