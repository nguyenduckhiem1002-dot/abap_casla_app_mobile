@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Phân công công nhân vào vị trí'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_PP_PosAssign_Adm
  provider contract transactional_query
  as projection on ZR_PP_PosAssign
{
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MOB_WorkCenter_VH', element: 'WorkCenter' } }]
  @Search.defaultSearchElement: true
  key WorkCenter,
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_Position_VH', element: 'PositionID' },
    additionalBinding: [{ localElement: 'WorkCenter', element: 'WorkCenter', usage: #FILTER_AND_RESULT }] }]
  @Search.defaultSearchElement: true
  key PositionID,
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_Worker_VH', element: 'WorkerID' },
    additionalBinding: [{ localElement: 'WorkCenter', element: 'WorkCenter', usage: #FILTER }] }]
  @Search.defaultSearchElement: true
  key WorkerID,
  Status,
  CreatedBy,
  CreatedAt,
  LastChangedBy,
  LastChangedAt,
  LocalLastChangedAt
}
