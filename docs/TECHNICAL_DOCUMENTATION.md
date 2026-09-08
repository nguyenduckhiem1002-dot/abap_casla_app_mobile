# CASLA Mobile Production Allocation Technical Documentation

Version: 1.0  
Scope: ABAP Cloud RAP and OData V4 backend in `serialized/`  
Audience: ABAP developers, Fiori developers, QA, DevOps and SAP administrators

## 1. Purpose and scope

CASLA Mobile is a backend for allocating production work to workers and recording the quantity completed at a production-order operation. The backend exposes RAP services over OData V4 and persists application data in custom `Z` tables.

This document is the technical source of truth for the repository. It describes the current implementation, data contracts, security rules, deployment order, test strategy and known tenant dependencies.

The solution records a CASLA-specific allocation ledger. It does not create a standard SAP production confirmation, material document, goods movement or other standard SAP business document. If standard confirmation is required later, it must be designed as a separate integration.

### In scope

- Mobile authentication, sessions, password verification and refresh/logout.
- RBAC using user, role, function and work-context assignments.
- Live validation of SAP production order operations.
- Initial assignment, transfer, recall, confirmation and reverse.
- Controlled correction of a confirmation for IAM/Fiori administrators.
- Idempotent mobile retry and `getSyncStatus` reconciliation.
- Personal and team work history.
- Versioned operation master data and a separate working-shift catalog.
- Fiori metadata, service definitions and OData V4 service bindings.

### Out of scope

- A mobile-side queue persisted in SAP. Pending and retry state belongs to the mobile application.
- Automatic creation of standard SAP production confirmations.
- Payroll, time evaluation, attendance or employee master maintenance.
- Automatic backfill of shift information for old ledger rows.
- Deletion of business history as a correction mechanism.

## 2. Current implementation status

| Area | Repository status | Tenant action |
| --- | --- | --- |
| ABAP Cloud syntax and lint | Source and custom checks present | Run CI and tenant ATC |
| Mobile authentication | Implemented | Activate and test with real configuration |
| RBAC and work context | Implemented | Create roles, functions and work assignments |
| Production allocation ledger | Implemented | Activate tables, CDS and behavior in order |
| SAP operation guard | Implemented against released CDS names used by source | Verify released views and fields in target tenant |
| Shift configuration | Active/draft tables, managed RAP BO, read CDS, resolver and setup template implemented | Activate in dependency order, fill plant/time-zone data and test draft save |
| Separate shift Fiori service | Transactional UI CDS, metadata, service definition and binding included | Activate and publish service binding |
| Fiori admin correction | Implemented in behavior and admin projection | Assign IAM/catalog authorization |
| ABAP Unit tests | Test classes written | Run in ADT on target SAP |
| Runtime integration tests | Not executable from this repository | Run with a real OData binding and tenant data |

Lint passing in the repository is not evidence that a CDS view, service binding, released SAP API or authorization object is active in the destination tenant.

## 3. Architecture

```text
Mobile app
  └─ local pending/retry queue
       └─ ZUI_MOB_AUTH / ZUI_PP_OPALLOC (OData V4)
            ├─ token, session, device and permission validation
            ├─ SAP live operation and worker validation
            ├─ RAP command facade
            ├─ ZTB_PP_EMP_ALLOC       current balance
            └─ ZTB_PP_ALLOC_TXN       immutable posted ledger

Fiori and IAM
  ├─ ZUI_MOB_USER_ADM       users and user roles
  ├─ ZUI_MOB_RBAC_ADM       roles, functions and work contexts
  ├─ ZUI_MD_CONGDOAN_ADM    operation master and rates
  ├─ ZUI_PP_ALLOC_ADM       correction and allocation audit
  └─ ZUI_PP_SHIFT_ADM       managed working-shift configuration
```

The design follows five rules:

1. The server is authoritative for identity, session, permission, worker, work context and SAP operation.
2. Clients call business actions. They cannot directly CRUD the balance or ledger.
3. The ledger is append-only. Reverse and correction create compensating rows linked to the original row.
4. Balance update and ledger append run in one RAP transactional unit.
5. A mobile retry keeps the same `SyncItemUUID`; a timeout is an unknown outcome, not an automatic failure.

## 4. Repository and object conventions

