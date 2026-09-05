@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Vị trí làm việc của chức danh (Admin)'
@Metadata.allowExtensions: true
define view entity ZC_MOB_RolWork_Adm
  as projection on ZI_MOB_RolWork
{
  @EndUserText.label: 'Mã chức danh'
  key RoleID,
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MOB_Work_VH', element: 'WorkID' } }]
  @EndUserText.label: 'Work ID'
  key WorkID,
  @EndUserText.label: 'Tên vị trí làm việc'
      WorkName,
  @EndUserText.label: 'Nhà máy'
      Plant,
  @EndUserText.label: 'Trung tâm làm việc'
      WorkCenter,
  @EndUserText.label: 'Bộ phận'
      BoPhan,
  @EndUserText.label: 'Địa điểm'
      Location,
      _Role : redirected to parent ZC_MOB_Role_Adm,
      _Work : redirected to ZC_MOB_Work_Adm
}
