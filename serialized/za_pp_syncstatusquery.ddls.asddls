@EndUserText.label: 'Tham số kiểm tra trạng thái đồng bộ'
define abstract entity ZA_PP_SyncStatusQuery
{
  @EndUserText.label: 'Token truy cập'
  AccessToken : abap.char(128);
  @EndUserText.label: 'Mã thiết bị'
  DeviceID : abap.char(120);
  @EndUserText.label: 'Mã đồng bộ'
  SyncItemUUID : sysuuid_x16;
}
