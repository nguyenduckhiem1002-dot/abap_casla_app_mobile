@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Chức năng của chức danh (Admin)'
@Metadata.allowExtensions: true
define view entity ZC_MOB_RolFunc_Adm
  as projection on ZI_MOB_RolFunc
{
  key RoleID,
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MOB_Func_VH', element: 'FuncID' } }]
  key FuncID,
      FuncName,
      AppModule,
      _Role : redirected to parent ZC_MOB_Role_Adm,
      _Func : redirected to ZC_MOB_Func_Adm
}
