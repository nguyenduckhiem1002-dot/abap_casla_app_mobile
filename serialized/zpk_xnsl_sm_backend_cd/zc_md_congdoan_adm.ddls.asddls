@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Quản trị master công đoạn'
@Metadata.allowExtensions: true
define root view entity ZC_MD_CongDoan_Adm
  provider contract transactional_query
  as projection on ZI_MD_CongDoan
{
  @EndUserText.label: 'Mã Công Đoạn'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MD_CongDoan_Hist_VH', element: 'MaCongDoan' } }]
  key MaCongDoan,
  @EndUserText.label: 'Hiệu lực từ'
  key ValidFrom,
  @EndUserText.label: 'Bộ phận'
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZI_MOB_Work_BoPhan_VH', element: 'BoPhan' },
    useForValidation: true
  }]
  key BoPhan,
  @EndUserText.label: 'Tên công đoạn'
      TenCongDoan,
  @EndUserText.label: 'Tên vị trí làm việc'
      WorkName,
  @EndUserText.label: 'Nhà máy'
      Plant,
  @EndUserText.label: 'Trung tâm làm việc'
      WorkCenter,
  @EndUserText.label: 'Đơn giá XM'
      DonGiaXM,
  @EndUserText.label: 'Đơn giá GC'
      DonGiaGC,
  @EndUserText.label: 'Hiệu lực đến'
      ValidTo,
  @EndUserText.label: 'Người tạo'
      CreatedBy,
  @EndUserText.label: 'Thời điểm tạo'
      CreatedAt,
  @EndUserText.label: 'Người thay đổi cuối'
      LastChangedBy,
  @EndUserText.label: 'Thời điểm thay đổi cuối'
      LastChangedAt,
  @EndUserText.label: 'Thời điểm cập nhật bản ghi'
      LocalLastChangedAt
}
