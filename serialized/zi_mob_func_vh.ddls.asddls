@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Trợ giúp chọn chức năng'
define view entity ZI_MOB_Func_VH
  as select from ztb_mob_func
{
  key func_id   as FuncID,
      func_name as FuncName,
      app_module as AppModule
}