```text
serialized/
  *.tabl.xml              DDIC table serialization
  *.asddls                CDS view or abstract entity source
  *.ddlx.asddlxs          CDS metadata extension source
  *.asbdef                RAP behavior definition source
  *.dcls.xml              DCL serialization
  *.clas.abap             global ABAP class implementation
  *.locals_imp.abap       behavior local handler implementation
  *.srvdsrv               service definition source
  *.srvb.xml              OData V4 service binding serialization
docs/                     design and operational documentation
scripts/                  repository checks
.github/workflows/        CI configuration
abaplint.json              ABAP Cloud lint rules
```

Naming conventions:

- `ZI_`: reusable/interface CDS view.
- `ZR_`: RAP root or interface behavior data model.
- `ZC_`: consumption/projection CDS view.
- `ZA_`: abstract action parameter/result entity.
- `ZTB_`: persisted custom table.
- `ZUI_`: service definition or UI-facing service.
- `ZCL_`: global ABAP class.

## 5. Data model

### 5.1 Identity and authorization

```text
ZTB_MOB_USER
  ├─ ZTB_MOB_CRED
  ├─ ZTB_MOB_SESSION
  └─ ZTB_MOB_USR_ROL ── ZTB_MOB_ROLE
                              ├─ ZTB_MOB_ROL_FNC ── ZTB_MOB_FUNC
                              └─ ZTB_MOB_ROL_WRK ── ZTB_MOB_WORK
```

| Table | Purpose | Important rule |
| --- | --- | --- |
| `ZTB_MOB_USER` | Mobile account and worker mapping | Account status and normalized username are server-controlled |
| `ZTB_MOB_CRED` | Password hash, salt and KDF parameters | Plaintext password is never persisted |
| `ZTB_MOB_SESSION` | Access/refresh session | Only token hashes are persisted; device is bound to session |
| `ZTB_MOB_ROLE` | Role master | Deactivate with status instead of deleting history |
| `ZTB_MOB_FUNC` | Stable permission identifiers | Used by UI and server authorization |
| `ZTB_MOB_WORK` | Plant, work center and work context | Defines where a role may operate |
| Mapping tables | User-role, role-function and role-work | Inactive mappings are ignored at runtime |

The manager user is an actor and permission holder. The worker receiving production quantity is determined by the action payload and worker validation. The manager must not be silently assigned production quantity merely because the manager created the assignment.

### 5.2 Production allocation tables

```text
ZTB_PP_OP_ALLOC
  ├─ ZTB_PP_EMP_ALLOC
  └─ ZTB_PP_ALLOC_TXN
```

`ZTB_PP_OP_ALLOC` is a local snapshot of a live SAP production order operation. The logical business key is production order plus operation; the tenant must enforce the intended uniqueness.

`ZTB_PP_EMP_ALLOC` stores the current balance by operation and worker. Its invariant is:

```text
RemainingQuantity
  = InitialAssignedQuantity
  + TransferredInQuantity
  - TransferredOutQuantity
  - RecalledQuantity
  - CompletedQuantity
```

The balance is intentionally worker-operation based and can span multiple shifts. A shift-specific balance is not created by the current implementation.

`ZTB_PP_ALLOC_TXN` is an immutable audit ledger. It stores posted commands, original-transaction links, actor/session/device information, worker verification, quantity, UoM, reason and source channel. Legacy SAP confirmation fields remain for compatibility; they do not mean that the system created a standard SAP confirmation.

### 5.3 Shift fields in the ledger

| Ledger field | Meaning |
| --- | --- |
| `SHIFT_ID` | Shift code selected and validated by the server |
| `WORK_DATE` | Business date, equal to the local date on which the shift starts |
| `EXECUTED_AT` | Actual event time in UTC, supplied by the mobile client |
| `SHIFT_START_AT` | UTC start boundary calculated by the resolver |
| `SHIFT_END_AT` | UTC end boundary calculated by the resolver |
| `SHIFT_TIME_ZONE` | SAP time-zone key used for calculation |
| `SHIFT_VALID_FROM` | Configuration version used for the snapshot |
| `EXECUTION_DATE` | Legacy-compatible copy of `WORK_DATE` |

The complete shift snapshot is stored so later configuration changes do not rewrite history.

