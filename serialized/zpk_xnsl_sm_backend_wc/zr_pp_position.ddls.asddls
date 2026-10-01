@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Danh mục vị trí làm việc của công nhân'
@Metadata.allowExtensions: true
define root view entity ZR_PP_Position
  as select from ztb_pp_position
{
  @EndUserText.label: 'Work Center'
  key work_center           as WorkCenter,
  @EndUserText.label: 'Vị trí'
  key position_id           as PositionID,
  @EndUserText.label: 'Mã máy'
  key machine_id            as MachineID,
  @EndUserText.label: 'Tên vị trí'
  position_name             as PositionName,
  @EndUserText.label: 'Trạng thái'
  status                    as Status,
  @Semantics.user.createdBy: true
  created_by                as CreatedBy,
  @Semantics.systemDateTime.createdAt: true
  created_at                as CreatedAt,
  @Semantics.user.lastChangedBy: true
  last_changed_by           as LastChangedBy,
  @Semantics.systemDateTime.lastChangedAt: true
  last_changed_at           as LastChangedAt,
  @Semantics.systemDateTime.localInstanceLastChangedAt: true
  local_last_changed_at     as LocalLastChangedAt
}
