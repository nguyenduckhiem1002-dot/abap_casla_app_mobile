@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Quản trị master công đoạn'
@Metadata.allowExtensions: true
define root view entity ZC_MD_CongDoan_Adm
  provider contract transactional_query
  as projection on ZI_MD_CongDoan
{
  @EndUserText.label: 'Mã Công Đoạn'
  key MaCongDoan,
  @EndUserText.label: 'Hiệu lực từ'
  key ValidFrom,
      TenCongDoan,
      BoPhan,
      DonGiaXM,
      DonGiaGC,
      ValidTo,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt
}
