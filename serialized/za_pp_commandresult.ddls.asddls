@EndUserText.label: 'Kết quả ghi nhận nghiệp vụ mobile'
define abstract entity ZA_PP_CommandResult
{
  @EndUserText.label: 'Trạng thái'
  Status : abap.char(20);
  @EndUserText.label: 'Mã đồng bộ'
  SyncItemUUID : sysuuid_x16;
  @EndUserText.label: 'Mã giao dịch'
  TransactionUUID : sysuuid_x16;
  @EndUserText.label: 'Lệnh sản xuất'
  ProductionOrder : abap.char(12);
  @EndUserText.label: 'Công đoạn lệnh sản xuất'
  Operation : abap.char(4);
  @EndUserText.label: 'Mã công đoạn'
  MaCongDoan : abap.char(7);
  @EndUserText.label: 'Mã lỗi'
  ErrorCode : abap.char(40);
  @EndUserText.label: 'Thông báo'
  Message : abap.char(255);
}
