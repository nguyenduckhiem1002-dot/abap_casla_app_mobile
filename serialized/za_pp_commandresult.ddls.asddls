@EndUserText.label: 'Kết quả ghi nhận nghiệp vụ mobile'
define abstract entity ZA_PP_CommandResult
{
  Status : abap.char(20);
  SyncItemUUID : sysuuid_x16;
  TransactionUUID : sysuuid_x16;
  ProductionOrder : abap.char(12);
  Operation : abap.char(4);
  MaCongDoan : abap.char(7);
  @EndUserText.label: 'Vị trí hiện tại'
  PositionID : abap.char(10);
  @EndUserText.label: 'Vị trí gốc'
  OriginPositionID : abap.char(10);
  ErrorCode : abap.char(40);
  Message : abap.char(255);
}
