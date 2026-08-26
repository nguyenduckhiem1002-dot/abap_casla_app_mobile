@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Sổ điều chỉnh sản lượng'
@Metadata.allowExtensions: true
define root view entity ZC_PP_AllocTxn_Adm
  as select from ztb_pp_alloc_txn as txn
    inner join ztb_pp_op_alloc as op
      on op.operation_uuid = txn.operation_uuid
{
  key txn.transaction_uuid          as TransactionUUID,
      txn.operation_uuid            as OperationUUID,
      txn.original_transaction_uuid as OriginalTransactionUUID,
      txn.sync_item_uuid            as SyncItemUUID,
      op.production_order           as ProductionOrder,
      op.operation_no               as Operation,
      op.ma_congdoan                as MaCongDoan,
      op.plant                      as Plant,
      op.work_center                as WorkCenter,
      txn.transaction_type          as TransactionType,
      txn.original_transaction_type as OriginalTransactionType,
      txn.from_worker_id            as FromWorkerID,
      txn.to_worker_id              as ToWorkerID,
      txn.worker_id                 as WorkerID,
      @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
      txn.quantity                  as Quantity,
      txn.uom                       as UnitOfMeasure,
      txn.execution_date            as ExecutionDate,
      txn.transaction_status        as TransactionStatus,
      txn.reason_code               as ReasonCode,
      txn.reason_text               as ReasonText,
      txn.source_channel            as SourceChannel,
      txn.actor_user_uuid           as ActorUserUUID,
      txn.initiator_session_id      as InitiatorSessionID,
      txn.device_id                 as DeviceID,
      txn.verification_method       as VerificationMethod,
      txn.verified_worker_user_uuid as VerifiedWorkerUserUUID,
      txn.worker_verified_at        as WorkerVerifiedAt,
      @Semantics.user.createdBy: true
      txn.created_by                as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      txn.created_at                as CreatedAt
}
