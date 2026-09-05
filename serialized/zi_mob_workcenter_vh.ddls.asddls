@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Chọn Work Center'
@Search.searchable: true
define view entity ZI_MOB_WorkCenter_VH
  as select distinct from I_WorkCenter
{
  @EndUserText.label: 'Nhà máy'
  key Plant,
  @EndUserText.label: 'Trung tâm làm việc'
  @Search.defaultSearchElement: true
  @EndUserText.label: 'Trung tâm làm việc'
  key WorkCenter
}
