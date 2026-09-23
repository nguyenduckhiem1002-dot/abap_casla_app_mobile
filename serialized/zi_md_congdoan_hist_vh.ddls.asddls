@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Tra cứu công đoạn theo lịch sử'
@Search.searchable: true
define view entity ZI_MD_CongDoan_Hist_VH
  as select from ZI_MD_CongDoan
{
  @EndUserText.label: 'Mã công đoạn'
  @Search.defaultSearchElement: true
  @ObjectModel.text.element: ['TenCongDoan']
  key MaCongDoan,
  @EndUserText.label: 'Hiệu lực từ'
  key ValidFrom,
  @EndUserText.label: 'Bộ phận'
  key BoPhan,
  @EndUserText.label: 'Tên công đoạn'
  @Search.defaultSearchElement: true
  TenCongDoan,
  @EndUserText.label: 'Tên vị trí làm việc'
  WorkName,
  @EndUserText.label: 'Nhà máy'
  Plant,
  @EndUserText.label: 'Trung tâm làm việc'
  WorkCenter,
  @EndUserText.label: 'Hiệu lực đến'
  ValidTo
}
