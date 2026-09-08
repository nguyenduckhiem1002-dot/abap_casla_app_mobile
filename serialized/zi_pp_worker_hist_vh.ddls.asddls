@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Tra cứu nhân công theo lịch sử'
@Search.searchable: true
define view entity ZI_PP_Worker_Hist_VH
  as select from ZI_PP_WorkerRef
{
  @EndUserText.label: 'Định danh nhân công'
  key WorkerUUID,
  @EndUserText.label: 'Mã nhân công'
  @Search.defaultSearchElement: true
  WorkerID,
  @EndUserText.label: 'Tên nhân công'
  @Search.defaultSearchElement: true
  WorkerName,
  @EndUserText.label: 'Nhà máy'
  Plant,
  @EndUserText.label: 'Trung tâm làm việc'
  WorkCenter,
  @EndUserText.label: 'Hiệu lực từ'
  ValidFrom,
  @EndUserText.label: 'Hiệu lực đến'
  ValidTo
}
