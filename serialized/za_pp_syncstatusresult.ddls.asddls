@EndUserText.label: 'Kết quả kiểm tra trạng thái đồng bộ'
define abstract entity ZA_PP_SyncStatusResult
{
  @EndUserText.label: 'Trạng thái'
  Status : abap.char(20);
  @EndUserText.label: 'Mã đồng bộ'
  SyncItemUUID : sysuuid_x16;
  @EndUserText.label: 'Mã giao dịch'
  TransactionUUID : sysuuid_x16;
  @EndUserText.label: 'Loại giao dịch'
  TransactionType : abap.char(20);
  @EndUserText.label: 'Lệnh sản xuất'
  ProductionOrder : abap.char(12);
  @EndUserText.label: 'Công đoạn lệnh sản xuất'
  Operation : abap.char(4);
  @EndUserText.label: 'Mã nhân công'
  WorkerID : abap.char(8);
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  @EndUserText.label: 'Số lượng'
  Quantity : abap.quan(15,3);
  @EndUserText.label: 'Đơn vị tính'
  UnitOfMeasure : abap.unit(3);
  @EndUserText.label: 'Ngày thực hiện'
  ExecutionDate : abap.dats;
  @EndUserText.label: 'Mã lỗi'
  ErrorCode : abap.char(40);
  @EndUserText.label: 'Thông báo'
  Message : abap.char(255);
}
