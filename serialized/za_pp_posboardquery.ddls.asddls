@EndUserText.label: 'Tham số xem sơ đồ vị trí công nhân'
define abstract entity ZA_PP_PosBoardQuery
{
  AccessToken : abap.char(128);
  DeviceID    : abap.char(120);
  // Để trống: trả tất cả Work Center trong phạm vi quyền.
  WorkCenter  : abap.char(8);
}
