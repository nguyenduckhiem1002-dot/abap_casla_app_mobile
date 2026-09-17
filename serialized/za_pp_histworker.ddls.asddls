@EndUserText.label: 'Tổng hợp lịch sử theo nhân công'
define abstract entity ZA_PP_HistWorker {
  _Result : association to parent ZA_PP_HistResult;
  WorkerID : abap.char(8);
  WorkerName : abap.char(80);
  @EndUserText.label: 'Vị trí làm việc'
  WorkID : abap.char(30);
  @EndUserText.label: 'Tên vị trí làm việc'
  WorkName : abap.char(100);
  @EndUserText.label: 'Bộ phận'
  BoPhan : abap.char(60);
  @EndUserText.label: 'Địa điểm'
  Location : abap.char(100);
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  AssignedQuantity : abap.quan(15,3);
  @EndUserText.label: 'Tổng chuyển vào'
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  TransferredInQuantity : abap.quan(15,3);
  @EndUserText.label: 'Tổng chuyển ra'
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  TransferredOutQuantity : abap.quan(15,3);
  @EndUserText.label: 'Tổng thu hồi'
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  RecalledQuantity : abap.quan(15,3);
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  CompletedQuantity : abap.quan(15,3);
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  RemainingQuantity : abap.quan(15,3);
  UnitOfMeasure : abap.unit(3);
  TransactionCount : abap.int4;
}
