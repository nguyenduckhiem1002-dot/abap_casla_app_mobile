@EndUserText.label: 'Tổng hợp lịch sử theo nhân công'
define abstract entity ZA_PP_HistWorker {
  _Result : association to parent ZA_PP_HistResult;
  @EndUserText.label: 'Mã nhân công'
  WorkerID : abap.char(8);
  @EndUserText.label: 'Tên nhân công'
  WorkerName : abap.char(80);
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  @EndUserText.label: 'Sản lượng được giao'
  AssignedQuantity : abap.quan(15,3);
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  @EndUserText.label: 'Sản lượng hoàn thành'
  CompletedQuantity : abap.quan(15,3);
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  @EndUserText.label: 'Sản lượng còn lại'
  RemainingQuantity : abap.quan(15,3);
  @EndUserText.label: 'Đơn vị tính'
  UnitOfMeasure : abap.unit(3);
  @EndUserText.label: 'Số giao dịch'
  TransactionCount : abap.int4;
}
