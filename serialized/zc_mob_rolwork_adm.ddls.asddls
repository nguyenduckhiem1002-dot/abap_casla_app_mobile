
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Vị trí làm việc của chức danh (Admin)'
@Metadata.allowExtensions: true
define view entity ZC_MOB_RolWork_Adm
  as projection on ZI_MOB_RolWork
{
  key RoleID,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MOB_Work_VH', element: 'WorkID' } }]
      @UI.textArrangement: #TEXT_FIRST
  key WorkID,
      _Role : redirected to parent ZC_MOB_Role_Adm,
      _Work : redirected to ZC_MOB_Work_Adm
}
