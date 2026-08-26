@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Quản trị tài khoản giám sát'
@Metadata.allowExtensions: true
define root view entity ZC_MOB_User_Adm
  provider contract transactional_query
  as projection on ZI_MOB_User
{
  key UserUUID,
      Username,
      FullName,
      Email,
      WorkerID,
      Status,
      PasswordChangeRequired,
      LastLoginAt,
      CreatedAt,
      _Roles : redirected to composition child ZC_MOB_UsrRol_Adm
}
