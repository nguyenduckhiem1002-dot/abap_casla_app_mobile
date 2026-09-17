@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Tổng hợp phân bổ sản lượng theo công đoạn'
define view entity ZI_PP_EmpAlloc_Agg
  as select from ztb_pp_emp_alloc
{
  key operation_uuid as OperationUUID,
  key uom           as UnitOfMeasure,

  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  sum( initial_assigned_qty ) + sum( transferred_in_qty )
    - sum( transferred_out_qty ) as TotalAssignedQuantity,

  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  sum( recalled_qty ) as TotalRecalledQuantity,

  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  sum( completed_qty ) as TotalCompletedQuantity,

  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  sum( remaining_qty ) as TotalRemainingQuantity
}
group by operation_uuid, uom
