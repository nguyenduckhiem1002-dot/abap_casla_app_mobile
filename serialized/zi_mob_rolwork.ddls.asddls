
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Vị trí làm việc của chức danh'
define view entity ZI_MOB_RolWork
  as select from ztb_mob_rol_wrk
  association to parent ZI_MOB_Role as _Role
    on $projection.RoleID = _Role.RoleID
  association [1..1] to ZI_MOB_Work as _Work
    on $projection.WorkID = _Work.WorkID
{
  key role_id as RoleID,
      @ObjectModel.text.association: '_Work'
  key work_id as WorkID,
      _Role,
      _Work
}
