@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Phân chức danh cho người dùng'
define view entity ZI_MOB_UsrRol
  as select from ztb_mob_usr_rol
  association to parent ZI_MOB_User as _User
    on $projection.UserUUID = _User.UserUUID
  association [1..1] to ZI_MOB_Role as _Role
    on $projection.RoleID = _Role.RoleID
{
  key user_uuid as UserUUID,
  key role_id   as RoleID,
      _User,
      _Role
}
