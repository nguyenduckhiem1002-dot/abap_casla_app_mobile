@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Phân bổ sản lượng công đoạn'
define root view entity ZR_PP_OpAlloc
  as select from ztb_pp_op_alloc
  composition [0..*] of ZR_PP_EmpAlloc as _Employees
  composition [0..*] of ZR_PP_AllocTxn as _Transactions
{
  key operation_uuid       as OperationUUID,
      production_order     as ProductionOrder,
      operation_no         as Operation,
      plant                as Plant,
      work_center          as WorkCenter,
      @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
      operation_qty        as OperationQuantity,
      uom                  as UnitOfMeasure,
      operation_status     as OperationStatus,
      @Semantics.user.createdBy: true
      created_by           as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at           as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by      as LastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      _Employees,
      _Transactions
}
