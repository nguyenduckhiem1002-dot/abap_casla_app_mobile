@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Vị trí làm việc của chức danh'
define view entity ZI_MOB_RolWork
  as select from ztb_mob_rol_wrk
  association to parent ZI_MOB_Role as _Role
    on $projection.RoleID = _Role.RoleID
  association [1..1] to ZI_MOB_Work as _Work
    on $projection.WorkID = _Work.WorkID
{
  key role_id        as RoleID,
  key work_id        as WorkID,
      _Work.WorkName as WorkName,
      _Work.Plant    as Plant,
      _Work.WorkCenter as WorkCenter,
      _Work.BoPhan   as BoPhan,
      _Work.Location as Location,
      _Role,
      _Work
}
