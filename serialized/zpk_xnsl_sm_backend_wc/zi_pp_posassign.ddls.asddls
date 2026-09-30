@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Lịch sử công nhân ngồi vị trí'
@UI.headerInfo: {
  typeName: 'Lượt ngồi vị trí',
  typeNamePlural: 'Lịch sử người ngồi'
}
// Append-only: chỉ được ghi bởi additional save của ZR_PP_Position. Mỗi dòng
// là một khoảng thời gian một công nhân ngồi một vị trí; dòng đã đóng không
// bao giờ bị sửa lại, nên câu hỏi "lúc đó ai ngồi đâu" luôn trả lời được.
define view entity ZI_PP_PosAssign
  as select from ztb_pp_pos_asgn
{
  @UI.hidden: true
  key assign_uuid            as AssignUUID,
  @EndUserText.label: 'Work Center'
  work_center                as WorkCenter,
  @EndUserText.label: 'Vị trí'
  position_id                as PositionID,
  @EndUserText.label: 'Mã công nhân'
  @UI.lineItem: [{ position: 10 }]
  worker_id                  as WorkerID,
  @EndUserText.label: 'Trạng thái'
  @UI.lineItem: [{ position: 20 }]
  status                     as Status,
  @EndUserText.label: 'Ngồi từ'
  @UI.lineItem: [{ position: 30 }]
  valid_from_at              as ValidFromAt,
  @EndUserText.label: 'Ngồi đến'
  @UI.lineItem: [{ position: 40 }]
  valid_to_at                as ValidToAt,
  @EndUserText.label: 'Lý do kết thúc'
  @UI.lineItem: [{ position: 50 }]
  end_reason                 as EndReason,
  @EndUserText.label: 'Lý do xếp ghế'
  @UI.lineItem: [{ position: 60 }]
  reason_text                as ReasonText,
  @EndUserText.label: 'Ghi chú khi rời ghế'
  @UI.lineItem: [{ position: 70 }]
  end_reason_text            as EndReasonText,
  @EndUserText.label: 'Nguồn xếp ghế'
  @UI.lineItem: [{ position: 80 }]
  source_channel             as SourceChannel,
  @EndUserText.label: 'Nguồn rời ghế'
  end_source_channel         as EndSourceChannel,
  @UI.hidden: true
  previous_assign_uuid       as PreviousAssignUUID,
  @UI.hidden: true
  start_event_uuid           as StartEventUUID,
  @UI.hidden: true
  end_event_uuid             as EndEventUUID,
  @UI.hidden: true
  actor_user_uuid            as ActorUserUUID,
  @UI.hidden: true
  end_actor_user_uuid        as EndActorUserUUID,
  @EndUserText.label: 'Người tạo'
  created_by                 as CreatedBy,
  @EndUserText.label: 'Thời điểm tạo'
  created_at                 as CreatedAt
}
