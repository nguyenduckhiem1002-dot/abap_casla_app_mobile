@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Chức danh của tài khoản (Admin)'
@UI.headerInfo: {
  typeName: 'Chức danh',
  typeNamePlural: 'Chức danh',
  title: { value: 'RoleName' }
}
define view entity ZC_MOB_UsrRol_Adm
  provider contract transactional_query
  as projection on ZI_MOB_UsrRol
{
  key UserUUID,
  @UI.lineItem: [{ position: 10 }]
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MOB_Role_VH', element: 'RoleID' } }]
  key RoleID,
  @UI.lineItem: [{ position: 20 }]
      RoleName,
  @UI.lineItem: [{ position: 30 }]
      RoleStatus,
      _User : redirected to parent ZC_MOB_User_Adm
}
