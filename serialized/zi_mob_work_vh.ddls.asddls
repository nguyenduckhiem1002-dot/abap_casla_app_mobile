@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Trợ giúp chọn vị trí làm việc'
@Search.searchable: true
define view entity ZI_MOB_Work_VH
  as select from ztb_mob_work
{
      @EndUserText.label: 'Work ID'
      @Search.defaultSearchElement: true
      @ObjectModel.text.element: ['WorkName']
      @UI.lineItem: [{ position: 10 }]
  @EndUserText.label: 'Work ID'
  key work_id    as WorkID,
      @EndUserText.label: 'Tên vị trí làm việc'
      @Search.defaultSearchElement: true
      @UI.lineItem: [{ position: 20 }]
      work_name  as WorkName,
      @EndUserText.label: 'Nhà máy'
      @UI.lineItem: [{ position: 30 }]
      plant      as Plant,
      @EndUserText.label: 'Trung tâm làm việc'
      @UI.lineItem: [{ position: 40 }]
      workcenter as WorkCenter,
      @EndUserText.label: 'Bộ phận'
      @UI.lineItem: [{ position: 50 }]
      bo_phan    as BoPhan,
      @EndUserText.label: 'Địa điểm'
      @UI.lineItem: [{ position: 60 }]
  @EndUserText.label: 'Địa điểm'
      location   as Location
}
where is_active = 'A'