### 5.4 Operation master

`ZTB_MD_CONGDOAN` is a versioned custom master keyed by `CLIENT + MA_CONGDOAN + VALID_FROM`. It stores name, department, rates and validity. The master enriches reports and does not decide whether an SAP operation can be confirmed. The SAP operation guard remains authoritative for operation status, quantity, UoM, plant and work center.

## 6. Authentication and security

### 6.1 Login and session lifecycle

1. Normalize username by trim/condense and lowercase.
2. Read only an active account, active credential and non-locked account.
3. Verify the password with the shared password service.
4. Generate access and refresh token values and persist only their hashes.
5. Enforce one active session per device and at most five active sessions per account; a new login revokes the previous session for that device.
6. Access token lifetime is 30 minutes and refresh token lifetime is 30 days in the current implementation.
7. Return permissions and work context for UI construction. The backend repeats authorization for every command.

### 6.2 Lockout and password policy

- Five failed attempts in a one-minute window lock the account for ten minutes.
- Logout, refresh-token rotation and password change revoke active sessions as implemented by the behavior pool.
- Newly created accounts require a password change.
- Current password policy requires at least six characters and rejects a password containing the username.
- Password pepper is read from `ZTB_MOB_CONFIG`.
- Credential records use a per-record salt and iterative SHA-256 KDF with the configured iteration range.

The policy is a security contract. A future policy change must update create-user, change-password, admin reset, error messages, migration and tests together.

### 6.3 Token and device guard

Every mobile action validates token, session status, expiry, device ID, account status and password-change state. The required function is checked before the business operation. `ActorUserUUID` always comes from the validated session; it is never trusted from a client payload.

Worker passwords are used only during the request. They are not returned to the client and are not written to the ledger.

## 7. SAP operation and worker validation

`ZCL_PP_OPERATION_GUARD` resolves the requested production order and operation against the released SAP CDS views used by the source. The guard:

1. Reads active manufacturing-order status.
2. Requires `REL` and rejects `TECO`, `CLSD` and `DLFL` even when `REL` is still present.
3. Reads the operation by manufacturing order and operation number.
4. Requires a valid operation-control profile and operation standard text code.
5. Requires positive planned quantity, plant, UoM and work center internal ID.
6. Resolves the work-center code from the internal ID.
7. Writes or refreshes the local operation snapshot and maps the standard text code to `MaCongDoan`.

Every mutation resolves the live operation before changing the balance. Duplicate local snapshots fail closed. Exact released status, field names and required authorization for `I_ManufacturingOrderStatus`, `I_ManufacturingOrderOperation` and `I_WorkCenter` must be checked in ADT/View Browser on the target tenant.

Worker validation additionally checks account mapping, active worker reference, plant/work-center scope, effective date and worker password according to the existing operation command contract.

## 8. RAP behavior and business actions

The root behavior is `ZR_PP_OpAlloc`, implemented by `ZBP_R_PP_OPALLOC`, with child entities `EmployeeAllocation` and `AllocationTransaction`.

| Action | Access surface | Result |
| --- | --- | --- |
| `initialAssign` | Internal bound action | Create or increase worker balance and append `INITIAL_ASSIGN` |
| `transfer` | Internal bound action | Decrease source, increase target and append `TRANSFER` |
| `recall` | Internal bound action | Reduce unspent assigned quantity and append `RECALL` |
| `confirm` | Internal bound action | Increase completed quantity, decrease remaining and append `CONFIRM` |
| `reverse` | Internal bound action | Compensate a confirmation and append `REVERSE` |
| `correctConfirm` | IAM/Fiori only | Append signed `CORRECTION` and adjust balance by delta |
| `submitInitialAssign` | Mobile static facade | Authenticate, validate, resolve and call `initialAssign` |
| `submitTransfer` | Mobile static facade | Authenticate, validate, resolve and call `transfer` |
| `submitRecall` | Mobile static facade | Authenticate, validate, resolve and call `recall` |
| `submitConfirm` | Mobile static facade | Authenticate, validate, resolve and call `confirm` |
| `submitReverse` | Mobile static facade | Authenticate, validate, resolve and call `reverse` |
| `getSyncStatus` | Mobile static action | Find a receipt after timeout |
| `getWorkHistory` | Mobile static action | Return scoped history and summaries |

