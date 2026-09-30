@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Quản lý vị trí công nhân'
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
  PositionName,
  @Search.defaultSearchElement: true
  MachineID,
  Status,
  @Search.defaultSearchElement: true
  CurrentWorkerID,
  CurrentAssignUUID,
  OccupiedSince,
  LastEventUUID,
  LastEventType,
  LastEventAt,
  LastPrevWorkerID,
  LastPrevAssignUUID,
  LastMoverPrevAssign,
  LastReasonText,
  LastActorUserUUID,
  LastSourceChannel,
  CreatedBy,
  CreatedAt,
  LastChangedBy,
  LastChangedAt,
  LocalLastChangedAt,
  _Assignments
}
