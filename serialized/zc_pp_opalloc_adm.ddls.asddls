@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Quản trị điều chỉnh sản lượng'
@Metadata.allowExtensions: true
define root view entity ZC_PP_OpAlloc_Adm
  provider contract transactional_query
  as projection on ZR_PP_OpAlloc
{
  key OperationUUID,
      ProductionOrder,
      Operation,
      MaCongDoan,
      Plant,
      WorkCenter,
      OperationQuantity,
      UnitOfMeasure,
      OperationStatus,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt
}