### 8.1 Common command contract

Every mobile mutation identifies the operation by `ProductionOrder` and `Operation`, sends an access token and device ID, and supplies a client-generated `SyncItemUUID`. A worker mutation supplies worker ID, quantity, UoM, worker password and `ExecutionDate` according to the action.

New shift-aware clients may additionally send:

```json
{
  "ShiftID": "NIGHT",
  "ExecutedAt": "2026-09-07T19:00:00Z",
  "ExecutionDate": "2026-09-07"
}
```

`ExecutedAt` is the actual production event time. It is not the upload time or server save time. The backend normalizes `ExecutionDate` to the shift business date and stores the calculated snapshot.

### 8.2 Initial assignment

The actor must have the initial-assignment function and a matching work context. The target worker is verified and active for the operation scope and business date. Quantity must be positive, UoM must match the operation and business rules must not exceed the operation quantity. The backend creates or updates only the target worker's balance and appends `INITIAL_ASSIGN`.

### 8.3 Transfer

The actor needs `PP_TRANSFER`. Source and target workers must differ. The target worker is independently verified. The source balance must have enough remaining quantity. The source receives `TransferredOutQuantity`; the target receives `TransferredInQuantity`; the ledger stores both worker IDs.

### 8.4 Recall

The actor needs `PP_RECALL`. The original transaction must belong to the operation, identify the same worker, and be an eligible `INITIAL_ASSIGN` or `TRANSFER`. The worker and UoM must match the balance and enough remaining quantity must exist. The original row is not changed; a linked `RECALL` row is appended.

### 8.5 Confirm

The actor needs `PP_CONFIRM`. The worker must be active and verified, the UoM must match, and the balance must be sufficient. `OriginalTransactionUUID` is required and must identify a posted `INITIAL_ASSIGN` or `TRANSFER` for the same operation and worker. This immutable lineage lets team history attribute the confirmation to the correct allocation. The backend updates `CompletedQuantity` and `RemainingQuantity`, then appends `CONFIRM` as a CASLA custom transaction.

### 8.6 Reverse

The actor needs `PP_REVERSE`. The target must be a posted `CONFIRM` for the same operation and must not already be reversed. Effective quantity is the original quantity plus earlier correction deltas. The balance is compensated and a linked `REVERSE` row is added. Original rows remain unchanged.

### 8.7 Controlled correction

`correctConfirm` is intentionally absent from the mobile projection. It is available to the IAM/Fiori admin surface. It requires a posted, not-yet-reversed confirmation, a non-negative new quantity in the same UoM and a reason code/text. The delta is:

```text
delta = NewQuantity - current effective confirmation quantity
```

The delta updates the balance and a `CORRECTION` ledger row records the new effective quantity. The correction inherits the original confirmation's shift snapshot and business date. `CreatedAt` identifies when the correction was recorded; the inherited `ExecutedAt` continues to identify the production event.

## 9. Idempotency and offline synchronization

The mobile app creates `SyncItemUUID` before its first send and keeps it unchanged across retries.

```text
No posted receipt
  -> execute command

Exactly one matching posted receipt
  -> return idempotent success; do not append another row

Receipt exists but business payload differs
  -> IDEMPOTENCY_KEY_REUSED

More than one receipt exists
  -> SYNC_RECEIPT_DUPLICATE; fail closed
```

The comparison includes actor, operation, transaction type, worker/from/to worker, quantity, UoM, execution date, original transaction and shift event fields when supplied. A persisted matching `CONFIRM` is returned before the live SAP operation guard runs, so a lost HTTP response remains retryable after the order status changes.

If HTTP response is lost, the mobile status becomes `UNKNOWN` or `PENDING_CONFIRMATION` and calls `getSyncStatus`. `NOT_FOUND` means that the backend has not proved a commit; it is not a business rejection. A retry uses the same key and logical payload.

The facade calls RAP actions in local mode and reads the receipt through EML. It must not rely on Open SQL to read a child row that may still be in the RAP transactional buffer before the save sequence completes.

## 10. Working shifts and overnight accounting

### 10.1 Configuration model

