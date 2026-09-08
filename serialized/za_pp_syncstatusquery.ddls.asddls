@EndUserText.label: 'Tham số kiểm tra trạng thái đồng bộ'
define abstract entity ZA_PP_SyncStatusQuery
{
  AccessToken : abap.char(128);
  DeviceID : abap.char(120);
  SyncItemUUID : sysuuid_x16;
}
