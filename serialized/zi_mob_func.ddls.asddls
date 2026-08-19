@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Chức năng ứng dụng di động'
define root view entity ZI_MOB_Func
  as select from ztb_mob_func
{
  key func_id   as FuncID,
      func_name as FuncName,
      module    as Module
}
