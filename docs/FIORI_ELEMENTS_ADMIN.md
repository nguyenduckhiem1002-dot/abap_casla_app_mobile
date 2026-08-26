# CASLA Mobile – Fiori Elements Admin Apps

Backend admin UX is intentionally consolidated into **two** Fiori Elements applications. Do not create separate apps for User Roles, Role Functions or Role Work Contexts; those are composition sections of their parent Object Page.

## 1. User Administration

**Service definition:** `ZUI_MOB_USER_ADM`  
**Recommended OData V4 binding name:** `ZUI_MOB_USER_ADM_O4`  
**Main entity set:** `SupervisorAccounts`

Use a **List Report + Object Page** application.

The List Report exposes the `createUser` action. Its parameter entity `ZA_MOB_CreateUser` contains `RoleID`, so the create dialog collects the initial active Role together with Username, password, name, email and WorkerID. Backend validation rejects a missing/inactive Role and deep-creates **User + Credential + initial UserRole in one RAP LUW**.

The User Object Page has two logical sections:

1. **Thông tin tài khoản** – account identification fields.
2. **Chức danh** – `_Roles` table. Add/remove additional Role assignments here; `RoleID` uses the active-role value help.

Do not expose credential/session entities or direct account create/update to the mobile service.

## 2. RBAC & Work Administration

**Service definition:** `ZUI_MOB_RBAC_ADM`  
**Recommended OData V4 binding name:** `ZUI_MOB_RBAC_ADM_O4`  
**Main entity set:** `Roles`

Use one **List Report + Object Page** application with Role as the main navigation object. The Role Object Page contains:

1. **Thông tin chức danh** – Role ID/name/status.
2. **Quyền chức năng** – `_Functions` composition table with Function value help.
3. **Vị trí làm việc** – `_WorkAssignments` composition table with Work Context value help and read-only Work Name/Plant/Work Center/Bộ phận/Location columns.

The same service exposes `WorkContexts` as the Work master. Configure it as a **secondary route/page inside this application**, not as another Launchpad app/tile. This keeps Work master maintenance available without creating a third admin application.

`WorkContexts` supports create/update. Hard delete is deliberately denied; set `IsActive = 'I'` when a Work ID is retired so existing grants/audit references are not orphaned.

## 3. Value helps

| Admin service | Value help | Used by |
| --- | --- | --- |
| `ZUI_MOB_USER_ADM` | `RoleValueHelp` (`ZI_MOB_Role_VH`) | Initial Role + User Role assignment |
| `ZUI_MOB_RBAC_ADM` | `FunctionValueHelp` (`ZI_MOB_Func_VH`) | Role Function assignment |
| `ZUI_MOB_RBAC_ADM` | `WorkContextValueHelp` (`ZI_MOB_Work_VH`) | Role Work assignment |

Role and Work value helps return active entries only. This is UX filtering; RAP/backend validation still verifies referenced master data, and runtime authorization never trusts a client-selected ID by itself.

## 4. Runtime relationship

```text
User -> UserRole -> active Role
                    |-> RoleFunction -> Function
                    |-> RoleWork ----> active Work
                                      (Plant + WorkCenter)
```

`login` and `refresh` return both `_Permissions` and `_WorkContexts`.

Before `initialAssign`, `transfer` or `recall` changes balance/ledger, backend derives the actor from the access token and verifies that the operation's `Plant + WorkCenter` is inside an active Work Context granted through one of the actor's active Roles. A client cannot expand its work scope by changing the payload.

## 5. Target-tenant setup

After abapGit import and activation:

1. Create and activate an **OData V4** service binding for `ZUI_MOB_USER_ADM`.
2. Create and activate an **OData V4** service binding for `ZUI_MOB_RBAC_ADM`.
3. Generate the two Fiori Elements apps above from those bindings in SAP Fiori tools/BAS, or the tenant-supported generator.
4. In the RBAC app, keep `Roles` as the main List Report and route `WorkContexts` as a secondary page instead of a separate application.
5. Publish only these two admin apps to the required Launchpad/Spaces/Pages.
6. Protect them with the intended IAM business catalogs/business roles.
7. Test the complete admin flow:
   - create User + initial Role;
   - add/remove additional User Roles;
   - create/update Role;
   - add/remove Role Functions;
   - create/update/deactivate Work Context;
   - add/remove Role Work Context assignments;
   - verify login/refresh returns effective Work Contexts;
   - verify PP mutation outside assigned Plant/Work Center is rejected.

## 6. Why no UI5 manifest is hard-coded in this repository

This repository currently contains the ABAP RAP backend, not a tenant-bound UI5 deployment project. Service-binding URLs, semantic objects, Launchpad target mappings, catalogs and destinations are tenant-specific.

The ABAP source therefore owns what can be made stable here: transactional projections, composition structure, UI annotations, value helps, service definitions and server-side validation. Do not commit a fabricated OData URL merely to make a `manifest.json` look complete; generate the Fiori Elements shells from the actual activated bindings on the target tenant.
