# CASLA – Fiori Elements Administration

The ABAP backend currently provides four IAM-protected administration surfaces. User/Role mapping tables remain compositions inside their parent apps; they are not separate Launchpad apps.

## 1. User Administration

**Service:** `ZUI_MOB_USER_ADM`  
**OData V4 binding:** `ZUI_MOB_USER_ADM_O4`  
**Main entity:** `SupervisorAccounts`

Recommended pattern: **List Report + Object Page**.

`createUser` collects Username, password, FullName, email, WorkerID and an initial active Role. Backend deep-creates User + Credential + initial UserRole in one RAP LUW.

Additional Roles are maintained through the `_Roles` composition on the same User Object Page.

Do not expose credential/session entities to the mobile production service.

## 2. RBAC & Work Administration

**Service:** `ZUI_MOB_RBAC_ADM`  
**OData V4 binding:** `ZUI_MOB_RBAC_ADM_O4`  
**Main entity:** `Roles`

Recommended pattern: **List Report + Object Page**.

Role Object Page sections:

1. Role information.
2. `_Functions` – Role -> Function assignments.
3. `_WorkAssignments` – Role -> Work Context assignments.

The same service exposes Function and Work master pages as secondary routes. Do not create separate apps for `UserRole`, `RoleFunction` or `RoleWork` mapping rows.

Work hard delete is denied; retire a Work Context with `IsActive = 'I'`.

## 3. Master Công đoạn

**Service:** `ZUI_MD_CONGDOAN_ADM`  
**OData V4 binding:** `ZUI_MD_CONGDOAN_ADM_O4`  
**Main entity:** `CongDoan`

Purpose: maintain versioned business enrichment for SAP `OperationStandardTextCode`.

Business key:

```text
MaCongDoan + ValidFrom
```

Fields include:

- MaCongDoan
- TenCongDoan
- BoPhan
- DonGiaXM
- DonGiaGC
- ValidFrom
- ValidTo

Backend rules:

- no negative rates;
- ValidTo >= ValidFrom;
- same MaCongDoan cannot have overlapping validity intervals;
- hard delete denied.

This master is intended for future wage/price reporting. It does not authorize or validate a Production Order/Operation; the PP API still validates SAP live data independently.

## 4. Production Allocation Correction & Audit

**Service:** `ZUI_PP_ALLOC_ADM`  
**OData V4 binding:** `ZUI_PP_ALLOC_ADM_O4`

Entity sets:

- `OperationAllocations` – operation snapshot and controlled action `correctConfirm`;
- `AllocationTransactions` – read-only transaction ledger/audit list.

This app exists because users may discover that a previously confirmed quantity was entered incorrectly.

### Security rule

There is deliberately no generic update for `ZTB_PP_EMP_ALLOC` and no update/delete for `ZTB_PP_ALLOC_TXN`.

The supported correction flow is:

```text
Find the CONFIRM transaction in AllocationTransactions
        ↓
Open/select the corresponding OperationAllocation
        ↓
correctConfirm(
  TransactionUUID,
  NewQuantity,
  UnitOfMeasure,
  ReasonCode,
  ReasonText
)
        ↓
Backend validates current effective quantity and balance
        ↓
Update current balance
        +
Append immutable CORRECTION transaction
```

If a CONFIRM has already been reversed, correction is rejected.

`CORRECTION.Quantity` is the signed delta from the prior effective quantity, which allows exact audit reconstruction.

Examples:

```text
CONFIRM 100
CORRECTION -20  -> effective 80
CORRECTION +10  -> effective 90
```

The Fiori action uses SAP IAM/business-user context. It does not accept a mobile CASLA `ActorUserUUID`; standard RAP audit fields record the SAP user responsible for the Fiori change.

## 5. Mobile vs Fiori service boundary

| Surface | Audience | Mutation model |
| --- | --- | --- |
| `ZUI_MOB_AUTH` | Mobile communication user | login/session actions |
| `ZUI_PP_OPALLOC` | Mobile communication user | token-guarded command/status/history actions |
| `ZUI_MOB_USER_ADM` | Fiori IAM | controlled User/Role administration |
| `ZUI_MOB_RBAC_ADM` | Fiori IAM | Role/Function/Work administration |
| `ZUI_MD_CONGDOAN_ADM` | Fiori IAM | versioned Công đoạn master |
| `ZUI_PP_ALLOC_ADM` | Fiori IAM | controlled quantity correction + read-only audit |

Never put an admin service binding into the mobile communication scenario.

Likewise, the mobile service must not expose raw EmployeeAllocation or AllocationTransaction entity sets.

## 6. Value helps and backend validation

| Service | Value help | Purpose |
| --- | --- | --- |
| `ZUI_MOB_USER_ADM` | `RoleValueHelp` | Initial/additional Role |
| `ZUI_MOB_RBAC_ADM` | `FunctionValueHelp` | Role Function |
| `ZUI_MOB_RBAC_ADM` | `WorkContextValueHelp` | Role Work Context |

Value-help filtering is UX only. Direct OData/EML requests are still validated in RAP behavior.

## 7. Target-tenant setup

After abapGit import:

1. Activate DDIC tables before dependent CDS/BDEF/classes.
2. Activate and publish:
   - `ZUI_MOB_USER_ADM_O4`
   - `ZUI_MOB_RBAC_ADM_O4`
   - `ZUI_MD_CONGDOAN_ADM_O4`
   - `ZUI_PP_ALLOC_ADM_O4`
3. Generate the Fiori Elements shells from the activated bindings on the real tenant.
4. Assign separate IAM business catalogs/roles appropriate to each admin responsibility.
5. Do not hard-code tenant-specific OData URLs, semantic objects, destinations or Launchpad target mappings into this backend repository.
6. Test at minimum:
   - create User + initial Role;
   - add/remove Role/Function/Work assignments;
   - deactivate Role/Work and verify effective access changes;
   - maintain non-overlapping Công đoạn versions;
   - locate a CONFIRM ledger row;
   - execute `correctConfirm` and verify current balance + CORRECTION row;
   - verify raw ledger update/delete is unavailable;
   - verify admin services are not reachable through the mobile communication role.

## 8. Frontend repository boundary

This repository owns the ABAP RAP backend, stable annotations, service definitions and serialized bindings. Tenant-specific Fiori app shells may be generated in BAS/Fiori tools after activation.

Do not commit fabricated runtime URLs just to make a frontend manifest appear complete.
