@EndUserText.label: 'Kết quả đăng nhập di động'
define root abstract entity ZA_MOB_LoginResult
{
  @EndUserText.label: 'Mã định danh người dùng'
  UserUUID : sysuuid_x16;
  @EndUserText.label: 'Mã phiên'
  SessionID : sysuuid_x16;
  @EndUserText.label: 'Token truy cập'
  AccessToken : abap.char(128);
  @EndUserText.label: 'Token làm mới'
  RefreshToken : abap.char(128);
  @EndUserText.label: 'Hết hạn lúc'
  ExpiresAt : abap.utclong;
  @EndUserText.label: 'Trạng thái'
  Status : abap.char(1);
  PasswordChangeRequired : abap_boolean;
  _Permissions : composition [0..*] of ZA_MOB_Permission;
  _WorkContexts : composition [0..*] of ZA_MOB_WorkContext;
}
