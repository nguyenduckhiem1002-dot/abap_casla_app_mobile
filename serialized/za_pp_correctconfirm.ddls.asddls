@EndUserText.label: 'Điều chỉnh sản lượng xác nhận'
define abstract entity ZA_PP_CorrectConfirm
{
  @EndUserText.label: 'Mã giao dịch'
  TransactionUUID : sysuuid_x16;
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  @EndUserText.label: 'Sản lượng sau điều chỉnh'
  NewQuantity : abap.quan(15,3);
  @EndUserText.label: 'Đơn vị tính'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_UnitOfMeasure', element: 'UnitOfMeasure' } }]
  UnitOfMeasure : abap.unit(3);
  @EndUserText.label: 'Mã lý do'
  ReasonCode : abap.char(20);
  @EndUserText.label: 'Nội dung lý do'
  ReasonText : abap.char(255);
}