`ZTB_PP_SHIFT` is a separate configuration table with key `CLIENT + PLANT + SHIFT_ID + VALID_FROM`. Besides the business fields below, it contains the managed RAP audit fields `CREATED_BY`, `CREATED_AT`, `LAST_CHANGED_BY`, `LAST_CHANGED_AT` and `LOCAL_LAST_CHANGED_AT`. Draft state is persisted separately in `ZTD_PP_SHIFT` with `SYCH_BDL_DRAFT_ADMIN_INC`.

| Field | Rule |
| --- | --- |
| `SHIFT_NAME` | User-facing name |
| `START_TIME` | Local factory start time |
| `END_TIME` | Local factory end time |
| `END_DAY_OFFSET` | `0` for same day, `1` for next day |
| `TIME_ZONE` | SAP-configured time-zone key |
| `VALID_FROM`, `VALID_TO` | Configuration validity dates |
| `IS_ACTIVE` | Active/inactive status |

The current setup template is `ZCL_PP_SHIFT_SETUP`. It contains sample shifts 06:00-14:00, 14:00-22:00 and 22:00-06:00. The template does not guess a plant or time zone, overwrite an existing version or delete old configuration. Fill the constants for the real tenant and run it in ADT.

### 10.2 Resolver rules

`ZCL_PP_SHIFT_RESOLVER` accepts plant, shift ID, executed UTC timestamp, optional execution date and optional sync key. It:

1. Reuses the stored snapshot for an existing sync item when the request is a retry.
2. Accepts legacy requests only when both new fields are initial and a valid `ExecutionDate` is supplied.
3. Requires `ShiftID` and `ExecutedAt` together for new requests.
4. Rejects future event timestamps.
5. Converts UTC to local factory time using the SAP time-zone key.
6. Finds exactly one active configuration whose half-open interval contains the event.
7. Calculates the business date and UTC start/end boundaries.
8. Rejects an explicit `ExecutionDate` that differs from the calculated business date.
9. Returns the complete snapshot for persistence.

The interval is `[start, end)`: start belongs to the shift and end belongs to the next shift. Same-day shifts require end time greater than start. Overnight shifts use `END_DAY_OFFSET = 1` and may be at most 24 hours.

### 10.3 Overnight example

For a shift from 22:00 on 07 September to 06:00 on 08 September, all rows below have `WorkDate = 2026-09-07`:

| Local factory time | WorkDate | Shift |
| --- | --- | --- |
| 07/09 23:00 | 07/09 | NIGHT |
| 08/09 02:00 | 07/09 | NIGHT |
| 08/09 05:30 | 07/09 | NIGHT |
| 08/09 06:00 | next shift | NIGHT is excluded at the boundary |

Offline clients must use the actual event timestamp, not the timestamp at which the request reaches SAP. Configuration changes do not recalculate a posted row because the snapshot is stored in the ledger.

### 10.4 Reporting semantics

`getWorkHistory` accepts `ShiftID`. To see the overnight shift for 07 September, use a custom range whose from and to dates are both 07 September and set `ShiftID = NIGHT`. Do not use the default current-day range after midnight if the intended report date is the shift start date.

Rows created before shift support have empty snapshot fields and use `ExecutionDate` as a reporting fallback. The implementation does not fabricate a shift for those rows.

The current balance remains worker-operation based across shifts. Summary `Remaining` is period-based assigned quantity minus period-based completion; it is not the all-time balance and can be negative when the assignment occurred outside the selected reporting period. The application should show ledger summary and current balance as separate concepts.

## 11. History and audit

`ZCL_PP_WORK_HISTORY` reads posted ledger rows and joins the local operation snapshot. It resolves worker names from `ZI_PP_WorkerRef` for display only; worker master data is not used to grant access.

### Range rules

| Code | Effective range |
| --- | --- |
| `D` | Today |
| `W` | Today minus six days through today |
| `M` or unknown | Today minus 29 days through today |
| `C` | Custom from/to, not future, less than 92 days apart |

The scan is capped at 20,000 ledger rows and entries at 1,000 rows. `IsTruncated` indicates that a cap was reached.

### Authorization scope

- `PP_HIST_TEAM`: actor sees assignments/transfers booked by that actor and related lineage of worker transactions.
- `PP_HIST_SELF`: worker is derived from actor's account mapping; a client-supplied worker filter is ignored.
- No applicable function: `MISSING_PERMISSION`.
- Inactive roles and work contexts are ignored at query time.

