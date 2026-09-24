@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'API cấu hình ca làm việc'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZC_PP_SHIFT provider contract transactional_query
  as projection on ZR_PP_Shift
{
    key Plant,
    key ShiftID,
    key ValidFrom,
    ShiftName,
    StartTime,
    EndTime,
    EndDayOffset,
    SAPTimeZone,
    ValidTo,
    IsActive,
    CreatedBy,
    CreatedAt,
    LastChangedBy,
    LastChangedAt,
    LocalLastChangedAt
}
