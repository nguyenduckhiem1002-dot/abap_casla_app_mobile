@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Chọn nhân công'
@Search.searchable: true
define view entity ZI_PP_Worker_VH
  as select distinct from ZI_PP_WorkerRef
{
  @EndUserText.label: 'Mã nhân công'
  @Search.defaultSearchElement: true
  key WorkerID,
  @EndUserText.label: 'Tên nhân công'
  @Search.defaultSearchElement: true
  key WorkerName,
  @EndUserText.label: 'Nhà máy'
  key Plant,
  @EndUserText.label: 'Trung tâm làm việc'
  key WorkCenter
}
where ValidFrom <= $session.system_date
  and ValidTo >= $session.system_date