Team history follows original-transaction links through correction and reversal chains. This prevents a correction or reversal from disappearing merely because the supervisor did not create that derived row.

The summary counts initial assignment and transfer as assigned, recall as negative assigned, confirm and correction as completed, and reverse as negative completed. `Remaining` therefore reconciles with the worker-operation balance: assigned minus completed.

## 12. OData services and Fiori

### 12.1 Service definitions

| Service definition | Main purpose | Important entities |
| --- | --- | --- |
| `ZUI_MOB_AUTH` | Mobile authentication and session | Auth actions and results |
| `ZUI_PP_OPALLOC` | Mobile allocation and history | `OperationAllocations`, `Shifts`, value helps |
| `ZUI_PP_ALLOC_ADM` | Admin correction and audit | `OperationAllocations`, `AllocationTransactions`, value helps |
| `ZUI_PP_SHIFT_ADM` | Separate managed shift configuration app | `Shifts`, `PlantValueHelp` |
| `ZUI_MOB_USER_ADM` | User administration | User and related admin entities |
| `ZUI_MOB_RBAC_ADM` | Role/function/work administration | RBAC admin entities |
| `ZUI_MD_CONGDOAN_ADM` | Operation master administration | Operation master entities |

### 12.2 Separate shift service

The shift catalog is exposed independently so a future Fiori Elements app can be created without exposing allocation actions or unrelated entities:

```text
CDS view       ZC_PP_Shift_Adm
Metadata       ZC_PP_Shift_Adm
Service        ZUI_PP_SHIFT_ADM
Binding        ZUI_PP_SHIFT_ADM_O4
Main entity    Shifts
Protocol       OData V4 UI
```

`ZI_PP_Shift` remains the read/value-help model. `ZR_PP_Shift` is the managed-draft transactional RAP root backed by `ZTB_PP_SHIFT` and draft table `ZTD_PP_SHIFT`; `ZC_PP_Shift_Adm` is its transactional projection. The behavior uses `LastChangedAt` as total ETag and `LocalLastChangedAt` as entity ETag, supports create/update with Edit, Activate, Discard, Resume and Prepare, and validates required fields, date ranges and overlapping active versions. Hard-delete is intentionally not exposed; administrators deactivate a version with `IsActive = 'I'`. The binding in Git is a deployment descriptor; it must be activated and published on the tenant before an endpoint exists.

For a Fiori Elements List Report/Object Page, choose service `ZUI_PP_SHIFT_ADM` and main entity `Shifts`. The mobile service `ZUI_PP_OPALLOC` still exposes `ZI_PP_Shift` as `Shifts` for mobile/API compatibility; the admin correction service stays focused on allocation and audit.

### 12.3 Value helps and metadata

Action parameters provide value help for `ShiftID` from `ZI_PP_Shift` and UoM from `I_UnitOfMeasure` where applicable. UI metadata is maintained separately from domain CDS where possible. All user-facing fields should have `@EndUserText.label`; selection fields and line-item positions are defined in the relevant metadata extension.

The SAP Gateway unit for quantity fields must be a configured SAP unit. Do not persist or return an unmapped value such as `PC` when the tenant expects `ST` or another configured ISO/SAP unit. The quantity field must keep its `@Semantics.quantity.unitOfMeasure` pairing with the unit field.

## 13. Error handling

Errors are returned as stable application error codes and user-facing text through command results. Important examples include:

| Code | Meaning |
| --- | --- |
| `MISSING_PERMISSION` | Actor lacks the required function |
| `WORKER_NOT_MAPPED` | Self-history account has no worker mapping |
| `OPERATION_SNAPSHOT_DUPLICATE` | More than one local operation snapshot exists |
| `SHIFT_AND_EXECUTED_AT_REQUIRED` | New request supplied only one shift event field |
| `SHIFT_NOT_APPLICABLE` | No active configuration covers the event |
| `SHIFT_CONFIG_AMBIGUOUS` | More than one active version covers the event |
| `SHIFT_WORK_DATE_MISMATCH` | Explicit date differs from calculated business date |
| `EXECUTED_AT_IN_FUTURE` | Event timestamp is later than current UTC time |
| `IDEMPOTENCY_KEY_REUSED` | Same sync key carries different business data |
| `SYNC_RECEIPT_DUPLICATE` | More than one receipt exists for a sync key |
| `NO_RELEASED_OPERATION_AT_WORKCENTER` | SAP operation is not released/usable |
| `NO_RELEASED_YBP1_AT_WORKCENTER` | Tenant operation-control validation failed |
| `NO_OPERATION_FOR_WORKER_WORKCENTER` | Worker has no valid operation scope |
| `RANGE_INVALID`, `RANGE_IN_FUTURE`, `RANGE_TOO_WIDE` | History range rejected |

