@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Chọn vị trí làm việc'
@Search.searchable: true
// Chỉ vị trí đang dùng. Mỗi vị trí có tối đa một dòng Active nên
// WorkCenter + PositionID là duy nhất trong view này.
define view entity ZI_PP_Position_VH
  as select from ztb_pp_position
{
  @EndUserText.label: 'Work Center'
  @Search.defaultSearchElement: true
  key work_center           as WorkCenter,
  @EndUserText.label: 'Vị trí'
  @Search.defaultSearchElement: true
  key position_id           as PositionID,
  @EndUserText.label: 'Mã máy'
  @Search.defaultSearchElement: true
  machine_id                as MachineID,
  @EndUserText.label: 'Tên vị trí'
  @Search.defaultSearchElement: true
  position_name             as PositionName
}
where status = 'A'
