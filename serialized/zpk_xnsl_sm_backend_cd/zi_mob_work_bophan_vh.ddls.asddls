@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Trợ giúp chọn bộ phận từ vị trí làm việc'
@Search.searchable: true
define view entity ZI_MOB_Work_BoPhan_VH
  as select distinct from ztb_mob_work
{
      @EndUserText.label: 'Bộ phận'
      @Search.defaultSearchElement: true
      @UI.lineItem: [{ position: 10 }]
  key bo_phan as BoPhan,
  @EndUserText.label: 'Tên Bộ Phận'
  work_name as WorkName
}
where
  is_active = 'A'
  and bo_phan <> ''
