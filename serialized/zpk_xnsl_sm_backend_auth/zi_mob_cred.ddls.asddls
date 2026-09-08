@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Thông tin xác thực di động'
define view entity ZI_MOB_Cred
  as select from ztb_mob_cred
  association to parent ZI_MOB_User as _User
    on $projection.UserUUID = _User.UserUUID
{
  key user_uuid           as UserUUID,
      password_hash       as PasswordHash,
      password_salt       as PasswordSalt,
      hash_algorithm      as HashAlgorithm,
      hash_iterations     as HashIterations,
      password_changed_at as PasswordChangedAt,
      credential_status   as CredentialStatus,
      _User
}
