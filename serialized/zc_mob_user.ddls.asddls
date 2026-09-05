@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'API tài khoản ứng dụng di động'
define root view entity ZC_MOB_User
  provider contract transactional_query
  as projection on ZI_MOB_User
{
  @EndUserText.label: 'Mã định danh người dùng'
  key UserUUID,
  @EndUserText.label: 'Tên đăng nhập'
      Username,
  @EndUserText.label: 'Họ và tên'
      FullName,
  @EndUserText.label: 'Email'
      Email,
  @EndUserText.label: 'Mã nhân công'
      WorkerID,
  @EndUserText.label: 'Trạng thái'
      Status,
  @EndUserText.label: 'Yêu cầu đổi mật khẩu'
      PasswordChangeRequired,
  @EndUserText.label: 'Lần đăng nhập cuối'
      LastLoginAt
}
