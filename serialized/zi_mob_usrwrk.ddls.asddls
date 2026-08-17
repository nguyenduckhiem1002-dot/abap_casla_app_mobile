@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Liên kết tài khoản và nhân công'
define view entity ZI_MOB_UsrWrk
  as select from ztb_mob_usr_wrk
  association to parent ZI_MOB_User as _User
    on $projection.UserUUID = _User.UserUUID
{
  key user_worker_uuid     as UserWorkerUUID,
      user_uuid            as UserUUID,
      worker_id            as WorkerID,
      plant                as Plant,
      work_center          as WorkCenter,
      valid_from           as ValidFrom,
      valid_to             as ValidTo,
      status               as Status,
      created_by           as CreatedBy,
      created_at           as CreatedAt,
      last_changed_by      as LastChangedBy,
      last_changed_at      as LastChangedAt,
      local_last_changed_at as LocalLastChangedAt,
      _User
}
