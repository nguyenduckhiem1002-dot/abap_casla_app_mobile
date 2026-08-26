@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Chức danh của tài khoản (Admin)'
@Metadata.allowExtensions: true
define view entity ZC_MOB_UsrRol_Adm
  as projection on ZI_MOB_UsrRol
{
  key UserUUID,
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MOB_Role_VH', element: 'RoleID' } }]
  key RoleID,
      RoleName,
      RoleStatus,
      _User : redirected to parent ZC_MOB_User_Adm
}
