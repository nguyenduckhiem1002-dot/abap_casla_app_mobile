@EndUserText.label: 'Tham số đảo giao dịch xác nhận'
define abstract entity ZA_PP_Reverse
{
  @EndUserText.label: 'Lệnh sản xuất'
  ProductionOrder : abap.char(12);
  @EndUserText.label: 'Công đoạn lệnh sản xuất'
  Operation : abap.char(4);
  @EndUserText.label: 'Mã giao dịch'
  TransactionUUID : sysuuid_x16;
  @EndUserText.label: 'Lý do'
  Reason : abap.char(120);
  @EndUserText.label: 'Token truy cập'
  AccessToken : abap.char(128);
  @EndUserText.label: 'Mã thiết bị'
  DeviceID : abap.char(120);
  @EndUserText.label: 'Mã đồng bộ'
  SyncItemUUID : sysuuid_x16;
}
