@EndUserText.label: 'Tham số điều chỉnh sản lượng giao'
define abstract entity ZA_PP_AdjustAllocation
{
  @EndUserText.label: 'Chênh lệch sản lượng giao'
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  AdjustmentQuantity : abap.quan(15,3);

  @EndUserText.label: 'Đơn vị tính'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_UnitOfMeasure', element: 'UnitOfMeasure' } }]
  UnitOfMeasure : abap.unit(3);

  @EndUserText.label: 'Mã lý do'
  ReasonCode : abap.char(20);

  @EndUserText.label: 'Nội dung lý do'
  ReasonText : abap.char(255);

  @EndUserText.label: 'Ngày làm việc'
  ExecutionDate : abap.dats;

  @EndUserText.label: 'Mã ca'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_Shift', element: 'ShiftID' } }]
  ShiftID : abap.char(10);
}
