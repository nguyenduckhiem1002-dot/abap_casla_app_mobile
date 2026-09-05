@EndUserText.label: 'Dòng lịch sử giao/nhận việc'
define abstract entity ZA_PP_HistEntry {
  _Result : association to parent ZA_PP_HistResult;
  @EndUserText.label: 'Mã giao dịch'
  TransactionUUID : sysuuid_x16;
  @EndUserText.label: 'Ngày thực hiện'
  ExecutionDate : abap.dats;
  @EndUserText.label: 'Mã nhân công'
  WorkerID : abap.char(8);
  @EndUserText.label: 'Tên nhân công'
  WorkerName : abap.char(80);
  @EndUserText.label: 'Lệnh sản xuất'
  ProductionOrder : abap.char(12);
  @EndUserText.label: 'Công đoạn lệnh sản xuất'
  Operation : abap.char(4);
  @EndUserText.label: 'Nhà máy'
  Plant : abap.char(4);
  @EndUserText.label: 'Trung tâm làm việc'
  WorkCenter : abap.char(8);
  @EndUserText.label: 'Loại giao dịch'
  TransactionType : abap.char(20);
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  @EndUserText.label: 'Số lượng'
  Quantity : abap.quan(15,3);
  @EndUserText.label: 'Đơn vị tính'
  UnitOfMeasure : abap.unit(3);
  @EndUserText.label: 'Trạng thái giao dịch'
  TransactionStatus : abap.char(20);
}
