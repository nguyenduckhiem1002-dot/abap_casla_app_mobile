@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Tra cứu Work ID theo lịch sử'
@Search.searchable: true
define view entity ZI_MOB_Work_Hist_VH
  as select from ztb_mob_work
{
  @EndUserText.label: 'Work ID'
  @Search.defaultSearchElement: true
  @ObjectModel.text.element: ['WorkName']
  key work_id as WorkID,
  @EndUserText.label: 'Tên vị trí làm việc'
  @Search.defaultSearchElement: true
  work_name as WorkName,
  @EndUserText.label: 'Nhà máy'
  plant as Plant,
  @EndUserText.label: 'Trung tâm làm việc'
  workcenter as WorkCenter,
  @EndUserText.label: 'Bộ phận'
  bo_phan as BoPhan,
  @EndUserText.label: 'Địa điểm'
  location as Location,
  @EndUserText.label: 'Trạng thái hoạt động'
  is_active as IsActive
}
