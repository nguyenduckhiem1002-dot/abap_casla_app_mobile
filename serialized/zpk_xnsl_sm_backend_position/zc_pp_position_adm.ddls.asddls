@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Danh mục vị trí làm việc'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_PP_Position_Adm
  provider contract transactional_query
  as projection on ZR_PP_Position
{
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MOB_WorkCenter_VH', element: 'WorkCenter' } }]
  @Search.defaultSearchElement: true
  key WorkCenter,
  @Search.defaultSearchElement: true
  key PositionID,
  @Search.defaultSearchElement: true
  key MachineID,
  @Search.defaultSearchElement: true
  PositionName,
  Status,
  CreatedBy,
  CreatedAt,
  LastChangedBy,
  LastChangedAt,
  LocalLastChangedAt
}
