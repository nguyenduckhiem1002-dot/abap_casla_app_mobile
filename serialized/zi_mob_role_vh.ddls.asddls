@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Trợ giúp chọn chức danh'
define view entity ZI_MOB_Role_VH
  as select from ztb_mob_role
{
  key role_id   as RoleID,
      role_name as RoleName,
      status    as Status
}
