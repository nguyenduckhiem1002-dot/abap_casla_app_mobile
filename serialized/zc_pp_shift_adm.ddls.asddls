@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Danh mục ca làm việc'
@Metadata.allowExtensions: true
@Search.searchable: true
define view entity ZC_PP_Shift_Adm as select from ZI_PP_Shift
{
  @EndUserText.label: 'Nhà máy'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Plant', element: 'Plant' } }]
  @UI.selectionField: [{ position: 10 }]
  key Plant,
  @EndUserText.label: 'Mã ca'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_Shift', element: 'ShiftID' },
    additionalBinding: [{ localElement: 'Plant', element: 'Plant', usage: #FILTER }] }]
  @Search.defaultSearchElement: true
  @ObjectModel.text.element: ['ShiftName']
  @UI.selectionField: [{ position: 20 }]
  key ShiftID,
  @EndUserText.label: 'Hiệu lực từ'
  @UI.selectionField: [{ position: 30 }]
  key ValidFrom,
  @EndUserText.label: 'Tên ca'
  @Search.defaultSearchElement: true
  ShiftName,
  @EndUserText.label: 'Giờ bắt đầu'
  StartTime,
  @EndUserText.label: 'Giờ kết thúc'
  EndTime,
  @EndUserText.label: 'Ngày kết thúc: 0 cùng ngày, 1 hôm sau'
  EndDayOffset,
  @EndUserText.label: 'Múi giờ SAP'
  SAPTimeZone,
  @EndUserText.label: 'Hiệu lực đến'
  ValidTo,
  @EndUserText.label: 'Trạng thái'
  IsActive
}
