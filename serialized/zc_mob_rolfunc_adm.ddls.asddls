@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Chức năng của chức danh (Admin)'
@UI.headerInfo: {
  typeName: 'Chức năng',
  typeNamePlural: 'Chức năng',
  title: { value: 'FuncID' }
}
define view entity ZC_MOB_RolFunc_Adm
  provider contract transactional_query
  as projection on ZI_MOB_RolFunc
{
  key RoleID,
  @UI.lineItem: [{ position: 10 }]
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MOB_Func_VH', element: 'FuncID' } }]
  key FuncID,
  @UI.lineItem: [{ position: 20 }]
      FuncName,
  @UI.lineItem: [{ position: 30 }]
      Module,
      _Role : redirected to parent ZC_MOB_Role_Adm,
      _Func : redirected to ZC_MOB_Func_Adm
}
