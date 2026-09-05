@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Quản trị tài khoản'
@Metadata.allowExtensions: true
define root view entity ZC_MOB_User_Adm
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
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_Worker_VH', element: 'WorkerID' } }]
      WorkerID,
  @EndUserText.label: 'Trạng thái'
      Status,
  @EndUserText.label: 'Yêu cầu đổi mật khẩu'
      PasswordChangeRequired,
  @EndUserText.label: 'Lần đăng nhập cuối'
      LastLoginAt,
  @EndUserText.label: 'Thời điểm tạo'
      CreatedAt,
  @EndUserText.label: 'Khóa đến'
      LockedUntil,
  @EndUserText.label: 'Thời điểm cập nhật bản ghi'
      LocalLastChangedAt,
  @EndUserText.label: 'Thời điểm thay đổi cuối'
      LastChangedAt,
      _Roles : redirected to composition child ZC_MOB_UsrRol_Adm
}
