@EndUserText.label: 'Tham số điều chỉnh sản lượng'
define abstract entity ZA_PP_AdjustAllocation
{
  @EndUserText.label: 'Loại điều chỉnh (ASSIGN/RECALL/CONFIRM)'
  AdjustmentType : zde_adjustmenttype;
  @EndUserText.label: 'Số lượng mới'
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  TargetQuantity : abap.quan(15,3);

  @EndUserText.label: 'Đơn vị tính'
  @UI.hidden     : true
  UnitOfMeasure  : abap.unit(3);
  @EndUserText.label: 'Mã lý do'
  ReasonCode     : abap.char(20);
  @EndUserText.label: 'Nội dung lý do'
  ReasonText     : abap.char(255);
  @EndUserText.label: 'Ngày làm việc'
  ExecutionDate  : abap.dats;
  @EndUserText.label: 'Mã ca'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_Shift', element: 'ShiftID' } }]
  ShiftID        : abap.char(10);
}
