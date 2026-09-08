@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Tra cứu giao dịch xác nhận'
@Search.searchable: true
define view entity ZI_PP_ConfirmTxn_VH
  as select from ztb_pp_alloc_txn as txn
    inner join ztb_pp_op_alloc as op
      on op.operation_uuid = txn.operation_uuid
    left outer join ztb_pp_alloc_txn as reversal
      on reversal.original_transaction_uuid = txn.transaction_uuid
     and reversal.transaction_type = 'REVERSE'
     and reversal.transaction_status = 'POSTED'
{
  @EndUserText.label: 'Mã giao dịch xác nhận'
  key txn.transaction_uuid as TransactionUUID,
  @EndUserText.label: 'Mã định danh công đoạn'
  key txn.operation_uuid as OperationUUID,
  @EndUserText.label: 'Lệnh sản xuất'
  @Search.defaultSearchElement: true
  op.production_order as ProductionOrder,
  @EndUserText.label: 'Công đoạn lệnh sản xuất'
  op.operation_no as Operation,
  @EndUserText.label: 'Mã nhân công'
  txn.worker_id as WorkerID,
  @EndUserText.label: 'Sản lượng xác nhận'
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  txn.quantity as Quantity,
  @EndUserText.label: 'Đơn vị tính'
  txn.uom as UnitOfMeasure,
  @EndUserText.label: 'Ngày làm việc'
  txn.work_date as WorkDate,
  @EndUserText.label: 'Mã ca'
  txn.shift_id as ShiftID,
  @EndUserText.label: 'Trạng thái giao dịch'
  txn.transaction_status as TransactionStatus
}
where txn.transaction_type = 'CONFIRM'
  and txn.transaction_status = 'POSTED'
  and reversal.transaction_uuid is null
