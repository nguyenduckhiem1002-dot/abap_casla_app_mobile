@EndUserText.label: 'Tham số chuyển phân bổ'
define abstract entity ZA_PP_Transfer
{
  @EndUserText.label: 'Lệnh sản xuất'
  ProductionOrder : abap.char(12);
  @EndUserText.label: 'Công đoạn lệnh sản xuất'
  Operation : abap.char(4);
  @EndUserText.label: 'Nhân công chuyển'
  FromWorkerID : abap.char(8);
  @EndUserText.label: 'Nhân công nhận'
  ToWorkerID : abap.char(8);
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  @EndUserText.label: 'Số lượng'
  Quantity : abap.quan(15,3);
  @EndUserText.label: 'Đơn vị tính'
  UnitOfMeasure : abap.unit(3);
  @EndUserText.label: 'Ngày thực hiện'
  ExecutionDate : abap.dats;
  @EndUserText.label: 'Token truy cập'
  AccessToken : abap.char(128);
  @EndUserText.label: 'Mã thiết bị'
  DeviceID : abap.char(120);
  @EndUserText.label: 'Mật khẩu nhân công'
  WorkerPassword : abap.char(255);
  @EndUserText.label: 'Mã đồng bộ'
  SyncItemUUID : sysuuid_x16;
}
