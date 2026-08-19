@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Chức danh ứng dụng di động'
define root view entity ZI_MOB_Role
  as select from ztb_mob_role
  composition [0..*] of ZI_MOB_RolFunc as _Functions
{
  key role_id               as RoleID,
      role_name             as RoleName,
      status                as Status,
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      _Functions
}
