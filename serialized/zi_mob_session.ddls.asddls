@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Phiên đăng nhập di động'
define view entity ZI_MOB_Session
  as select from ztb_mob_session
  association to parent ZI_MOB_User as _User
    on $projection.UserUUID = _User.UserUUID
{
  key session_id            as SessionID,
      user_uuid              as UserUUID,
      access_token_hash      as AccessTokenHash,
      refresh_token_hash     as RefreshTokenHash,
      token_version          as TokenVersion,
      login_at               as LoginAt,
      last_activity_at       as LastActivityAt,
      expires_at             as ExpiresAt,
      refresh_expires_at     as RefreshExpiresAt,
      logout_at              as LogoutAt,
      status                 as Status,
      device_id              as DeviceID,
      revoked_reason         as RevokedReason,
      @Semantics.systemDateTime.createdAt: true
      created_at             as CreatedAt,
      @Semantics.user.createdBy: true
      created_by             as CreatedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at        as LastChangedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by        as LastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at  as LocalLastChangedAt,
      _User
}
