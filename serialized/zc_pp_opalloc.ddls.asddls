@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'API phân bổ sản lượng công đoạn'
define root view entity ZC_PP_OpAlloc
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
      MaCongDoan,
  @EndUserText.label: 'Nhà máy'
      Plant,
  @EndUserText.label: 'Trung tâm làm việc'
      WorkCenter,
  @EndUserText.label: 'Sản lượng công đoạn'
      OperationQuantity,
  @EndUserText.label: 'Đơn vị tính'
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
