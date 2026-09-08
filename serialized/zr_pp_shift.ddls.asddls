@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cấu hình ca làm việc'
@Metadata.allowExtensions: true
define root view entity ZR_PP_Shift
  as select from ztb_pp_shift
{
  @EndUserText.label: 'Nhà máy'
  key plant as Plant,
  @EndUserText.label: 'Mã ca'
  key shift_id as ShiftID,
  @EndUserText.label: 'Hiệu lực từ'
  key valid_from as ValidFrom,
  @EndUserText.label: 'Tên ca'
  shift_name as ShiftName,
  @EndUserText.label: 'Giờ bắt đầu'
  start_time as StartTime,
  @EndUserText.label: 'Giờ kết thúc'
  end_time as EndTime,
  @EndUserText.label: 'Ngày kết thúc: 0 cùng ngày, 1 hôm sau'
  end_day_offset as EndDayOffset,
  @EndUserText.label: 'Múi giờ SAP'
  time_zone as SAPTimeZone,
  @EndUserText.label: 'Hiệu lực đến'
  valid_to as ValidTo,
  @EndUserText.label: 'Trạng thái'
  is_active as IsActive,
  @Semantics.user.createdBy: true
  created_by as CreatedBy,
  @Semantics.systemDateTime.createdAt: true
  created_at as CreatedAt,
  @Semantics.user.lastChangedBy: true
  last_changed_by as LastChangedBy,
  @Semantics.systemDateTime.lastChangedAt: true
  last_changed_at as LastChangedAt,
  @Semantics.systemDateTime.localInstanceLastChangedAt: true
  local_last_changed_at as LocalLastChangedAt
}
