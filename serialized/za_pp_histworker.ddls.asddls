@EndUserText.label: 'Tổng hợp lịch sử theo nhân công'
define abstract entity ZA_PP_HistWorker {
  _Result : association to parent ZA_PP_HistResult;
  WorkerID : abap.char(8);
  WorkerName : abap.char(80);
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  AssignedQuantity : abap.quan(15,3);
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  CompletedQuantity : abap.quan(15,3);
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  RemainingQuantity : abap.quan(15,3);
  UnitOfMeasure : abap.unit(3);
  TransactionCount : abap.int4;
}
