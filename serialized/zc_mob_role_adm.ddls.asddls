@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Quản trị chức danh'
@Metadata.allowExtensions: true
define root view entity ZC_MOB_Role_Adm
  provider contract transactional_query
  as projection on ZI_MOB_Role
{
  key RoleID,
      RoleName,
      Status,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _Functions : redirected to composition child ZC_MOB_RolFunc_Adm,
      _WorkAssignments : redirected to composition child ZC_MOB_RolWork_Adm
}
