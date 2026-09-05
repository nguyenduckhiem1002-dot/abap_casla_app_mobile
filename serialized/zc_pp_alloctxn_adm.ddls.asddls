@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Sổ điều chỉnh sản lượng'
@Metadata.allowExtensions: true
define root view entity ZC_PP_AllocTxn_Adm
  as select from ztb_pp_alloc_txn as txn
    inner join ztb_pp_op_alloc as op
      on op.operation_uuid = txn.operation_uuid
{
  @EndUserText.label: 'Mã giao dịch'
  key txn.transaction_uuid          as TransactionUUID,
  @EndUserText.label: 'Mã định danh công đoạn'
      txn.operation_uuid            as OperationUUID,
  @EndUserText.label: 'Mã giao dịch gốc'
      txn.original_transaction_uuid as OriginalTransactionUUID,
  @EndUserText.label: 'Mã đồng bộ'
      txn.sync_item_uuid            as SyncItemUUID,
  @EndUserText.label: 'Lệnh sản xuất'
      op.production_order           as ProductionOrder,
  @EndUserText.label: 'Công đoạn lệnh sản xuất'
      op.operation_no               as Operation,
  @EndUserText.label: 'Mã công đoạn'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MD_CongDoan_VH', element: 'MaCongDoan' } }]
      op.ma_congdoan                as MaCongDoan,
  @EndUserText.label: 'Nhà máy'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Plant', element: 'Plant' } }]
      op.plant                      as Plant,
  @EndUserText.label: 'Trung tâm làm việc'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MOB_WorkCenter_VH', element: 'WorkCenter' },
    additionalBinding: [{ localElement: 'Plant', element: 'Plant', usage: #FILTER }] }]
      op.work_center                as WorkCenter,
  @EndUserText.label: 'Loại giao dịch'
      txn.transaction_type          as TransactionType,
  @EndUserText.label: 'Loại giao dịch gốc'
      txn.original_transaction_type as OriginalTransactionType,
  @EndUserText.label: 'Nhân công chuyển'
      txn.from_worker_id            as FromWorkerID,
  @EndUserText.label: 'Nhân công nhận'
      txn.to_worker_id              as ToWorkerID,
  @EndUserText.label: 'Mã nhân công'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_Worker_VH', element: 'WorkerID' } }]
      txn.worker_id                 as WorkerID,
      @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  @EndUserText.label: 'Số lượng'
      txn.quantity                  as Quantity,
  @EndUserText.label: 'Đơn vị tính'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_UnitOfMeasure', element: 'UnitOfMeasure' } }]
      txn.uom                       as UnitOfMeasure,
  @EndUserText.label: 'Ngày thực hiện'
      txn.execution_date            as ExecutionDate,
  @EndUserText.label: 'Trạng thái giao dịch'
      txn.transaction_status        as TransactionStatus,
  @EndUserText.label: 'Mã lý do'
      txn.reason_code               as ReasonCode,
  @EndUserText.label: 'Nội dung lý do'
      txn.reason_text               as ReasonText,
  @EndUserText.label: 'Nguồn giao dịch'
      txn.source_channel            as SourceChannel,
  @EndUserText.label: 'Người thực hiện'
      txn.actor_user_uuid           as ActorUserUUID,
  @EndUserText.label: 'Phiên thực hiện'
      txn.initiator_session_id      as InitiatorSessionID,
  @EndUserText.label: 'Mã thiết bị'
      txn.device_id                 as DeviceID,
  @EndUserText.label: 'Phương thức xác thực'
      txn.verification_method       as VerificationMethod,
  @EndUserText.label: 'Tài khoản nhân công xác thực'
      txn.verified_worker_user_uuid as VerifiedWorkerUserUUID,
  @EndUserText.label: 'Thời điểm xác thực nhân công'
      txn.worker_verified_at        as WorkerVerifiedAt,
      @Semantics.user.createdBy: true
  @EndUserText.label: 'Người tạo'
      txn.created_by                as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
  @EndUserText.label: 'Thời điểm tạo'
      txn.created_at                as CreatedAt
}
