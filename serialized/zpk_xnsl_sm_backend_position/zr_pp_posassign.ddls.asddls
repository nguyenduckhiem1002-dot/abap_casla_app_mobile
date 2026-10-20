@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Phân công công nhân vào vị trí'
@Metadata.allowExtensions: true
define root view entity ZR_PP_PosAssign
  as select from ztb_pp_pos_asgn
{
  @EndUserText.label: 'Work Center'
  key work_center           as WorkCenter,
  @EndUserText.label: 'Vị trí'
  key position_id           as PositionID,
  @EndUserText.label: 'Mã công nhân'
  key worker_id             as WorkerID,
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
