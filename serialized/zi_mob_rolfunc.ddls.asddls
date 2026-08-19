@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Phân quyền chức năng cho chức danh'
define view entity ZI_MOB_RolFunc
  as select from ztb_mob_rol_fnc
  association to parent ZI_MOB_Role as _Role
    on $projection.RoleID = _Role.RoleID
  association [1..1] to ZI_MOB_Func as _Func
    on $projection.FuncID = _Func.FuncID
{
  key role_id as RoleID,
  key func_id as FuncID,
      _Role,
      _Func
}
