@EndUserText.label: 'Điều chỉnh sản lượng xác nhận'
define abstract entity ZA_PP_CorrectConfirm
{
  TransactionUUID : sysuuid_x16;
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  NewQuantity : abap.quan(15,3);
  UnitOfMeasure : abap.unit(3);
  ReasonCode : abap.char(20);
  ReasonText : abap.char(255);
}
