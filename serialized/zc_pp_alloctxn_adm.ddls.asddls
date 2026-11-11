@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Sổ điều chỉnh sản lượng'
@Metadata.allowExtensions: true
define root view entity ZC_PP_AllocTxn_Adm
  as select from    ztb_pp_alloc_txn as txn
    inner join      ztb_pp_op_alloc  as op       on op.operation_uuid = txn.operation_uuid
  // Tài khoản mobile chỉ dùng để hiển thị mã nhân công; không lọc quyền xem.
    left outer join ztb_mob_user     as actor    on actor.user_uuid = txn.actor_user_uuid
    left outer join ztb_mob_user     as verifier on verifier.user_uuid = txn.verified_worker_user_uuid

  // Máy chạy ở vị trí đúng lúc ghi giao dịch (CREATED_AT, UTC) theo lịch sử
  // ZTB_PP_MACH_HIST: đoạn bắt đầu trước/đúng lúc đó và chưa kết thúc tại lúc
  // đó. Các đoạn của một vị trí không chồng nhau nên join ra tối đa một dòng.
    left outer join ztb_pp_mach_hist as machine_hist on  machine_hist.work_center = op.work_center
                                                     and machine_hist.position_id = txn.position_id
                                                     and machine_hist.valid_from <= txn.created_at
                                                     and ( machine_hist.valid_to  = 0
                                                        or machine_hist.valid_to  > txn.created_at )

  // Bộ phận công nhân theo Bảng khai báo nhân công theo xưởng: cùng Work Center,
  // Plant, mã công nhân và Posting Date trong khoảng Từ ngày - Đến ngày (Đến ngày
  // trống = còn hiệu lực). BO khai báo chặn chồng hiệu lực theo Work Center +
  // Plant + mã công nhân nên join ra tối đa một dòng; không khớp thì để trống.
    left outer join ztb_kb_nhancong  as worker_decl  on  worker_decl.work_center = op.work_center
                                                     and worker_decl.plant       = op.plant
                                                     and worker_decl.worker_id   = txn.worker_id
                                                     and worker_decl.from_date  <= txn.posting_date
                                                     and ( worker_decl.to_date   = abap.dats'00000000'
                                                        or worker_decl.to_date  >= txn.posting_date )
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
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_ProductionOrder_VH', element: 'ProductionOrder' } }]
      op.production_order           as ProductionOrder,
      @EndUserText.label: 'Công đoạn lệnh sản xuất'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_OrderOperation_VH', element: 'Operation' },
        additionalBinding: [{ localElement: 'ProductionOrder', element: 'ProductionOrder', usage: #FILTER }] }]
      op.operation_no               as Operation,
      @EndUserText.label: 'Mã công đoạn'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MD_CongDoan_Hist_VH', element: 'MaCongDoan' } }]
      op.ma_congdoan                as MaCongDoan,
      @EndUserText.label: 'Nhà máy'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Plant', element: 'Plant' } }]
      op.plant                      as Plant,
      @EndUserText.label: 'Trung tâm làm việc'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MOB_WorkCenter_VH', element: 'WorkCenter' },
        additionalBinding: [{ localElement: 'Plant', element: 'Plant', usage: #FILTER }] }]
      op.work_center                as WorkCenter,
      @EndUserText.label: 'Loại giao dịch'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_TxnType_VH', element: 'TransactionType' } }]
      txn.transaction_type          as TransactionType,
      @EndUserText.label: 'Loại giao dịch gốc'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_TxnType_VH', element: 'TransactionType' } }]
      txn.original_transaction_type as OriginalTransactionType,
      @EndUserText.label: 'Nhân công chuyển'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_Worker_Hist_VH', element: 'WorkerID' } }]
      txn.from_worker_id            as FromWorkerID,
      @EndUserText.label: 'Nhân công nhận'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_Worker_Hist_VH', element: 'WorkerID' } }]
      txn.to_worker_id              as ToWorkerID,
      @EndUserText.label: 'Mã nhân công'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_Worker_Hist_VH', element: 'WorkerID' } }]
      txn.worker_id                 as WorkerID,
      @EndUserText.label: 'Bộ phận công nhân'
      worker_decl.bo_phan           as WorkerBoPhan,
      @EndUserText.label: 'Vị trí làm việc'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MOB_Work_Hist_VH', element: 'WorkID' } }]
      txn.work_id                   as WorkID,
      @EndUserText.label: 'Vị trí hiện tại'
      txn.position_id               as PositionID,
      @EndUserText.label: 'Vị trí gốc'
      txn.origin_position_id        as OriginPositionID,
      @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
      @EndUserText.label: 'Số lượng'
      txn.quantity                  as Quantity,
      @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
      @EndUserText.label: 'Số lượng lỗi'
      txn.defect_quantity           as DefectQuantity,
      @EndUserText.label: 'Đơn vị tính'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_UnitOfMeasure', element: 'UnitOfMeasure' } }]
      txn.uom                       as UnitOfMeasure,
      @EndUserText.label: 'Ngày thực hiện'
      txn.execution_date            as ExecutionDate,
      @EndUserText.label: 'Mã ca'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_Shift', element: 'ShiftID' },
        additionalBinding: [{ localElement: 'WorkCenter', element: 'WorkCenter', usage: #FILTER }] }]
      txn.shift_id                  as ShiftID,
      @EndUserText.label: 'Ngày làm việc'
      txn.work_date                 as WorkDate,
      @EndUserText.label: 'Thời điểm thực hiện UTC'
      txn.executed_at               as ExecutedAt,
      @EndUserText.label: 'Bắt đầu ca UTC'
      txn.shift_start_at            as ShiftStartAt,
      @EndUserText.label: 'Kết thúc ca UTC'
      txn.shift_end_at              as ShiftEndAt,
      @EndUserText.label: 'Múi giờ ca'
      txn.shift_time_zone           as ShiftTimeZone,
      @EndUserText.label: 'Phiên bản ca hiệu lực từ'
      txn.shift_valid_from          as ShiftValidFrom,
      @EndUserText.label: 'Posting Date'
      txn.posting_date              as PostingDate,
      @EndUserText.label: 'Entry Date'
      txn.entry_date                as EntryDate,
      @EndUserText.label: 'Entry Time'
      txn.entry_time                as EntryTime,
      @EndUserText.label: 'Trạng thái giao dịch'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_TxnStatus_VH', element: 'TransactionStatus' } }]
      txn.transaction_status        as TransactionStatus,
      @EndUserText.label: 'Mã lý do'
      txn.reason_code               as ReasonCode,
      @EndUserText.label: 'Nội dung lý do'
      txn.reason_text               as ReasonText,
      @EndUserText.label: 'Nguồn giao dịch'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_SourceChannel_VH', element: 'SourceChannel' } }]
      txn.source_channel            as SourceChannel,
      @EndUserText.label: 'Người thực hiện'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_Worker_Hist_VH', element: 'WorkerID' } }]
      actor.worker_id               as ActorWorkerID,
      @EndUserText.label: 'Tài khoản người thực hiện'
      txn.actor_user_uuid           as ActorUserUUID,
      @EndUserText.label: 'Nhân công xác thực'
      verifier.worker_id            as VerifiedWorkerID,
      @EndUserText.label: 'Tài khoản nhân công xác thực'
      txn.verified_worker_user_uuid as VerifiedWorkerUserUUID,
      @EndUserText.label: 'Phiên thực hiện'
      txn.initiator_session_id      as InitiatorSessionID,
      @EndUserText.label: 'Mã thiết bị'
      txn.device_id                 as DeviceID,
      @EndUserText.label: 'Phương thức xác thực'
      txn.verification_method       as VerificationMethod,
      @EndUserText.label: 'Thời điểm xác thực nhân công'
      txn.worker_verified_at        as WorkerVerifiedAt,
      @Semantics.user.createdBy: true
      @EndUserText.label: 'Người tạo'
      txn.created_by                as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      @EndUserText.label: 'Thời điểm tạo'
      txn.created_at                as CreatedAt,
      @EndUserText.label: 'Mã máy đồng bộ'
      txn.machine_id                as MachineID,
      // Máy theo lịch sử vị trí; giao dịch trước khi có lịch sử (hoặc không có
      // vị trí) thì lấy máy đóng dấu lúc post trên chính dòng ledger.
      @EndUserText.label: 'Mã máy'
      coalesce( machine_hist.machine_id, txn.machine_id ) as PositionMachineID
}
