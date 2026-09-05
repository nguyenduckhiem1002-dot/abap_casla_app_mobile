
@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Quản trị vị trí làm việc'
@Metadata.allowExtensions: true
define root view entity ZC_MOB_Work_Adm
  provider contract transactional_query
  as projection on ZI_MOB_Work
{
  @EndUserText.label: 'Work ID'
key WorkID,
  @EndUserText.label: 'Tên vị trí làm việc'
WorkName,
  @EndUserText.label: 'Nhà máy'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Plant', element: 'Plant' } }]
Plant,
  @EndUserText.label: 'Trung tâm làm việc'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MOB_WorkCenter_VH', element: 'WorkCenter' },
    additionalBinding: [{ localElement: 'Plant', element: 'Plant', usage: #FILTER_AND_RESULT }] }]
WorkCenter,
  @EndUserText.label: 'Bộ phận'
BoPhan,
  @EndUserText.label: 'Địa điểm'
Location,
  @EndUserText.label: 'Trạng thái hoạt động'
IsActive,
  @EndUserText.label: 'Thời điểm thay đổi cuối'
LastChangedAt,
  @EndUserText.label: 'Thời điểm cập nhật bản ghi'
LocalLastChangedAt
}
