@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Vị trí làm việc của công nhân'
@Metadata.allowExtensions: true
define root view entity ZR_PP_Position
  as select from ztb_pp_position
  association [0..*] to ZI_PP_PosAssign as _Assignments
    on  $projection.WorkCenter = _Assignments.WorkCenter
    and $projection.PositionID = _Assignments.PositionID
{
  @EndUserText.label: 'Work Center'
  key work_center            as WorkCenter,
  @EndUserText.label: 'Vị trí'
  key position_id            as PositionID,
  @EndUserText.label: 'Tên vị trí'
  position_name              as PositionName,
  @EndUserText.label: 'Mã máy'
  machine_id                 as MachineID,
  @EndUserText.label: 'Trạng thái'
  status                     as Status,
  @EndUserText.label: 'Công nhân đang ngồi'
  current_worker_id          as CurrentWorkerID,
  current_assign_uuid        as CurrentAssignUUID,
  @EndUserText.label: 'Ngồi từ'
  occupied_since             as OccupiedSince,
  last_event_uuid            as LastEventUUID,
  @EndUserText.label: 'Thao tác gần nhất'
  last_event_type            as LastEventType,
  @EndUserText.label: 'Thời điểm thao tác gần nhất'
  last_event_at              as LastEventAt,
  @EndUserText.label: 'Người ngồi trước đó'
  last_prev_worker_id        as LastPrevWorkerID,
  last_prev_assign_uuid      as LastPrevAssignUUID,
  last_mover_prev_assign     as LastMoverPrevAssign,
  @EndUserText.label: 'Lý do'
  last_reason_text           as LastReasonText,
  last_actor_user_uuid       as LastActorUserUUID,
  @EndUserText.label: 'Nguồn thao tác'
  last_source_channel        as LastSourceChannel,
  @Semantics.user.createdBy: true
  created_by                 as CreatedBy,
  @Semantics.systemDateTime.createdAt: true
  created_at                 as CreatedAt,
  @Semantics.user.lastChangedBy: true
  last_changed_by            as LastChangedBy,
  @Semantics.systemDateTime.lastChangedAt: true
  last_changed_at            as LastChangedAt,
  @Semantics.systemDateTime.localInstanceLastChangedAt: true
  local_last_changed_at      as LocalLastChangedAt,
  _Assignments
}
