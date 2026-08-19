@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Chức danh của tài khoản (Admin)'
@UI.headerInfo: {
  typeName: 'Chức danh',
  typeNamePlural: 'Chức danh',
  title: { value: 'RoleID' }
}
define view entity ZC_MOB_UsrRol_Adm
  provider contract transactional_query
  as projection on ZI_MOB_UsrRol
{
  @UI.lineItem: [{ position: 10 }]
  key UserUUID,
  @UI.lineItem: [{ position: 20 }]
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MOB_Role_VH', element: 'RoleID' } }]
  key RoleID,
      /* Associations */
      _User : redirected to parent ZC_MOB_User_Adm
}
