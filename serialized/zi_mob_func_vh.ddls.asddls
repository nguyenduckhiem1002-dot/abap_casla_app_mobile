@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Trợ giúp chọn chức năng'
@Search.searchable: true
define view entity ZI_MOB_Func_VH
  as select from ztb_mob_func
{
  @EndUserText.label: 'Mã chức năng'
  @Search.defaultSearchElement: true
  @ObjectModel.text.element: ['FuncName']
  key func_id   as FuncID,
  @EndUserText.label: 'Tên chức năng'
  @Search.defaultSearchElement: true
      func_name as FuncName,
  @EndUserText.label: 'Phân hệ ứng dụng'
      app_module as AppModule
}
