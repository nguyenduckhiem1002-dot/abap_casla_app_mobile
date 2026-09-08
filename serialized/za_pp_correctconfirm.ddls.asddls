@EndUserText.label: 'Điều chỉnh sản lượng xác nhận'
define abstract entity ZA_PP_CorrectConfirm
{
  @EndUserText.label: 'Mã giao dịch xác nhận'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_CONFIRM_TXN_VH', element: 'TransactionUUID' },
    additionalBinding: [{ localElement: 'UnitOfMeasure', element: 'UnitOfMeasure', usage: #RESULT }] }]
  TransactionUUID : sysuuid_x16;
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  @EndUserText.label: 'Sản lượng xác nhận mới'
  NewQuantity : abap.quan(15,3);
  @EndUserText.label: 'Đơn vị tính'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_UnitOfMeasure', element: 'UnitOfMeasure' } }]
  UnitOfMeasure : abap.unit(3);
  @EndUserText.label: 'Mã lý do'
  ReasonCode : abap.char(20);
  @EndUserText.label: 'Nội dung lý do'
  ReasonText : abap.char(255);
}
