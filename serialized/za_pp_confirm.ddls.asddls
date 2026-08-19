@EndUserText.label: 'Tham số xác nhận sản lượng'
define abstract entity ZA_PP_Confirm
{
  WorkerID : abap.char(8);
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  Quantity : abap.quan(15,3);
  UnitOfMeasure : abap.unit(3);
  ExecutionDate : abap.dats;
  AccessToken : abap.char(128);
  DeviceID : abap.char(120);
  WorkerPassword : abap.char(255);
}
