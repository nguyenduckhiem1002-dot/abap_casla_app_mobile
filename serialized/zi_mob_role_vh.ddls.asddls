@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Trợ giúp chọn chức danh'
@Search.searchable: true
define view entity ZI_MOB_Role_VH
  as select from ztb_mob_role
{
  @EndUserText.label: 'Mã chức danh'
  @Search.defaultSearchElement: true
  @ObjectModel.text.element: ['RoleName']
  key role_id   as RoleID,
  @Search.defaultSearchElement: true
  @EndUserText.label: 'Tên chức danh'
      role_name as RoleName
}
where status = 'A'