The service layer may wrap application errors in an OData Gateway error. A 500 error caused by unit serialization, such as “No configuration for unit of measure”, is a tenant data/semantic configuration issue and must be fixed by using a configured SAP UoM and activating affected CDS/service metadata.

## 14. Deployment with abapGit and an existing backend

abapGit source files are not database rows. Updating a serialized source file should not require deleting the live table or its data. For an existing backend:

1. Pull or import the repository into the intended package.
2. Review the abapGit object list. Do not approve deletion of a live table merely because a source serialization changed.
3. Keep object name, package, object type and source path stable. A rename or object-type change can appear as delete plus insert.
4. Add new columns to `ZTB_PP_ALLOC_TXN` through the normal DDIC activation/migration path; preserve existing data.
5. Create `ZTB_PP_SHIFT` and its managed-draft table `ZTD_PP_SHIFT` separately.
6. Activate in dependency order.
7. Publish service bindings after service definitions are active. The repository
   ignores generated `SCO2`/`SUSH` files because these contain tenant-specific
   OData V4 `G4BA` registration and start-authorization data. Publish the local
   service endpoint on the destination tenant, then verify its authorization
   configuration separately; publication alone does not establish that the
   required permissions or customized authorization defaults are present.
8. In the service binding editor, open **Maintain Authorization Default Values**
   and review the required authorization objects and values. Use **Synchronize**
   where appropriate to add missing objects from the authorization context;
   it does not remove existing objects. Preserve or reapply any intentionally
   customized defaults required on the destination tenant.
9. For business-user access, verify the IAM app, business catalog and assigned
   business role. For communication-user access, verify the communication
   scenario and arrangement, including the assigned user and required service.
   Test the endpoint using the intended user to confirm the required operations
   are authorized and unauthorized operations are rejected.

