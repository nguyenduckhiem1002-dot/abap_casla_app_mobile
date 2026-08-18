@EndUserText.label: 'Kết quả đăng nhập di động'
define abstract entity ZA_MOB_LoginResult {
  UserUUID : sysuuid_x16;
  SessionID : sysuuid_x16;
  AccessToken : abap.char(128);
  RefreshToken : abap.char(128);
  ExpiresAt : abap.utclong;
  Status : abap.char(1);
  PasswordChangeRequired : abap_boolean;
}
