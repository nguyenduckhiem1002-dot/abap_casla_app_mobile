@EndUserText.label: 'Tham số đảo giao dịch xác nhận'
define abstract entity ZA_PP_Reverse
{
  ProductionOrder : abap.char(12);
  Operation : abap.char(4);
  TransactionUUID : sysuuid_x16;
  Reason : abap.char(120);
  AccessToken : abap.char(128);
  DeviceID : abap.char(120);
  SyncItemUUID : sysuuid_x16;
}
