@EndUserText.label: 'Dòng lịch sử giao/nhận việc'
define abstract entity ZA_PP_HistEntry {
  _Result : association to parent ZA_PP_HistResult;
  TransactionUUID : sysuuid_x16;
  ExecutionDate : abap.dats;
  WorkerID : abap.char(8);
  WorkerName : abap.char(80);
  ProductionOrder : abap.char(12);
  Operation : abap.char(4);
  Plant : abap.char(4);
  WorkCenter : abap.char(8);
  TransactionType : abap.char(20);
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  Quantity : abap.quan(15,3);
  UnitOfMeasure : abap.unit(3);
  TransactionStatus : abap.char(20);
}
