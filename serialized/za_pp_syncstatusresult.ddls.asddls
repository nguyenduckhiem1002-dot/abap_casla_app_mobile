@EndUserText.label: 'Kết quả kiểm tra trạng thái đồng bộ'
define abstract entity ZA_PP_SyncStatusResult
{
  Status : abap.char(20);
  SyncItemUUID : sysuuid_x16;
  TransactionUUID : sysuuid_x16;
  TransactionType : abap.char(20);
  ProductionOrder : abap.char(12);
  Operation : abap.char(4);
  WorkerID : abap.char(8);
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  Quantity : abap.quan(15,3);
  UnitOfMeasure : abap.unit(3);
  ExecutionDate : abap.dats;
  ErrorCode : abap.char(40);
  Message : abap.char(255);
}
