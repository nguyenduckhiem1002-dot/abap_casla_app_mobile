@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Phân bổ sản lượng theo nhân công'
@Metadata.allowExtensions: true
define view entity ZC_PP_EmpAlloc_Adm
  as projection on ZR_PP_EmpAlloc
{
  @EndUserText.label: 'Mã phân bổ'
  key EmployeeAllocationUUID,
  @EndUserText.label: 'Mã định danh công đoạn'
  OperationUUID,
  @EndUserText.label: 'Lệnh sản xuất'
  _Operation.ProductionOrder as ProductionOrder,
  @EndUserText.label: 'Công đoạn'
  _Operation.Operation as Operation,
  @EndUserText.label: 'Mã công đoạn'
  _Operation.MaCongDoan as MaCongDoan,
  @EndUserText.label: 'Nhà máy'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Plant', element: 'Plant' } }]
  _Operation.Plant as Plant,
  @EndUserText.label: 'Trung tâm làm việc'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MOB_WorkCenter_VH', element: 'WorkCenter' },
    additionalBinding: [{ localElement: 'Plant', element: 'Plant', usage: #FILTER }] }]
  _Operation.WorkCenter as WorkCenter,
  @EndUserText.label: 'Mã nhân công'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_Worker_Hist_VH', element: 'WorkerID' },
    additionalBinding: [
      { localElement: 'Plant', element: 'Plant', usage: #FILTER },
      { localElement: 'WorkCenter', element: 'WorkCenter', usage: #FILTER }
    ] }]
  WorkerID,
  @EndUserText.label: 'Sản lượng giao ban đầu'
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  InitialAssignedQuantity,
  @EndUserText.label: 'Sản lượng nhận điều chuyển'
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  TransferredInQuantity,
  @EndUserText.label: 'Sản lượng điều chuyển đi'
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  TransferredOutQuantity,
  @EndUserText.label: 'Sản lượng đã thu hồi'
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  RecalledQuantity,
  @EndUserText.label: 'Sản lượng đã xác nhận'
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  CompletedQuantity,
  @EndUserText.label: 'Sản lượng còn lại'
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  RemainingQuantity,
  @EndUserText.label: 'Đơn vị tính'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_UnitOfMeasure', element: 'UnitOfMeasure' } }]
  UnitOfMeasure,
  @EndUserText.label: 'Ngày thực hiện cuối'
  LastExecutionDate,
  @EndUserText.label: 'Lần đồng bộ cuối'
  LastSyncAt,
  @EndUserText.label: 'Người tạo'
  CreatedBy,
  @EndUserText.label: 'Thời điểm tạo'
  CreatedAt,
  @EndUserText.label: 'Người thay đổi cuối'
  LastChangedBy,
  @EndUserText.label: 'Thời điểm cập nhật bản ghi'
  LocalLastChangedAt,
  _Operation : redirected to parent ZC_PP_OpAlloc_Adm
}
