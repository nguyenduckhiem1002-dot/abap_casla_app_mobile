@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Vị trí làm việc của chức danh (Admin)'
@UI.headerInfo: {
  typeName: 'Vị trí làm việc',
  typeNamePlural: 'Vị trí làm việc',
  title: { value: 'WorkName' }
}
define view entity ZC_MOB_RolWork_Adm
  provider contract transactional_query
  as projection on ZI_MOB_RolWork
{
  key RoleID,
  @UI.lineItem: [{ position: 10 }]
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MOB_Work_VH', element: 'WorkID' } }]
  key WorkID,
  @UI.lineItem: [{ position: 20 }]
      WorkName,
  @UI.lineItem: [{ position: 30 }]
      Plant,
  @UI.lineItem: [{ position: 40 }]
      WorkCenter,
  @UI.lineItem: [{ position: 50 }]
      BoPhan,
  @UI.lineItem: [{ position: 60 }]
      Location,
      _Role : redirected to parent ZC_MOB_Role_Adm,
      _Work : redirected to ZC_MOB_Work_Adm
}
