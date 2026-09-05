@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Quản trị điều chỉnh sản lượng'
@Metadata.allowExtensions: true
define root view entity ZC_PP_OpAlloc_Adm
  provider contract transactional_query
  as projection on ZR_PP_OpAlloc
{
  @EndUserText.label: 'Mã định danh công đoạn'
  key OperationUUID,
  @EndUserText.label: 'Lệnh sản xuất'
      ProductionOrder,
  @EndUserText.label: 'Công đoạn lệnh sản xuất'
      Operation,
  @EndUserText.label: 'Mã công đoạn'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MD_CongDoan_VH', element: 'MaCongDoan' } }]
      MaCongDoan,
  @EndUserText.label: 'Nhà máy'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Plant', element: 'Plant' } }]
      Plant,
  @EndUserText.label: 'Trung tâm làm việc'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MOB_WorkCenter_VH', element: 'WorkCenter' },
    additionalBinding: [{ localElement: 'Plant', element: 'Plant', usage: #FILTER }] }]
      WorkCenter,
  @EndUserText.label: 'Sản lượng công đoạn'
      OperationQuantity,
  @EndUserText.label: 'Đơn vị tính'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_UnitOfMeasure', element: 'UnitOfMeasure' } }]
      UnitOfMeasure,
  @EndUserText.label: 'Trạng thái công đoạn'
      OperationStatus,
  @EndUserText.label: 'Người tạo'
      CreatedBy,
  @EndUserText.label: 'Thời điểm tạo'
      CreatedAt,
  @EndUserText.label: 'Người thay đổi cuối'
      LastChangedBy,
  @EndUserText.label: 'Thời điểm cập nhật bản ghi'
      LocalLastChangedAt
}
