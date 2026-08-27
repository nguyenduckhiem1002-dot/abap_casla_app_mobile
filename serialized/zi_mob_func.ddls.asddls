
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Chức năng ứng dụng di động'
define root view entity ZI_MOB_Func
  as select from ztb_mob_func
{
  key func_id as FuncID,
      @Semantics.text: true
      func_name as FuncName,
      app_module as AppModule,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt
}
