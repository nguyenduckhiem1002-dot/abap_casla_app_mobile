@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Tài khoản ứng dụng di động'
define root view entity ZI_MOB_User
  as select from ztb_mob_user
  composition [0..1] of ZI_MOB_Cred    as _Credential
  composition [0..*] of ZI_MOB_Session as _Sessions
  composition [0..*] of ZI_MOB_UsrWrk  as _WorkerMappings
{
  key user_uuid                as UserUUID,
      username                 as Username,
      normalized_username      as NormalizedUsername,
      full_name                as FullName,
      email                    as Email,
      status                   as Status,
      failed_login_count       as FailedLoginCount,
      locked_until             as LockedUntil,
      password_change_required as PasswordChangeRequired,
      first_login_at           as FirstLoginAt,
      last_login_at            as LastLoginAt,
      created_by               as CreatedBy,
      created_at               as CreatedAt,
      last_changed_by          as LastChangedBy,
      last_changed_at          as LastChangedAt,
      local_last_changed_at    as LocalLastChangedAt,
      _Credential,
      _Sessions,
      _WorkerMappings
}
