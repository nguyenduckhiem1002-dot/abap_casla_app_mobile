@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'API tài khoản ứng dụng di động'
define root view entity ZC_MOB_User
  provider contract transactional_query
  as projection on ZI_MOB_User
{
  key UserUUID,
      Username,
      FullName,
      Email,
      Status,
      PasswordChangeRequired,
      LastLoginAt
}
