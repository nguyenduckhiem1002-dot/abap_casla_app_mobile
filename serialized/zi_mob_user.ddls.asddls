@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Tài khoản ứng dụng di động'
define root view entity ZI_MOB_User
  as select from ztb_mob_user
  composition [0..1] of ZI_MOB_Cred    as _Credential
  composition [0..*] of ZI_MOB_Session as _Sessions
  composition [0..*] of ZI_MOB_UsrRol  as _Roles
{
  key user_uuid                as UserUUID,
      username                 as Username,
      normalized_username      as NormalizedUsername,
      full_name                as FullName,
      email                    as Email,
      worker_id                as WorkerID,
      status                   as Status,
      failed_login_count       as FailedLoginCount,
      locked_until             as LockedUntil,
      password_change_required as PasswordChangeRequired,
      first_login_at           as FirstLoginAt,
      last_login_at            as LastLoginAt,
      @Semantics.user.createdBy: true
      created_by               as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at               as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by          as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at          as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at    as LocalLastChangedAt,
      _Credential,
      _Sessions,
      _Roles
}
