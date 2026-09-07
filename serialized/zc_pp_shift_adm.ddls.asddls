@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Danh mục ca làm việc'
@Metadata.allowExtensions: true
@Search.searchable: true
define view entity ZC_PP_Shift_Adm as select from ZI_PP_Shift
{
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Plant', element: 'Plant' } }]
  key Plant,
  @ObjectModel.text.element: ['ShiftName']
  @Search.defaultSearchElement: true
  key ShiftID,
  key ValidFrom,
  @Search.defaultSearchElement: true
  ShiftName,
  StartTime,
  EndTime,
  EndDayOffset,
  TimeZone,
  ValidTo,
  @ObjectModel.text.element: ['StatusText']
  IsActive,
  @EndUserText.label: 'Tên trạng thái'
  case IsActive
    when 'A' then 'Đang hoạt động'
    when 'I' then 'Ngừng hoạt động'
    else 'Không xác định'
  end as StatusText
}