See [SAP: Editing Authorization Default Values](https://help.sap.com/docs/sap-btp-abap-environment/abap-environment/editing-default-authorization-values)
for synchronization behavior and the relationship between service defaults and
IAM app authorizations.

The repository must not contain `*.sco2.xml` or `*.sush.xml` files. After the
change is committed and pushed, refresh the abapGit repository index, pull again,
and confirm that the import list contains no `G4BA` object. The remaining
`*.srvb.xml` files are the service-binding source definitions and must be retained.

Recommended activation order:

```text
1. Existing DDIC tables, ZTB_PP_SHIFT and ZTD_PP_SHIFT
2. Interface CDS and value-help CDS
3. Root/consumption CDS projections
4. Abstract action parameters and result entities
5. RAP behavior definition
6. Resolver, history and behavior implementation classes
7. Metadata extensions
8. Service definitions
9. Service bindings and publication
10. IAM/catalog/communication authorization
```

If abapGit reports delete/add for an object that should be overwritten, compare object type, package, original name, serialization path and case. Import source through ADT as an overwrite only after confirming that the target object is the same repository object. Never use delete/recreate as a shortcut for a table with production data.

## 15. Testing and quality gates

### Repository checks

Run the repository CI command and custom RAP pattern check before import. The current quality gate includes ABAP Cloud lint and repository-specific RAP checks. Also run `git diff --check` to catch whitespace errors.

### ABAP Unit coverage

`ZCL_PP_SHIFT_RESOLVER` tests cover overnight events before and after midnight, inclusive start and exclusive end boundaries, event outside the shift, configuration validity end date, daytime shift, invalid overnight configuration, legacy date-only request and missing timestamp fields.

`ZCL_PP_WORK_HISTORY` tests cover correction/reverse lineage totals, ancestor scope expansion when rows are not read in parent-first order, and legacy execution-date fallback and explicit work date.

These tests are written in the repository but require ADT execution on SAP. They are not replaced by abaplint.

### Tenant integration checklist

- Activate all dependencies and refresh `$metadata`.
- GET `Shifts` from `ZUI_PP_SHIFT_ADM_O4` and verify labels and fields.
- Test a normal shift, overnight 23:00, 02:00 and the exact 06:00 boundary.
- Test offline replay with the same `SyncItemUUID`.
- Retry with a changed timestamp and verify idempotency rejection.
- Confirm that the manager is the actor while the intended worker receives the balance.
- Verify quantity UoM is a configured SAP unit.
- Test initial assign, transfer, recall, confirm, correction and reverse.
- Test team and self history, custom date range and shift filter.
- Verify correction/reverse reports use the original shift snapshot.
- Verify inactive role/work context and expired configuration are rejected.
- Check Gateway logs using the returned transaction ID for any serialization error.

## 16. Operational and performance notes

The ledger is append-only and grows with every command, correction and reverse. Keep indexes aligned with common filters: operation, worker, actor, sync key, status, business date and shift ID. Validate index effectiveness with tenant SQL monitoring rather than assuming that a custom index is useful.

History deliberately caps scans and output. The client must surface `IsTruncated` and provide narrower filters. A future high-volume reporting design should use a dedicated aggregate or analytical model instead of increasing the scan limit indefinitely.

Do not log access tokens, refresh tokens, plaintext worker passwords or password hashes. Application logs should include stable correlation IDs and the OData transaction ID where available.

## 17. Change management rules

- Preserve table names, keys and serialized object names once deployed.
- Add columns compatibly; do not recreate a production table to change a structure.
- Keep ledger rows immutable and use compensating transactions.
- Version shift and operation master configuration; do not edit a version already used by posted transactions.
- Keep service definition and binding changes explicit so `$metadata` changes are reviewable.
- Update this document whenever action parameters, error codes, tables, bindings or reporting semantics change.
- Mark tenant-specific assumptions clearly and verify released SAP APIs in ADT.

## 18. Related repository files

- [Working shift design](WORKING_SHIFTS.md)
- [Fiori admin guidance](FIORI_ELEMENTS_ADMIN.md)
- [Metadata UX audit](METADATA_UX_AUDIT.md)
- [Production demo data queries](PP_DEMO_DATA_QUERIES.md)
- [Mobile synchronization plan](ABAP_RAP_MOBILE_SYNC_PLAN.md)
- [Security and performance review](SECURITY_PERFORMANCE_REVIEW.md)
- [Shift setup class](../serialized/zcl_pp_shift_setup.clas.abap)
- [Shift resolver](../serialized/zcl_pp_shift_resolver.clas.abap)
- [Separate shift service](../serialized/zui_pp_shift_adm.srvd.srvdsrv)

## Appendix A. Representative OData calls

### Read shift catalog

```http
GET <shift-service-root>/Shifts?$filter=Plant eq '1000' and IsActive eq 'A'&$orderby=ShiftID,ValidFrom
```

### Read operation history for an overnight shift

```http
POST <mobile-service-root>/OperationAllocations/<operation-key>/getWorkHistory
Content-Type: application/json

{
  "RangeCode": "C",
  "DateFrom": "2026-09-07",
  "DateTo": "2026-09-07",
  "ShiftID": "NIGHT",
  "SummaryOnly": false,
  "AccessToken": "<access-token>",
  "DeviceID": "<device-id>"
}
```

### Mobile confirmation event

```json
{
  "ProductionOrder": "100000000001",
  "Operation": "0010",
  "WorkerID": "HD000001",
  "Quantity": 25,
  "UnitOfMeasure": "ST",
  "ExecutionDate": "2026-09-07",
  "ShiftID": "NIGHT",
  "ExecutedAt": "2026-09-07T19:00:00Z",
  "SyncItemUUID": "<uuid>",
  "AccessToken": "<access-token>",
  "DeviceID": "<device-id>",
  "WorkerPassword": "<worker-password>"
}
```

The exact OData URL shape is generated by the active service binding and must be copied from the tenant's binding, not hard-coded from a different system.


