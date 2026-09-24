CLASS lhc_operationallocation DEFINITION
  INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.
    TYPES reported_response TYPE RESPONSE FOR REPORTED zr_pp_opalloc.
    TYPES failed_response TYPE RESPONSE FOR FAILED zr_pp_opalloc.
    TYPES: BEGIN OF operation_context,
             is_valid         TYPE abap_bool,
             error_code       TYPE c LENGTH 40,
             operation_uuid   TYPE ztb_pp_op_alloc-operation_uuid,
             production_order TYPE ztb_pp_op_alloc-production_order,
             operation_no     TYPE ztb_pp_op_alloc-operation_no,
             ma_congdoan      TYPE ztb_pp_op_alloc-ma_congdoan,
             plant            TYPE ztb_pp_op_alloc-plant,
             work_center      TYPE ztb_pp_op_alloc-work_center,
             operation_qty    TYPE ztb_pp_op_alloc-operation_qty,
             uom              TYPE ztb_pp_op_alloc-uom,
           END OF operation_context,
           operation_contexts TYPE SORTED TABLE OF operation_context
                              WITH UNIQUE KEY production_order operation_no.

    TYPES: BEGIN OF work_operation_context,
             is_valid          TYPE abap_bool,
             error_code        TYPE c LENGTH 40,
             work_name         TYPE ztb_mob_work-work_name,
             work_bo_phan      TYPE ztb_mob_work-bo_phan,
             location          TYPE ztb_mob_work-location,
             operation_name    TYPE ztb_md_congdoan-ten_congdoan,
             operation_bo_phan TYPE ztb_md_congdoan-bo_phan,
           END OF work_operation_context.

    TYPES: BEGIN OF worker_access_result,
             is_valid   TYPE abap_bool,
             error_code TYPE c LENGTH 40,
           END OF worker_access_result.

    TYPES: BEGIN OF worker_balance,
             employee_allocation_uuid TYPE ztb_pp_emp_alloc-emp_alloc_uuid,
             worker_id                TYPE ztb_pp_emp_alloc-worker_id,
             initial_assigned_qty     TYPE ztb_pp_emp_alloc-initial_assigned_qty,
             transferred_in_qty       TYPE ztb_pp_emp_alloc-transferred_in_qty,
             transferred_out_qty      TYPE ztb_pp_emp_alloc-transferred_out_qty,
             recalled_qty             TYPE ztb_pp_emp_alloc-recalled_qty,
             completed_qty            TYPE ztb_pp_emp_alloc-completed_qty,
             remaining_qty            TYPE ztb_pp_emp_alloc-remaining_qty,
             uom                      TYPE ztb_pp_emp_alloc-uom,
           END OF worker_balance,
           worker_balances TYPE STANDARD TABLE OF worker_balance WITH EMPTY KEY.

    TYPES: BEGIN OF lineage_transaction,
             transaction_uuid          TYPE ztb_pp_alloc_txn-transaction_uuid,
             original_transaction_uuid TYPE ztb_pp_alloc_txn-original_transaction_uuid,
             transaction_type          TYPE ztb_pp_alloc_txn-transaction_type,
             worker_id                 TYPE ztb_pp_alloc_txn-worker_id,
             from_worker_id            TYPE ztb_pp_alloc_txn-from_worker_id,
             to_worker_id              TYPE ztb_pp_alloc_txn-to_worker_id,
             work_id                   TYPE ztb_pp_alloc_txn-work_id,
             shift_id                  TYPE ztb_pp_alloc_txn-shift_id,
             work_date                 TYPE ztb_pp_alloc_txn-work_date,
             quantity                  TYPE ztb_pp_alloc_txn-quantity,
             uom                       TYPE ztb_pp_alloc_txn-uom,
             transaction_status        TYPE ztb_pp_alloc_txn-transaction_status,
           END OF lineage_transaction,
           lineage_transactions TYPE HASHED TABLE OF lineage_transaction
                                 WITH UNIQUE KEY transaction_uuid.

    TYPES: BEGIN OF lineage_result,
             is_valid                TYPE abap_bool,
             error_code              TYPE c LENGTH 40,
             source_transaction_type TYPE ztb_pp_alloc_txn-transaction_type,
             usable_quantity         TYPE ztb_pp_alloc_txn-quantity,
             root_transaction_uuid   TYPE ztb_pp_alloc_txn-transaction_uuid,
             work_id                 TYPE ztb_pp_alloc_txn-work_id,
             shift_id                TYPE ztb_pp_alloc_txn-shift_id,
             work_date               TYPE ztb_pp_alloc_txn-work_date,
           END OF lineage_result.

    TYPES: BEGIN OF balance_result,
             is_valid   TYPE abap_bool,
             error_code TYPE c LENGTH 40,
             balance    TYPE worker_balance,
           END OF balance_result.

    TYPES: BEGIN OF sync_receipt,
             transaction_uuid          TYPE ztb_pp_alloc_txn-transaction_uuid,
             operation_uuid            TYPE ztb_pp_alloc_txn-operation_uuid,
             actor_user_uuid           TYPE ztb_pp_alloc_txn-actor_user_uuid,
             original_transaction_uuid TYPE ztb_pp_alloc_txn-original_transaction_uuid,
             transaction_type          TYPE ztb_pp_alloc_txn-transaction_type,
             worker_id                 TYPE ztb_pp_alloc_txn-worker_id,
             work_id                   TYPE ztb_pp_alloc_txn-work_id,
             from_worker_id            TYPE ztb_pp_alloc_txn-from_worker_id,
             to_worker_id              TYPE ztb_pp_alloc_txn-to_worker_id,
             quantity                  TYPE ztb_pp_alloc_txn-quantity,
             uom                       TYPE ztb_pp_alloc_txn-uom,
             execution_date            TYPE ztb_pp_alloc_txn-execution_date,
             shift_id                  TYPE ztb_pp_alloc_txn-shift_id,
             executed_at               TYPE ztb_pp_alloc_txn-executed_at,
             production_order          TYPE ztb_pp_op_alloc-production_order,
             operation_no              TYPE ztb_pp_op_alloc-operation_no,
             ma_congdoan               TYPE ztb_pp_op_alloc-ma_congdoan,
           END OF sync_receipt,
           sync_receipts TYPE STANDARD TABLE OF sync_receipt WITH EMPTY KEY.

    CONSTANTS:
      func_initial_assign TYPE ztb_mob_func-func_id VALUE 'PP_INITIAL_ASSIGN',
      func_transfer       TYPE ztb_mob_func-func_id VALUE 'PP_TRANSFER',
      func_recall         TYPE ztb_mob_func-func_id VALUE 'PP_RECALL',
      func_confirm        TYPE ztb_mob_func-func_id VALUE 'PP_CONFIRM',
      func_reverse        TYPE ztb_mob_func-func_id VALUE 'PP_REVERSE'.

    DATA operation_cache TYPE operation_contexts.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR OperationAllocation
      RESULT result.

    METHODS validateOperation FOR VALIDATE ON SAVE
      IMPORTING keys FOR OperationAllocation~validateOperation.

    METHODS initialAssign FOR MODIFY
      IMPORTING keys   FOR ACTION OperationAllocation~initialAssign
      RESULT    result.
    METHODS transfer FOR MODIFY
      IMPORTING keys   FOR ACTION OperationAllocation~transfer
      RESULT    result.
    METHODS recall FOR MODIFY
      IMPORTING keys   FOR ACTION OperationAllocation~recall
      RESULT    result.
    METHODS confirm FOR MODIFY
      IMPORTING keys   FOR ACTION OperationAllocation~confirm
      RESULT    result.
    METHODS reverse FOR MODIFY
      IMPORTING keys   FOR ACTION OperationAllocation~reverse
      RESULT    result.
    METHODS submitInitialAssign FOR MODIFY
      IMPORTING keys   FOR ACTION OperationAllocation~submitInitialAssign
      RESULT    result.
    METHODS submitTransfer FOR MODIFY
      IMPORTING keys   FOR ACTION OperationAllocation~submitTransfer
      RESULT    result.
    METHODS submitRecall FOR MODIFY
      IMPORTING keys   FOR ACTION OperationAllocation~submitRecall
      RESULT    result.
    METHODS submitConfirm FOR MODIFY
      IMPORTING keys   FOR ACTION OperationAllocation~submitConfirm
      RESULT    result.
    METHODS submitReverse FOR MODIFY
      IMPORTING keys   FOR ACTION OperationAllocation~submitReverse
      RESULT    result.
    METHODS getSyncStatus FOR MODIFY
      IMPORTING keys   FOR ACTION OperationAllocation~getSyncStatus
      RESULT    result.
    METHODS getWorkHistory FOR MODIFY
      IMPORTING keys   FOR ACTION OperationAllocation~getWorkHistory
      RESULT    result.
    METHODS checkOperationAccess FOR MODIFY
      IMPORTING keys   FOR ACTION OperationAllocation~checkOperationAccess
      RESULT    result.


    METHODS alpha_out_no_gaps
      IMPORTING iv_value        TYPE csequence
      RETURNING VALUE(rv_value) TYPE string.

    METHODS ensure_operation
      IMPORTING
                production_order TYPE ztb_pp_op_alloc-production_order
                operation_no     TYPE ztb_pp_op_alloc-operation_no
                user_uuid        TYPE sysuuid_x16
                func_id          TYPE ztb_mob_func-func_id
                work_id          TYPE ztb_mob_work-work_id OPTIONAL
                effective_date   TYPE d OPTIONAL
      RETURNING VALUE(value)     TYPE operation_context.

    METHODS check_work_operation_context
      IMPORTING
                work_id        TYPE ztb_mob_work-work_id
                plant          TYPE ztb_mob_work-plant
                work_center    TYPE ztb_mob_work-workcenter
                ma_congdoan    TYPE ztb_md_congdoan-ma_congdoan
                effective_date TYPE d
      RETURNING VALUE(result)  TYPE work_operation_context.

    METHODS check_worker_access
      IMPORTING user_uuid      TYPE sysuuid_x16
                worker_id      TYPE ztb_pp_alloc_txn-worker_id
                plant          TYPE ztb_mob_work-plant
                work_center    TYPE ztb_mob_work-workcenter
                work_id        TYPE ztb_mob_work-work_id
                ma_congdoan    TYPE ztb_md_congdoan-ma_congdoan
                effective_date TYPE d
      RETURNING VALUE(result)  TYPE worker_access_result.

    METHODS read_worker_balances
      IMPORTING operation_uuid TYPE ztb_pp_op_alloc-operation_uuid
      RETURNING VALUE(result)  TYPE worker_balances.

    METHODS validate_worker_balance
      IMPORTING balances          TYPE worker_balances
                worker_identifier TYPE ztb_pp_alloc_txn-worker_id
                quantity          TYPE ztb_pp_alloc_txn-quantity
                uom               TYPE ztb_pp_alloc_txn-uom
      RETURNING VALUE(result)     TYPE balance_result.

    METHODS get_usable_txn_qty
      IMPORTING operation_uuid            TYPE ztb_pp_op_alloc-operation_uuid
                original_transaction_uuid TYPE ztb_pp_alloc_txn-transaction_uuid
                worker_id                 TYPE ztb_pp_alloc_txn-worker_id
                uom                       TYPE ztb_pp_alloc_txn-uom
      RETURNING VALUE(result)             TYPE lineage_result.


    METHODS find_allocation_root
      IMPORTING operation_uuid TYPE ztb_pp_op_alloc-operation_uuid
                worker_id      TYPE ztb_pp_alloc_txn-worker_id
                work_id        TYPE ztb_pp_alloc_txn-work_id
                shift_id       TYPE ztb_pp_alloc_txn-shift_id
                work_date      TYPE ztb_pp_alloc_txn-work_date
                uom            TYPE ztb_pp_alloc_txn-uom
      RETURNING VALUE(result)  TYPE ztb_pp_alloc_txn-transaction_uuid.

    METHODS find_persisted_sync_receipts
      IMPORTING sync_item_uuid TYPE ztb_pp_alloc_txn-sync_item_uuid
      RETURNING VALUE(result)  TYPE sync_receipts.

    METHODS read_operation_sync_receipts
      IMPORTING operation_uuid TYPE ztb_pp_op_alloc-operation_uuid
                sync_item_uuid TYPE ztb_pp_alloc_txn-sync_item_uuid
      RETURNING VALUE(result)  TYPE sync_receipts.

    METHODS report_instance_failure
      IMPORTING operation_uuid TYPE ztb_pp_op_alloc-operation_uuid
                text TYPE string
      CHANGING failed TYPE failed_response reported TYPE reported_response.

    METHODS forward_action_failure
      IMPORTING cid TYPE string
                operation_uuid TYPE ztb_pp_op_alloc-operation_uuid
                action_reported TYPE reported_response
      CHANGING failed TYPE failed_response reported TYPE reported_response.

    METHODS report_failure
      IMPORTING cid TYPE string text TYPE string
      CHANGING failed TYPE failed_response reported TYPE reported_response.
ENDCLASS.

CLASS lhc_employeeallocation DEFINITION
  INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    TYPES: BEGIN OF adjustment_calculation,
             is_valid                TYPE abap_bool,
             error_code              TYPE c LENGTH 40,
             delta_quantity          TYPE ztb_pp_emp_alloc-remaining_qty,
             new_initial_quantity    TYPE ztb_pp_emp_alloc-initial_assigned_qty,
             new_recalled_quantity   TYPE ztb_pp_emp_alloc-recalled_qty,
             new_completed_quantity  TYPE ztb_pp_emp_alloc-completed_qty,
             new_remaining_quantity  TYPE ztb_pp_emp_alloc-remaining_qty,
             ledger_transaction_type TYPE ztb_pp_alloc_txn-transaction_type,
           END OF adjustment_calculation.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR EmployeeAllocation
      RESULT result.

    METHODS calculate_adjustment
      IMPORTING adjustment_type    TYPE string
                target_quantity    TYPE ztb_pp_emp_alloc-remaining_qty
                initial_quantity   TYPE ztb_pp_emp_alloc-initial_assigned_qty
                recalled_quantity  TYPE ztb_pp_emp_alloc-recalled_qty
                completed_quantity TYPE ztb_pp_emp_alloc-completed_qty
                remaining_quantity TYPE ztb_pp_emp_alloc-remaining_qty
      RETURNING VALUE(result)      TYPE adjustment_calculation.

    METHODS assignment_exceeds_operation
      IMPORTING operation_uuid     TYPE ztb_pp_emp_alloc-operation_uuid
                operation_quantity TYPE ztb_pp_op_alloc-operation_qty
                delta_quantity     TYPE ztb_pp_emp_alloc-remaining_qty
      RETURNING VALUE(result)      TYPE abap_bool.

    METHODS adjustAllocation FOR MODIFY
      IMPORTING keys   FOR ACTION EmployeeAllocation~adjustAllocation
      RESULT    result.

    METHODS validateBalance FOR VALIDATE ON SAVE
      IMPORTING keys FOR EmployeeAllocation~validateBalance.
ENDCLASS.

CLASS lhc_employeeallocation IMPLEMENTATION.

  " Kiểm tra quyền global cho action điều chỉnh phân bổ ở entity con.
  " Các quyền update/delete của entity con vẫn kế thừa authorization master
  " của OperationAllocation thông qua authorization dependent by _Operation.
  METHOD get_global_authorizations.
    IF requested_authorizations-%action-adjustAllocation = if_abap_behv=>mk-on.
      result-%action-adjustAllocation = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  " Tính số chênh lệch từ số hiện tại đến số mới và chọn loại ledger tương ứng.
  METHOD calculate_adjustment.
    result-new_initial_quantity = initial_quantity.
    result-new_recalled_quantity = recalled_quantity.
    result-new_completed_quantity = completed_quantity.
    result-new_remaining_quantity = remaining_quantity.
    result-is_valid = abap_true.

    CASE adjustment_type.
      WHEN 'ASSIGN'.
        result-delta_quantity = target_quantity - initial_quantity.
        result-new_initial_quantity = target_quantity.
        result-new_remaining_quantity = remaining_quantity + result-delta_quantity.
        result-ledger_transaction_type = zcl_pp_txn_type=>allocation_adjustment.

      WHEN 'RECALL'.
        result-delta_quantity = target_quantity - recalled_quantity.
        result-new_recalled_quantity = target_quantity.
        result-new_remaining_quantity = remaining_quantity - result-delta_quantity.
        result-ledger_transaction_type = zcl_pp_txn_type=>recall_adjustment.

      WHEN 'CONFIRM'.
        result-delta_quantity = target_quantity - completed_quantity.
        result-new_completed_quantity = target_quantity.
        result-new_remaining_quantity = remaining_quantity - result-delta_quantity.
        result-ledger_transaction_type = zcl_pp_txn_type=>confirm_adjustment.

      WHEN OTHERS.
        result-is_valid = abap_false.
        result-error_code = 'INVALID_ADJUSTMENT_TYPE'.
    ENDCASE.
  ENDMETHOD.

  " Kiểm tra phần giao mới có vượt sản lượng của công đoạn hay không.
  METHOD assignment_exceeds_operation.
    READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
      ENTITY OperationAllocation BY \_Employees
      FIELDS ( CompletedQuantity RemainingQuantity )
      WITH VALUE #( ( %key-OperationUUID = operation_uuid ) )
      RESULT DATA(operation_allocations).
    DATA(total_allocated) = REDUCE ztb_pp_emp_alloc-remaining_qty(
      INIT total = CONV ztb_pp_emp_alloc-remaining_qty( 0 )
      FOR current IN operation_allocations
      NEXT total = total + current-RemainingQuantity + current-CompletedQuantity ).
    result = xsdbool( total_allocated + delta_quantity > operation_quantity ).
  ENDMETHOD.

  " Điều chỉnh giao/thu hồi/xác nhận của một công nhân theo số lượng mới.
  " DVT luôn lấy từ snapshot hiện tại; ledger ghi delta để có thể audit.
  METHOD adjustAllocation.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      DATA(input) = <key>-%param.

      READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY EmployeeAllocation ALL FIELDS
        WITH VALUE #( ( %tky = <key>-%tky ) )
        RESULT DATA(allocations).
      IF lines( allocations ) <> 1.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-employeeallocation.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Không tìm thấy phân bổ nhân công' ) )
          TO reported-employeeallocation.
        CONTINUE.
      ENDIF.

      DATA(allocation) = allocations[ 1 ].
      DATA(execution_date) = COND d(
        WHEN input-ExecutionDate IS INITIAL
        THEN cl_abap_context_info=>get_system_date( )
        ELSE input-ExecutionDate ).
      IF input-AdjustmentType IS INITIAL
         OR input-TargetQuantity < 0
         OR input-ReasonCode IS INITIAL
         OR input-ReasonText IS INITIAL.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-employeeallocation.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Thiếu loại điều chỉnh, số lượng mới hoặc lý do' ) )
          TO reported-employeeallocation.
        CONTINUE.
      ENDIF.

      READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY OperationAllocation ALL FIELDS
        WITH VALUE #( ( OperationUUID = allocation-OperationUUID ) )
        RESULT DATA(operations).
      IF lines( operations ) <> 1.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-employeeallocation.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Không tìm thấy công đoạn của phân bổ' ) )
          TO reported-employeeallocation.
        CONTINUE.
      ENDIF.

      DATA(operation) = operations[ 1 ].
      IF allocation-UnitOfMeasure <> operation-UnitOfMeasure.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-employeeallocation.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Đơn vị tính của phân bổ không khớp công đoạn' ) )
          TO reported-employeeallocation.
        CONTINUE.
      ENDIF.

      IF input-ShiftID IS NOT INITIAL.
        SELECT FROM ztb_pp_shift
          FIELDS shift_id, valid_from, time_zone
          WHERE plant = @operation-Plant
            AND shift_id = @input-ShiftID
            AND is_active = 'A'
            AND valid_from <= @execution_date
            AND valid_to >= @execution_date
          INTO TABLE @DATA(shifts)
          UP TO 2 ROWS.
        IF lines( shifts ) <> 1.
          APPEND VALUE #( %tky = <key>-%tky ) TO failed-employeeallocation.
          APPEND VALUE #(
            %tky = <key>-%tky
            %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-error
              text = 'Ca làm việc không hợp lệ tại nhà máy và ngày đã chọn' ) )
            TO reported-employeeallocation.
          CONTINUE.
        ENDIF.
      ENDIF.

      DATA(calculation) = calculate_adjustment(
        adjustment_type = CONV string( input-AdjustmentType )
        target_quantity = input-TargetQuantity
        initial_quantity = allocation-InitialAssignedQuantity
        recalled_quantity = allocation-RecalledQuantity
        completed_quantity = allocation-CompletedQuantity
        remaining_quantity = allocation-RemainingQuantity ).
      IF calculation-is_valid = abap_false.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-employeeallocation.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Loại điều chỉnh chỉ nhận ASSIGN, RECALL hoặc CONFIRM' ) )
          TO reported-employeeallocation.
        CONTINUE.
      ENDIF.

      IF input-AdjustmentType = 'ASSIGN'.
        IF calculation-delta_quantity > 0
           AND assignment_exceeds_operation(
             operation_uuid = allocation-OperationUUID
             operation_quantity = operation-OperationQuantity
             delta_quantity = calculation-delta_quantity ) = abap_true.
          APPEND VALUE #( %tky = <key>-%tky ) TO failed-employeeallocation.
          APPEND VALUE #(
            %tky = <key>-%tky
            %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-error
              text = 'Tổng sản lượng giao vượt sản lượng công đoạn' ) )
            TO reported-employeeallocation.
          CONTINUE.
        ENDIF.
      ENDIF.

      IF calculation-new_initial_quantity < 0
         OR calculation-new_recalled_quantity < 0
         OR calculation-new_completed_quantity < 0
         OR calculation-new_remaining_quantity < 0.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-employeeallocation.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Số lượng mới không thể nhỏ hơn số lượng đã phát sinh' ) )
          TO reported-employeeallocation.
        CONTINUE.
      ENDIF.

      DATA(executed_at) = utclong_current( ).
      "Điều chỉnh từ admin không nhận WorkID từ mobile. Lấy vị trí gần nhất
      "đã được ghi trên ledger của đúng công nhân để giữ nguyên ngữ cảnh audit.
      SELECT FROM ztb_pp_alloc_txn
        FIELDS work_id
        WHERE operation_uuid = @allocation-OperationUUID
          AND transaction_status = @zcl_pp_txn_type=>posted
          AND work_id <> ' '
          AND ( worker_id = @allocation-WorkerID
             OR from_worker_id = @allocation-WorkerID
             OR to_worker_id = @allocation-WorkerID )
        ORDER BY executed_at DESCENDING, created_at DESCENDING
        INTO TABLE @DATA(work_contexts)
        UP TO 1 ROWS.
      DATA(work_id) = VALUE ztb_mob_work-work_id(
        work_contexts[ 1 ]-work_id OPTIONAL ).
      DATA(shift_valid_from) = VALUE ztb_pp_shift-valid_from(
        shifts[ 1 ]-valid_from OPTIONAL ).
      DATA(shift_time_zone) = VALUE ztb_pp_shift-time_zone(
        shifts[ 1 ]-time_zone OPTIONAL ).



      MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY EmployeeAllocation UPDATE FIELDS
          ( InitialAssignedQuantity RecalledQuantity CompletedQuantity
            RemainingQuantity LastExecutionDate LastSyncAt )
        WITH VALUE #( ( EmployeeAllocationUUID = allocation-EmployeeAllocationUUID
          InitialAssignedQuantity = calculation-new_initial_quantity
          RecalledQuantity = calculation-new_recalled_quantity
          CompletedQuantity = calculation-new_completed_quantity
          RemainingQuantity = calculation-new_remaining_quantity
          LastExecutionDate = execution_date
          LastSyncAt = executed_at ) )
        ENTITY OperationAllocation CREATE BY \_Transactions FIELDS
          ( TransactionType WorkerID WorkID Quantity UnitOfMeasure ExecutionDate
            ShiftID WorkDate ExecutedAt ShiftTimeZone ShiftValidFrom
            TransactionStatus ReasonCode ReasonText SourceChannel VerificationMethod )
        WITH VALUE #( ( %tky = operation-%tky %target = VALUE #(
          ( %cid = |ADJ{ sy-tabix }|
            TransactionType = calculation-ledger_transaction_type
            WorkerID = allocation-WorkerID WorkID = work_id
            Quantity = calculation-delta_quantity
            UnitOfMeasure = allocation-UnitOfMeasure
            ExecutionDate = execution_date
            ShiftID = input-ShiftID
            WorkDate = execution_date
            ExecutedAt = executed_at
            ShiftTimeZone = shift_time_zone
            ShiftValidFrom = shift_valid_from
            TransactionStatus = zcl_pp_txn_type=>posted
            ReasonCode = input-ReasonCode
            ReasonText = input-ReasonText
            SourceChannel = zcl_pp_txn_type=>source_fiori
            VerificationMethod = 'IAM' ) ) ) )
        FAILED DATA(modify_failed).
      IF modify_failed-employeeallocation IS NOT INITIAL
         OR modify_failed-operationallocation IS NOT INITIAL
         OR modify_failed-allocationtransaction IS NOT INITIAL.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-employeeallocation.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Không thể lưu điều chỉnh sản lượng và ledger' ) )
          TO reported-employeeallocation.
        CONTINUE.
      ENDIF.

      allocation-InitialAssignedQuantity = calculation-new_initial_quantity.
      allocation-RecalledQuantity = calculation-new_recalled_quantity.
      allocation-CompletedQuantity = calculation-new_completed_quantity.
      allocation-RemainingQuantity = calculation-new_remaining_quantity.
      allocation-LastExecutionDate = execution_date.
      APPEND VALUE #( %tky = <key>-%tky %param = allocation ) TO result.
    ENDLOOP.
  ENDMETHOD.

  " Kiểm tra số dư còn lại của từng phân công theo công thức cộng/trừ sản lượng.
  METHOD validateBalance.
    READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
      ENTITY EmployeeAllocation
      FIELDS ( InitialAssignedQuantity TransferredInQuantity
               TransferredOutQuantity RecalledQuantity CompletedQuantity
               RemainingQuantity )
      WITH CORRESPONDING #( keys )
      RESULT DATA(allocations).

    LOOP AT allocations ASSIGNING FIELD-SYMBOL(<allocation>).
      DATA expected_remaining TYPE ztb_pp_emp_alloc-remaining_qty.
      expected_remaining =
        <allocation>-InitialAssignedQuantity
        + <allocation>-TransferredInQuantity
        - <allocation>-TransferredOutQuantity
        - <allocation>-RecalledQuantity
        - <allocation>-CompletedQuantity.
      IF expected_remaining < 0
         OR <allocation>-RemainingQuantity <> expected_remaining.
        APPEND VALUE #( %tky = <allocation>-%tky ) TO failed-employeeallocation.
        APPEND VALUE #(
          %tky = <allocation>-%tky
          %element-RemainingQuantity = if_abap_behv=>mk-on
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Số lượng còn lại không khớp với sổ phân bổ' ) )
          TO reported-employeeallocation.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS lhc_operationallocation IMPLEMENTATION.

  " Cấp quyền RAP ở mức global; quyền nghiệp vụ cụ thể được kiểm tra trong từng action.
  METHOD get_global_authorizations.
    "API mobile không expose raw CRUD. Các domain action tự xác thực CASLA token
    "khi request xuất phát từ mobile; projection mobile chỉ expose các static
    "facade action có kiểm soát.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-unauthorized.
    ENDIF.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-unauthorized.
    ENDIF.
    IF requested_authorizations-%action-initialAssign = if_abap_behv=>mk-on.
      result-%action-initialAssign = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-transfer = if_abap_behv=>mk-on.
      result-%action-transfer = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-recall = if_abap_behv=>mk-on.
      result-%action-recall = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-confirm = if_abap_behv=>mk-on.
      result-%action-confirm = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-reverse = if_abap_behv=>mk-on.
      result-%action-reverse = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-submitInitialAssign = if_abap_behv=>mk-on.
      result-%action-submitInitialAssign = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-submitTransfer = if_abap_behv=>mk-on.
      result-%action-submitTransfer = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-submitRecall = if_abap_behv=>mk-on.
      result-%action-submitRecall = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-submitConfirm = if_abap_behv=>mk-on.
      result-%action-submitConfirm = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-submitReverse = if_abap_behv=>mk-on.
      result-%action-submitReverse = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-getSyncStatus = if_abap_behv=>mk-on.
      result-%action-getSyncStatus = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-getWorkHistory = if_abap_behv=>mk-on.
      result-%action-getWorkHistory = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  " Kiểm tra dữ liệu snapshot công đoạn trước khi ghi vào cơ sở dữ liệu.
  METHOD validateOperation.
    READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
      ENTITY OperationAllocation
      FIELDS ( ProductionOrder Operation MaCongDoan OperationQuantity
               UnitOfMeasure Plant WorkCenter )
      WITH CORRESPONDING #( keys )
      RESULT DATA(operations).

    LOOP AT operations ASSIGNING FIELD-SYMBOL(<operation>).
      IF <operation>-ProductionOrder IS INITIAL
         OR <operation>-Operation IS INITIAL
         OR <operation>-MaCongDoan IS INITIAL
         OR <operation>-OperationQuantity <= 0
         OR <operation>-UnitOfMeasure IS INITIAL
         OR <operation>-Plant IS INITIAL
         OR <operation>-WorkCenter IS INITIAL.
        APPEND VALUE #( %tky = <operation>-%tky ) TO failed-operationallocation.
        APPEND VALUE #(
          %tky = <operation>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Dữ liệu snapshot công đoạn không đầy đủ' ) )
          TO reported-operationallocation.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  " Lần giao gốc của nhóm: cùng công nhân, công đoạn, bộ phận, ca, ngày làm việc
  " và đơn vị. Lần giao sau của nhóm được ghi như phần bổ sung của gốc này.
  METHOD find_allocation_root.
    IF shift_id IS INITIAL OR work_date IS INITIAL.
      RETURN.
    ENDIF.
    SELECT FROM ztb_pp_alloc_txn
      FIELDS transaction_uuid
      WHERE operation_uuid = @operation_uuid
        AND transaction_type = @zcl_pp_txn_type=>initial_assign
        AND transaction_status = @zcl_pp_txn_type=>posted
        AND worker_id = @worker_id
        AND work_id = @work_id
        AND shift_id = @shift_id
        AND work_date = @work_date
        AND uom = @uom
        AND original_transaction_uuid IS INITIAL
      ORDER BY executed_at ASCENDING, transaction_uuid ASCENDING
      INTO @result
      UP TO 1 ROWS.
    ENDSELECT.
  ENDMETHOD.

  " Đọc công đoạn sống từ SAP, kiểm tra phạm vi quyền rồi lấy hoặc tạo snapshot công đoạn.
  METHOD ensure_operation.
    DATA(live) = zcl_pp_operation_guard=>resolve(
      production_order = production_order
      operation_no = operation_no ).
    IF live-is_valid = abap_false.
      value-error_code = live-error_code.
      RETURN.
    ENDIF.
    DATA(context_date) = COND d(
      WHEN effective_date IS INITIAL THEN cl_abap_context_info=>get_system_date( )
      ELSE effective_date ).
    IF zcl_mob_token_validator=>has_func_op_scope(
         user_uuid = user_uuid
         func_id = func_id
         plant = live-plant
         work_center = live-work_center
         work_id = work_id
         ma_congdoan = live-ma_congdoan
         effective_date = context_date ) = abap_false.
      value-error_code = 'MANAGER_OPERATION_NOT_ALLOWED'.
      RETURN.
    ENDIF.
    DATA(work_operation_context) = check_work_operation_context(
      work_id = work_id
      plant = live-plant
      work_center = live-work_center
      ma_congdoan = live-ma_congdoan
      effective_date = context_date ).
    IF work_operation_context-is_valid = abap_false.
      value-error_code = work_operation_context-error_code.
      RETURN.
    ENDIF.
    DATA(cached_context) = VALUE operation_context(
      operation_cache[ production_order = production_order
                       operation_no = operation_no ] OPTIONAL ).
    IF cached_context IS NOT INITIAL.
      value = cached_context.
      RETURN.
    ENDIF.

    SELECT FROM ztb_pp_op_alloc
      FIELDS operation_uuid, production_order, operation_no, ma_congdoan,
             plant, work_center, operation_qty, uom
      WHERE production_order = @production_order
        AND operation_no = @operation_no
      INTO TABLE @DATA(existing)
      UP TO 2 ROWS.

    IF lines( existing ) > 1.
      value-error_code = 'OPERATION_SNAPSHOT_DUPLICATE'.
      RETURN.
    ENDIF.

    IF existing IS INITIAL.
      MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY OperationAllocation CREATE FIELDS
          ( ProductionOrder Operation MaCongDoan Plant WorkCenter
            OperationQuantity UnitOfMeasure OperationStatus )
        WITH VALUE #( ( %cid = 'OP'
          ProductionOrder = live-production_order
          Operation = live-operation_no
          MaCongDoan = live-ma_congdoan
          Plant = live-plant
          WorkCenter = live-work_center
          OperationQuantity = live-operation_qty
          UnitOfMeasure = live-uom
          OperationStatus = 'REL' ) )
        MAPPED DATA(mapped)
        FAILED DATA(create_failed).
      IF create_failed-operationallocation IS NOT INITIAL
         OR mapped-operationallocation IS INITIAL.
        value-error_code = 'OPERATION_SNAPSHOT_CREATE_FAILED'.
        RETURN.
      ENDIF.
      value-operation_uuid = mapped-operationallocation[ 1 ]-OperationUUID.
    ELSE.
      DATA(snapshot) = existing[ 1 ].
      value-operation_uuid = snapshot-operation_uuid.
      IF snapshot-ma_congdoan <> live-ma_congdoan
         OR snapshot-plant <> live-plant
         OR snapshot-work_center <> live-work_center
         OR snapshot-operation_qty <> live-operation_qty
         OR snapshot-uom <> live-uom.
        MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE
          ENTITY OperationAllocation UPDATE FIELDS
            ( MaCongDoan Plant WorkCenter OperationQuantity UnitOfMeasure
              OperationStatus )
          WITH VALUE #( ( OperationUUID = snapshot-operation_uuid
            MaCongDoan = live-ma_congdoan
            Plant = live-plant
            WorkCenter = live-work_center
            OperationQuantity = live-operation_qty
            UnitOfMeasure = live-uom
            OperationStatus = 'REL' ) )
          FAILED DATA(update_failed).
        IF update_failed-operationallocation IS NOT INITIAL.
          value-error_code = 'OPERATION_SNAPSHOT_UPDATE_FAILED'.
          RETURN.
        ENDIF.
      ENDIF.
    ENDIF.

    value-is_valid = abap_true.
    value-production_order = live-production_order.
    value-operation_no = live-operation_no.
    value-ma_congdoan = live-ma_congdoan.
    value-plant = live-plant.
    value-work_center = live-work_center.
    value-operation_qty = live-operation_qty.
    value-uom = live-uom.
    INSERT value INTO TABLE operation_cache.
  ENDMETHOD.

  " Đối chiếu vị trí làm việc với công đoạn theo Plant, Work Center và bộ phận.
  " Master công đoạn phải có đúng một phiên bản hiệu lực tại ngày làm việc.
  METHOD check_work_operation_context.
    SELECT FROM ztb_mob_work
      FIELDS work_id, work_name, plant, workcenter, bo_phan, location
      WHERE work_id = @work_id
        AND is_active = 'A'
      INTO TABLE @DATA(work_contexts)
      UP TO 2 ROWS.
    IF work_contexts IS INITIAL.
      result-error_code = 'WORK_NOT_FOUND'.
      RETURN.
    ENDIF.

    DATA(work_context) = work_contexts[ 1 ].
    IF work_context-plant <> plant
       OR work_context-workcenter <> work_center.
      result-error_code = 'WORK_OPERATION_MISMATCH'.
      RETURN.
    ENDIF.

    SELECT FROM ztb_md_congdoan
      FIELDS ma_congdoan, ten_congdoan, bo_phan
      WHERE ma_congdoan = @ma_congdoan
        AND bo_phan = @work_context-bo_phan
        AND valid_from <= @effective_date
        AND valid_to >= @effective_date
      INTO TABLE @DATA(operation_masters)
      UP TO 2 ROWS.
    IF operation_masters IS INITIAL.
      result-error_code = 'OPERATION_MASTER_NOT_FOUND'.
      RETURN.
    ENDIF.
    IF lines( operation_masters ) > 1.
      result-error_code = 'OPERATION_MASTER_AMBIGUOUS'.
      RETURN.
    ENDIF.

    DATA(operation_master) = operation_masters[ 1 ].
    IF work_context-bo_phan IS INITIAL
       OR operation_master-bo_phan IS INITIAL
       OR work_context-bo_phan <> operation_master-bo_phan.
      result-error_code = 'OPERATION_DEPARTMENT_MISMATCH'.
      RETURN.
    ENDIF.

    result = VALUE #(
      is_valid = abap_true
      work_name = work_context-work_name
      work_bo_phan = work_context-bo_phan
      location = work_context-location
      operation_name = operation_master-ten_congdoan
      operation_bo_phan = operation_master-bo_phan ).
  ENDMETHOD.

  " Kiểm tra công nhân theo đúng thứ tự để mobile phân biệt được nguyên nhân lỗi:
  " tài khoản/role không có quyền tại công đoạn hay phân công nhân công hết hiệu lực.
  METHOD check_worker_access.
    IF zcl_mob_token_validator=>has_worker_op_scope(
         user_uuid = user_uuid
         worker_id = worker_id
         plant = plant
         work_center = work_center
         work_id = work_id
         ma_congdoan = ma_congdoan
         effective_date = effective_date ) = abap_false.
      result-error_code = 'WORKER_OPERATION_NOT_ALLOWED'.
      RETURN.
    ENDIF.

    IF zcl_pp_worker_validator=>is_worker_active(
         worker_id = worker_id
         plant = plant
         work_center = work_center
         execution_date = effective_date ) = abap_false.
      result-error_code = 'WORKER_ASSIGNMENT_EXPIRED'.
      RETURN.
    ENDIF.

    result-is_valid = abap_true.
  ENDMETHOD.

  " Đọc số dư phân công từ transactional buffer để các action cùng request thấy dữ liệu mới nhất.
  METHOD read_worker_balances.
    "EML reads the RAP transactional buffer, including balances changed earlier
    "in the same request. Open SQL would only see the persisted database state.
    READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
      ENTITY OperationAllocation BY \_Employees
        FIELDS ( EmployeeAllocationUUID WorkerID InitialAssignedQuantity
                 TransferredInQuantity TransferredOutQuantity RecalledQuantity
                 CompletedQuantity RemainingQuantity UnitOfMeasure )
        WITH VALUE #( ( %key-OperationUUID = operation_uuid ) )
        RESULT DATA(allocations).
    LOOP AT allocations INTO DATA(allocation).
      APPEND VALUE #(
        employee_allocation_uuid = allocation-EmployeeAllocationUUID
        worker_id = allocation-WorkerID
        initial_assigned_qty = allocation-InitialAssignedQuantity
        transferred_in_qty = allocation-TransferredInQuantity
        transferred_out_qty = allocation-TransferredOutQuantity
        recalled_qty = allocation-RecalledQuantity
        completed_qty = allocation-CompletedQuantity
        remaining_qty = allocation-RemainingQuantity
        uom = allocation-UnitOfMeasure ) TO result.
    ENDLOOP.
  ENDMETHOD.

  " Kiểm tra worker có đúng một balance và còn đủ số lượng tổng hay không.
  METHOD validate_worker_balance.
    DATA(worker_balances) = balances.
    DELETE worker_balances WHERE worker_id <> worker_identifier.
    IF lines( worker_balances ) <> 1.
      result-error_code = COND string(
        WHEN lines( worker_balances ) > 1
        THEN 'WORKER_BALANCE_DUPLICATE'
        ELSE 'CONFIRM_QUANTITY_EXCEEDED' ).
      RETURN.
    ENDIF.

    result-balance = worker_balances[ 1 ].
    IF result-balance-uom <> uom
       OR result-balance-remaining_qty < quantity.
      result-error_code = 'CONFIRM_QUANTITY_EXCEEDED'.
      RETURN.
    ENDIF.
    result-is_valid = abap_true.
  ENDMETHOD.

  " Tính số lượng còn dùng được của đúng transaction gốc, không dùng balance tổng
  " của worker để thay thế kiểm tra lineage.
  METHOD get_usable_txn_qty.
    READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
      ENTITY OperationAllocation BY \_Transactions
        FIELDS ( TransactionUUID OriginalTransactionUUID TransactionType
                 WorkerID FromWorkerID ToWorkerID WorkID ShiftID WorkDate
                 Quantity UnitOfMeasure TransactionStatus )
        WITH VALUE #( ( %key-OperationUUID = operation_uuid ) )
        RESULT DATA(transactions).

    DATA(lineage_rows) = VALUE lineage_transactions( ).
    LOOP AT transactions INTO DATA(transaction)
      WHERE TransactionStatus = zcl_pp_txn_type=>posted.
      INSERT VALUE #( transaction_uuid = transaction-TransactionUUID
        original_transaction_uuid = transaction-OriginalTransactionUUID
        transaction_type = transaction-TransactionType
        worker_id = transaction-WorkerID
        from_worker_id = transaction-FromWorkerID
        to_worker_id = transaction-ToWorkerID
        work_id = transaction-WorkID
        shift_id = transaction-ShiftID
        work_date = transaction-WorkDate
        quantity = transaction-Quantity
        uom = transaction-UnitOfMeasure
        transaction_status = transaction-TransactionStatus ) INTO TABLE lineage_rows.
    ENDLOOP.

    DATA(root) = VALUE lineage_transaction(
      lineage_rows[ transaction_uuid = original_transaction_uuid ] OPTIONAL ).
    "Lần giao bổ sung dùng chung số dư với gốc của nhóm: quy về gốc trước.
    DATA parent TYPE lineage_transaction.
    DO 5 TIMES.
      IF root IS INITIAL
         OR root-transaction_type <> zcl_pp_txn_type=>initial_assign
         OR root-original_transaction_uuid IS INITIAL.
        EXIT.
      ENDIF.
      parent = VALUE #(
        lineage_rows[ transaction_uuid = root-original_transaction_uuid ] OPTIONAL ).
      IF parent IS INITIAL
         OR parent-transaction_type <> zcl_pp_txn_type=>initial_assign.
        EXIT.
      ENDIF.
      root = parent.
    ENDDO.

    IF root IS INITIAL
       OR root-transaction_status <> zcl_pp_txn_type=>posted
       OR root-uom <> uom
       OR root-quantity <= 0.
      result-error_code = 'ORIGINAL_TRANSACTION_INVALID'.
      RETURN.
    ENDIF.

    IF ( root-transaction_type = zcl_pp_txn_type=>transfer
         AND root-to_worker_id <> worker_id )
       OR ( root-transaction_type <> zcl_pp_txn_type=>transfer
            AND root-worker_id <> worker_id
            AND root-to_worker_id <> worker_id ).
      result-error_code = 'ORIGINAL_TRANSACTION_WORKER_MISMATCH'.
      RETURN.
    ENDIF.

    IF root-transaction_type <> zcl_pp_txn_type=>initial_assign
       AND root-transaction_type <> zcl_pp_txn_type=>transfer
       AND root-transaction_type <> zcl_pp_txn_type=>allocation_adjustment.
      result-error_code = 'ORIGINAL_TRANSACTION_TYPE_INVALID'.
      RETURN.
    ENDIF.
    result-source_transaction_type = root-transaction_type.

    DATA lineage_ids TYPE SORTED TABLE OF ztb_pp_alloc_txn-transaction_uuid
                     WITH UNIQUE KEY table_line.
    INSERT root-transaction_uuid INTO TABLE lineage_ids.

    DATA(lineage_changed) = abap_true.
    WHILE lineage_changed = abap_true.
      lineage_changed = abap_false.
      LOOP AT lineage_rows ASSIGNING FIELD-SYMBOL(<lineage_row>).
        IF <lineage_row>-original_transaction_uuid IS INITIAL
           OR NOT line_exists( lineage_ids[
                table_line = <lineage_row>-original_transaction_uuid ] )
           OR line_exists( lineage_ids[
                table_line = <lineage_row>-transaction_uuid ] ).
          CONTINUE.
        ENDIF.
        INSERT <lineage_row>-transaction_uuid INTO TABLE lineage_ids.
        lineage_changed = abap_true.
      ENDLOOP.
    ENDWHILE.

    result-usable_quantity = root-quantity.
    LOOP AT lineage_rows ASSIGNING <lineage_row>.
      IF <lineage_row>-transaction_uuid = root-transaction_uuid
         OR NOT line_exists( lineage_ids[
              table_line = <lineage_row>-transaction_uuid ] ).
        CONTINUE.
      ENDIF.
      CASE <lineage_row>-transaction_type.
        WHEN zcl_pp_txn_type=>initial_assign.
          "Lần giao bổ sung của nhóm: cộng vào số dùng được.
          result-usable_quantity = result-usable_quantity
                                + <lineage_row>-quantity.
        WHEN zcl_pp_txn_type=>confirm OR zcl_pp_txn_type=>recall.
          result-usable_quantity = result-usable_quantity
                                - <lineage_row>-quantity.
        WHEN zcl_pp_txn_type=>correction.
          "Correction là delta của confirmation: delta âm trả lại capacity.
          result-usable_quantity = result-usable_quantity
                                - <lineage_row>-quantity.
        WHEN zcl_pp_txn_type=>reverse.
          result-usable_quantity = result-usable_quantity
                                + <lineage_row>-quantity.
      ENDCASE.
    ENDLOOP.

    IF result-usable_quantity < 0.
      result-usable_quantity = 0.
    ENDIF.
    result-root_transaction_uuid = root-transaction_uuid.
    result-work_id = root-work_id.
    result-shift_id = root-shift_id.
    result-work_date = root-work_date.
    result-is_valid = abap_true.
  ENDMETHOD.

  " Tìm receipt đã commit theo SyncItemUUID để xử lý retry theo cơ chế idempotent.
  METHOD find_persisted_sync_receipts.
    "A retry after a completed request must be recognizable even when SAP no
    "longer permits a new posting for the manufacturing operation.
    SELECT FROM ztb_pp_alloc_txn AS txn
      INNER JOIN ztb_pp_op_alloc AS op
        ON op~operation_uuid = txn~operation_uuid
      FIELDS txn~transaction_uuid, txn~operation_uuid, txn~actor_user_uuid,
             txn~original_transaction_uuid, txn~transaction_type, txn~worker_id,
             txn~from_worker_id, txn~to_worker_id, txn~work_id, txn~quantity, txn~uom,
             txn~execution_date, txn~shift_id, txn~executed_at,
             op~production_order, op~operation_no, op~ma_congdoan
      WHERE txn~sync_item_uuid = @sync_item_uuid
        AND txn~transaction_status = @zcl_pp_txn_type=>posted
      INTO CORRESPONDING FIELDS OF TABLE @result
      UP TO 2 ROWS.
  ENDMETHOD.

  " Đọc receipt của công đoạn trong transactional buffer theo SyncItemUUID.
  METHOD read_operation_sync_receipts.
    READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
      ENTITY OperationAllocation BY \_Transactions
        FIELDS ( TransactionUUID OperationUUID SyncItemUUID ActorUserUUID
                 OriginalTransactionUUID TransactionType WorkerID
                 FromWorkerID ToWorkerID WorkID Quantity UnitOfMeasure
                 ExecutionDate ShiftID ExecutedAt )
        WITH VALUE #( ( %key-OperationUUID = operation_uuid ) )
        RESULT DATA(transactions).
    LOOP AT transactions INTO DATA(transaction)
      WHERE SyncItemUUID = sync_item_uuid.
      APPEND VALUE #(
        transaction_uuid = transaction-TransactionUUID
        operation_uuid = transaction-OperationUUID
        actor_user_uuid = transaction-ActorUserUUID
        original_transaction_uuid = transaction-OriginalTransactionUUID
        transaction_type = transaction-TransactionType
        worker_id = transaction-WorkerID
        work_id = transaction-WorkID
        from_worker_id = transaction-FromWorkerID
        to_worker_id = transaction-ToWorkerID
        quantity = transaction-Quantity
        uom = transaction-UnitOfMeasure
        execution_date = transaction-ExecutionDate
        shift_id = transaction-ShiftID
        executed_at = transaction-ExecutedAt ) TO result.
    ENDLOOP.
  ENDMETHOD.

  " Xử lý giao sản lượng ban đầu cho công nhân, gồm ca, UoM, quyền và ledger.
  METHOD initialAssign.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      DATA(input) = <key>-%param.
      TRY.
          DATA(auth) = zcl_mob_token_validator=>validate_token(
            token = CONV string( input-AccessToken )
            device_id = input-DeviceID
            required_func = func_initial_assign ).
        CATCH cx_abap_message_digest zcx_mob_config.
          report_instance_failure(
            EXPORTING operation_uuid = <key>-%tky-OperationUUID
                      text = 'Không thể xác thực yêu cầu'
            CHANGING failed = failed reported = reported ).
          CONTINUE.
      ENDTRY.
      IF auth-is_valid = abap_false.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = CONV string( auth-error_code )
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

      READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY OperationAllocation ALL FIELDS
        WITH VALUE #( ( %tky = <key>-%tky ) ) RESULT DATA(operations).
      IF operations IS INITIAL OR input-Quantity <= 0
         OR input-WorkID IS INITIAL
         OR input-ToWorkerID IS INITIAL OR input-SyncItemUUID IS INITIAL
         OR ( input-ExecutionDate IS INITIAL AND input-ExecutedAt IS INITIAL ).
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'Thiếu dữ liệu giao việc bắt buộc'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      DATA(operation) = operations[ 1 ].
      DATA(shift) = zcl_pp_shift_resolver=>resolve(
        plant = operation-Plant shift_id = input-ShiftID
        executed_at = input-ExecutedAt execution_date = input-ExecutionDate
        sync_item_uuid = input-SyncItemUUID ).
      IF shift-is_valid = abap_false.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = CONV string( shift-error_code )
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      input-ExecutionDate = shift-work_date.
      IF zcl_mob_token_validator=>has_func_op_scope(
           user_uuid = auth-user_uuid func_id = func_initial_assign
           plant = operation-Plant
           work_center = operation-WorkCenter
           work_id = input-WorkID
           ma_congdoan = operation-MaCongDoan
           effective_date = shift-work_date ) = abap_false.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'MANAGER_OPERATION_NOT_ALLOWED'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      IF input-UnitOfMeasure <> operation-UnitOfMeasure.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'UNIT_OF_MEASURE_MISMATCH'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      TRY.
          DATA(worker_auth) = zcl_mob_token_validator=>verify_worker_password(
            worker_id = input-ToWorkerID
            password = CONV string( input-WorkerPassword ) ).
        CATCH cx_abap_message_digest zcx_mob_config.
          report_instance_failure(
            EXPORTING operation_uuid = <key>-%tky-OperationUUID
                      text = 'WORKER_AUTH_FAILED'
            CHANGING failed = failed reported = reported ).
          CONTINUE.
      ENDTRY.
      DATA(worker_access) = COND worker_access_result(
        WHEN worker_auth-is_valid = abap_false
        THEN VALUE #( error_code = 'WORKER_AUTH_FAILED' )
        ELSE check_worker_access(
          user_uuid = worker_auth-worker_user_uuid
          worker_id = input-ToWorkerID
          plant = operation-Plant
          work_center = operation-WorkCenter
          work_id = input-WorkID
          ma_congdoan = operation-MaCongDoan
          effective_date = input-ExecutionDate ) ).
      IF worker_access-is_valid = abap_false.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = CONV string( worker_access-error_code )
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

      DATA(existing_txns) = read_operation_sync_receipts(
        operation_uuid = operation-OperationUUID
        sync_item_uuid = input-SyncItemUUID ).
      IF lines( existing_txns ) > 1.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'SYNC_RECEIPT_DUPLICATE'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      IF existing_txns IS NOT INITIAL.
        DATA(existing_txn) = existing_txns[ 1 ].
        IF existing_txn-actor_user_uuid = auth-user_uuid
           AND existing_txn-operation_uuid = operation-OperationUUID
          AND existing_txn-transaction_type = zcl_pp_txn_type=>initial_assign
          AND existing_txn-to_worker_id = input-ToWorkerID
          AND existing_txn-work_id = input-WorkID
          AND existing_txn-quantity = input-Quantity
          AND existing_txn-uom = input-UnitOfMeasure
          AND existing_txn-shift_id = input-ShiftID
          AND existing_txn-executed_at = input-ExecutedAt
          AND existing_txn-execution_date = input-ExecutionDate.
          APPEND VALUE #( %tky = operation-%tky %param = operation ) TO result.
        ELSE.
          report_instance_failure(
            EXPORTING operation_uuid = <key>-%tky-OperationUUID
                      text = 'IDEMPOTENCY_KEY_REUSED'
            CHANGING failed = failed reported = reported ).
        ENDIF.
        CONTINUE.
      ENDIF.

      DATA(worker_balances) = read_worker_balances( operation-OperationUUID ).
      DATA(allocated_quantity) = REDUCE ztb_pp_emp_alloc-remaining_qty(
        INIT total = CONV ztb_pp_emp_alloc-remaining_qty( 0 )
        FOR worker_balance IN worker_balances
        NEXT total = total + worker_balance-remaining_qty
                          + worker_balance-completed_qty ).
      IF allocated_quantity + input-Quantity
         > operation-OperationQuantity.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'OPERATION_QUANTITY_EXCEEDED'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

      DELETE worker_balances WHERE worker_id <> input-ToWorkerID.
      IF lines( worker_balances ) > 1.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'WORKER_BALANCE_DUPLICATE'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      DATA(balance) = VALUE worker_balance( worker_balances[ 1 ] OPTIONAL ).
      IF balance IS INITIAL.
        MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE
          ENTITY OperationAllocation CREATE BY \_Employees FIELDS
            ( WorkerID InitialAssignedQuantity RemainingQuantity UnitOfMeasure
              LastExecutionDate )
          WITH VALUE #( ( %tky = operation-%tky %target = VALUE #(
            ( %cid = |EMP{ sy-tabix }| WorkerID = input-ToWorkerID
              InitialAssignedQuantity = input-Quantity
              RemainingQuantity = input-Quantity
              UnitOfMeasure = input-UnitOfMeasure
              LastExecutionDate = input-ExecutionDate ) ) ) ).
      ELSE.
        MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE
          ENTITY EmployeeAllocation UPDATE FIELDS
            ( InitialAssignedQuantity RemainingQuantity LastExecutionDate )
          WITH VALUE #( ( EmployeeAllocationUUID = balance-employee_allocation_uuid
            InitialAssignedQuantity = balance-initial_assigned_qty + input-Quantity
            RemainingQuantity = balance-remaining_qty + input-Quantity
            LastExecutionDate = input-ExecutionDate ) ).
      ENDIF.

      DATA(allocation_root) = find_allocation_root( operation_uuid = operation-OperationUUID
                                              worker_id = input-ToWorkerID
                                              work_id = input-WorkID
                                              shift_id = shift-shift_id
                                              work_date = shift-work_date
                                              uom = input-UnitOfMeasure ).

      MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY OperationAllocation CREATE BY \_Transactions FIELDS
          (             OriginalTransactionUUID OriginalTransactionType SyncItemUUID ActorUserUUID VerifiedWorkerUserUUID WorkerVerifiedAt
            InitiatorSessionID DeviceID VerificationMethod TransactionType
             WorkerID ToWorkerID WorkID Quantity UnitOfMeasure ExecutionDate ShiftID WorkDate ExecutedAt ShiftStartAt
             ShiftEndAt ShiftTimeZone ShiftValidFrom
            TransactionStatus SourceChannel )
        WITH VALUE #( ( %tky = operation-%tky %target = VALUE #(
          ( %cid = |TXN{ sy-tabix }|
            OriginalTransactionUUID = allocation_root
            OriginalTransactionType = COND #( WHEN allocation_root IS NOT INITIAL
                                              THEN zcl_pp_txn_type=>initial_assign )
            SyncItemUUID = input-SyncItemUUID
            ActorUserUUID = auth-user_uuid
            VerifiedWorkerUserUUID = worker_auth-worker_user_uuid
            WorkerVerifiedAt = utclong_current( )
            InitiatorSessionID = auth-session_id DeviceID = input-DeviceID
            VerificationMethod = 'PASSWORD'
            ShiftID = shift-shift_id
            WorkDate = shift-work_date
            ExecutedAt = shift-executed_at
            ShiftStartAt = shift-shift_start_at
            ShiftEndAt = shift-shift_end_at
            ShiftTimeZone = shift-shift_time_zone
            ShiftValidFrom = shift-shift_valid_from
            TransactionType = zcl_pp_txn_type=>initial_assign
            WorkerID = input-ToWorkerID ToWorkerID = input-ToWorkerID WorkID = input-WorkID
            Quantity = input-Quantity UnitOfMeasure = input-UnitOfMeasure
            ExecutionDate = input-ExecutionDate
            TransactionStatus = zcl_pp_txn_type=>posted
            SourceChannel = zcl_pp_txn_type=>source_mobile ) ) ) ).
      APPEND VALUE #( %tky = operation-%tky %param = operation ) TO result.
    ENDLOOP.
  ENDMETHOD.

  " Xử lý điều chuyển sản lượng giữa hai công nhân và cập nhật các số dư liên quan.
  METHOD transfer.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      DATA(input) = <key>-%param.
      TRY.
          DATA(auth) = zcl_mob_token_validator=>validate_token(
            token = CONV string( input-AccessToken ) device_id = input-DeviceID
            required_func = func_transfer ).
        CATCH cx_abap_message_digest zcx_mob_config.
          report_instance_failure(
            EXPORTING operation_uuid = <key>-%tky-OperationUUID
                      text = 'Không thể xác thực yêu cầu điều chuyển'
            CHANGING failed = failed reported = reported ).
          CONTINUE.
      ENDTRY.
      IF auth-is_valid = abap_false.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = CONV string( auth-error_code )
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE ENTITY OperationAllocation ALL FIELDS
        WITH VALUE #( ( %tky = <key>-%tky ) ) RESULT DATA(operations).
      IF operations IS INITIAL OR input-Quantity <= 0
         OR input-WorkID IS INITIAL
         OR input-FromWorkerID IS INITIAL OR input-ToWorkerID IS INITIAL
         OR input-FromWorkerID = input-ToWorkerID OR input-SyncItemUUID IS INITIAL
         OR ( input-ExecutionDate IS INITIAL AND input-ExecutedAt IS INITIAL ).
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'Thiếu hoặc sai dữ liệu điều chuyển'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      DATA(operation) = operations[ 1 ].
      DATA(shift) = zcl_pp_shift_resolver=>resolve(
        plant = operation-Plant shift_id = input-ShiftID
        executed_at = input-ExecutedAt execution_date = input-ExecutionDate
        sync_item_uuid = input-SyncItemUUID ).
      IF shift-is_valid = abap_false.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = CONV string( shift-error_code )
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      input-ExecutionDate = shift-work_date.
      IF zcl_mob_token_validator=>has_func_op_scope(
           user_uuid = auth-user_uuid func_id = func_transfer
           plant = operation-Plant
           work_center = operation-WorkCenter
           work_id = input-WorkID
           ma_congdoan = operation-MaCongDoan
           effective_date = shift-work_date ) = abap_false.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'MANAGER_OPERATION_NOT_ALLOWED'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      TRY.
          DATA(worker_auth) = zcl_mob_token_validator=>verify_worker_password(
            worker_id = input-ToWorkerID password = CONV string( input-WorkerPassword ) ).
        CATCH cx_abap_message_digest zcx_mob_config.
          report_instance_failure(
            EXPORTING operation_uuid = <key>-%tky-OperationUUID
                      text = 'WORKER_AUTH_FAILED'
            CHANGING failed = failed reported = reported ).
          CONTINUE.
      ENDTRY.
      IF worker_auth-is_valid = abap_false
         OR input-UnitOfMeasure <> operation-UnitOfMeasure.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = COND string(
                      WHEN worker_auth-is_valid = abap_false
                      THEN 'WORKER_AUTH_FAILED'
                      ELSE 'UNIT_OF_MEASURE_MISMATCH' )
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      DATA(worker_access) = check_worker_access(
        user_uuid = worker_auth-worker_user_uuid
        worker_id = input-ToWorkerID
        plant = operation-Plant
        work_center = operation-WorkCenter
        work_id = input-WorkID
        ma_congdoan = operation-MaCongDoan
        effective_date = input-ExecutionDate ).
      IF worker_access-is_valid = abap_false.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = CONV string( worker_access-error_code )
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

      DATA(existing_txns) = read_operation_sync_receipts(
        operation_uuid = operation-OperationUUID
        sync_item_uuid = input-SyncItemUUID ).
      IF lines( existing_txns ) > 1.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'SYNC_RECEIPT_DUPLICATE'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      IF existing_txns IS NOT INITIAL.
        DATA(existing_txn) = existing_txns[ 1 ].
        IF existing_txn-actor_user_uuid = auth-user_uuid
           AND existing_txn-operation_uuid = operation-OperationUUID
          AND existing_txn-transaction_type = zcl_pp_txn_type=>transfer
          AND existing_txn-from_worker_id = input-FromWorkerID
          AND existing_txn-to_worker_id = input-ToWorkerID
          AND existing_txn-work_id = input-WorkID
          AND existing_txn-quantity = input-Quantity
          AND existing_txn-uom = input-UnitOfMeasure
          AND existing_txn-shift_id = input-ShiftID
          AND existing_txn-executed_at = input-ExecutedAt
          AND existing_txn-execution_date = input-ExecutionDate.
          APPEND VALUE #( %tky = operation-%tky %param = operation ) TO result.
        ELSE.
          report_instance_failure(
            EXPORTING operation_uuid = <key>-%tky-OperationUUID
                      text = 'IDEMPOTENCY_KEY_REUSED'
            CHANGING failed = failed reported = reported ).
        ENDIF.
        CONTINUE.
      ENDIF.

      DATA(balances) = read_worker_balances( operation-OperationUUID ).
      DATA(source) = VALUE worker_balance(
        balances[ worker_id = input-FromWorkerID ] OPTIONAL ).
      DATA(target) = VALUE worker_balance(
        balances[ worker_id = input-ToWorkerID ] OPTIONAL ).
      IF source IS INITIAL OR source-uom <> input-UnitOfMeasure
         OR source-remaining_qty < input-Quantity.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'SOURCE_BALANCE_INSUFFICIENT'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY EmployeeAllocation UPDATE FIELDS
          ( TransferredOutQuantity RemainingQuantity LastExecutionDate )
        WITH VALUE #( ( EmployeeAllocationUUID = source-employee_allocation_uuid
          TransferredOutQuantity = source-transferred_out_qty + input-Quantity
          RemainingQuantity = source-remaining_qty - input-Quantity
          LastExecutionDate = input-ExecutionDate ) ).
      IF target IS INITIAL.
        MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE
          ENTITY OperationAllocation CREATE BY \_Employees FIELDS
            ( WorkerID TransferredInQuantity RemainingQuantity UnitOfMeasure LastExecutionDate )
          WITH VALUE #( ( %tky = operation-%tky %target = VALUE #(
            ( %cid = |TRG{ sy-tabix }| WorkerID = input-ToWorkerID
              TransferredInQuantity = input-Quantity RemainingQuantity = input-Quantity
              UnitOfMeasure = input-UnitOfMeasure LastExecutionDate = input-ExecutionDate ) ) ) ).
      ELSE.
        MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE
          ENTITY EmployeeAllocation UPDATE FIELDS
            ( TransferredInQuantity RemainingQuantity LastExecutionDate )
          WITH VALUE #( ( EmployeeAllocationUUID = target-employee_allocation_uuid
            TransferredInQuantity = target-transferred_in_qty + input-Quantity
            RemainingQuantity = target-remaining_qty + input-Quantity
            LastExecutionDate = input-ExecutionDate ) ).
      ENDIF.

      MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY OperationAllocation CREATE BY \_Transactions FIELDS
          ( SyncItemUUID ActorUserUUID VerifiedWorkerUserUUID WorkerVerifiedAt
            InitiatorSessionID DeviceID VerificationMethod TransactionType
             FromWorkerID ToWorkerID WorkID Quantity UnitOfMeasure ExecutionDate ShiftID WorkDate
             ExecutedAt ShiftStartAt
             ShiftEndAt ShiftTimeZone ShiftValidFrom
            TransactionStatus SourceChannel )
        WITH VALUE #( ( %tky = operation-%tky %target = VALUE #(
          ( %cid = |TRN{ sy-tabix }| SyncItemUUID = input-SyncItemUUID
            ActorUserUUID = auth-user_uuid
            VerifiedWorkerUserUUID = worker_auth-worker_user_uuid
            WorkerVerifiedAt = utclong_current( ) InitiatorSessionID = auth-session_id
            DeviceID = input-DeviceID VerificationMethod = 'PASSWORD'
            ShiftID = shift-shift_id
            WorkDate = shift-work_date
            ExecutedAt = shift-executed_at
            ShiftStartAt = shift-shift_start_at
            ShiftEndAt = shift-shift_end_at
            ShiftTimeZone = shift-shift_time_zone
            ShiftValidFrom = shift-shift_valid_from
            TransactionType = zcl_pp_txn_type=>transfer
            FromWorkerID = input-FromWorkerID ToWorkerID = input-ToWorkerID WorkID = input-WorkID
            Quantity = input-Quantity UnitOfMeasure = input-UnitOfMeasure
            ExecutionDate = input-ExecutionDate TransactionStatus = zcl_pp_txn_type=>posted
            SourceChannel = zcl_pp_txn_type=>source_mobile ) ) ) ).
      APPEND VALUE #( %tky = operation-%tky %param = operation ) TO result.
    ENDLOOP.
  ENDMETHOD.

  " Xử lý thu hồi sản lượng đã giao và ghi nhận giao dịch ledger tương ứng.
  METHOD recall.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      DATA(input) = <key>-%param.
      TRY.
          DATA(auth) = zcl_mob_token_validator=>validate_token(
            token = CONV string( input-AccessToken ) device_id = input-DeviceID
            required_func = func_recall ).
        CATCH cx_abap_message_digest zcx_mob_config.
          report_instance_failure(
            EXPORTING operation_uuid = <key>-%tky-OperationUUID
                      text = 'Không thể xác thực yêu cầu thu hồi'
            CHANGING failed = failed reported = reported ).
          CONTINUE.
      ENDTRY.
      IF auth-is_valid = abap_false.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = CONV string( auth-error_code )
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE ENTITY OperationAllocation ALL FIELDS
        WITH VALUE #( ( %tky = <key>-%tky ) ) RESULT DATA(operations).
      IF operations IS INITIAL OR input-Quantity <= 0 OR input-WorkID IS INITIAL
         OR input-WorkerID IS INITIAL
         OR input-SyncItemUUID IS INITIAL OR input-OriginalTransactionUUID IS INITIAL
         OR ( input-ExecutionDate IS INITIAL AND input-ExecutedAt IS INITIAL ).
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'Thiếu dữ liệu thu hồi bắt buộc'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      DATA(operation) = operations[ 1 ].
      DATA(shift) = zcl_pp_shift_resolver=>resolve(
        plant = operation-Plant shift_id = input-ShiftID
        executed_at = input-ExecutedAt execution_date = input-ExecutionDate
        sync_item_uuid = input-SyncItemUUID ).
      IF shift-is_valid = abap_false.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = CONV string( shift-error_code )
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      input-ExecutionDate = shift-work_date.
      IF zcl_mob_token_validator=>has_func_op_scope(
           user_uuid = auth-user_uuid func_id = func_recall
           plant = operation-Plant
           work_center = operation-WorkCenter
           work_id = input-WorkID
           ma_congdoan = operation-MaCongDoan
           effective_date = shift-work_date ) = abap_false.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'MANAGER_OPERATION_NOT_ALLOWED'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      TRY.
          DATA(worker_auth) = zcl_mob_token_validator=>verify_worker_password(
            worker_id = input-WorkerID password = CONV string( input-WorkerPassword ) ).
        CATCH cx_abap_message_digest zcx_mob_config.
          report_instance_failure(
            EXPORTING operation_uuid = <key>-%tky-OperationUUID
                      text = 'WORKER_AUTH_FAILED'
            CHANGING failed = failed reported = reported ).
          CONTINUE.
      ENDTRY.
      IF worker_auth-is_valid = abap_false.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'WORKER_AUTH_FAILED'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      DATA(worker_access) = check_worker_access(
        user_uuid = worker_auth-worker_user_uuid
        worker_id = input-WorkerID
        plant = operation-Plant
        work_center = operation-WorkCenter
        work_id = input-WorkID
        ma_congdoan = operation-MaCongDoan
        effective_date = input-ExecutionDate ).
      IF worker_access-is_valid = abap_false.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = CONV string( worker_access-error_code )
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

      DATA(existing_txns) = read_operation_sync_receipts(
        operation_uuid = operation-OperationUUID
        sync_item_uuid = input-SyncItemUUID ).
      IF lines( existing_txns ) > 1.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'SYNC_RECEIPT_DUPLICATE'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      IF existing_txns IS NOT INITIAL.
        DATA(existing_txn) = existing_txns[ 1 ].
        IF existing_txn-actor_user_uuid = auth-user_uuid
           AND existing_txn-operation_uuid = operation-OperationUUID
          AND existing_txn-original_transaction_uuid = input-OriginalTransactionUUID
          AND existing_txn-transaction_type = zcl_pp_txn_type=>recall
          AND existing_txn-worker_id = input-WorkerID
          AND existing_txn-work_id = input-WorkID
          AND existing_txn-quantity = input-Quantity
          AND existing_txn-uom = input-UnitOfMeasure
          AND existing_txn-shift_id = input-ShiftID
          AND existing_txn-executed_at = input-ExecutedAt
          AND existing_txn-execution_date = input-ExecutionDate.
          APPEND VALUE #( %tky = operation-%tky %param = operation ) TO result.
        ELSE.
          report_instance_failure(
            EXPORTING operation_uuid = <key>-%tky-OperationUUID
                      text = 'IDEMPOTENCY_KEY_REUSED'
            CHANGING failed = failed reported = reported ).
        ENDIF.
        CONTINUE.
      ENDIF.

      READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY AllocationTransaction
          FIELDS ( OperationUUID TransactionType TransactionStatus
                   WorkerID ToWorkerID )
          WITH VALUE #(
            ( %key-TransactionUUID = input-OriginalTransactionUUID ) )
          RESULT DATA(root_transactions).
      DATA(root_transaction) = VALUE #( root_transactions[ 1 ] OPTIONAL ).
      DATA(root_type) = root_transaction-TransactionType.
      DATA(worker_balances) = read_worker_balances( operation-OperationUUID ).
      DELETE worker_balances WHERE worker_id <> input-WorkerID.
      IF lines( worker_balances ) > 1.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'WORKER_BALANCE_DUPLICATE'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      DATA(balance) = VALUE worker_balance( worker_balances[ 1 ] OPTIONAL ).
      IF root_transaction IS INITIAL
         OR root_transaction-OperationUUID <> operation-OperationUUID
         OR root_transaction-TransactionStatus <> zcl_pp_txn_type=>posted
         OR ( root_type <> zcl_pp_txn_type=>initial_assign
           AND root_type <> zcl_pp_txn_type=>transfer
           AND root_type <> zcl_pp_txn_type=>allocation_adjustment )
         OR ( root_transaction-WorkerID <> input-WorkerID
              AND root_transaction-ToWorkerID <> input-WorkerID )
         OR balance IS INITIAL OR balance-uom <> input-UnitOfMeasure
         OR balance-remaining_qty < input-Quantity.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'RECALL_NOT_ALLOWED'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      DATA(lineage) = get_usable_txn_qty(
        operation_uuid = operation-OperationUUID
        original_transaction_uuid = input-OriginalTransactionUUID
        worker_id = input-WorkerID
        uom = input-UnitOfMeasure ).
      IF lineage-is_valid = abap_false
         OR input-Quantity > lineage-usable_quantity.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'RECALL_ORIGINAL_QUANTITY_EXCEEDED'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY EmployeeAllocation UPDATE FIELDS
          ( RecalledQuantity RemainingQuantity LastExecutionDate )
        WITH VALUE #( ( EmployeeAllocationUUID = balance-employee_allocation_uuid
          RecalledQuantity = balance-recalled_qty + input-Quantity
          RemainingQuantity = balance-remaining_qty - input-Quantity
          LastExecutionDate = input-ExecutionDate ) )
        ENTITY OperationAllocation CREATE BY \_Transactions FIELDS
          ( OriginalTransactionUUID OriginalTransactionType SyncItemUUID ActorUserUUID
            VerifiedWorkerUserUUID WorkerVerifiedAt InitiatorSessionID DeviceID
            VerificationMethod TransactionType WorkerID FromWorkerID WorkID Quantity
             UnitOfMeasure ExecutionDate ShiftID WorkDate ExecutedAt ShiftStartAt ShiftEndAt ShiftTimeZone
             ShiftValidFrom TransactionStatus SourceChannel )
        WITH VALUE #( ( %tky = operation-%tky %target = VALUE #(
          ( %cid = |RCL{ sy-tabix }| OriginalTransactionUUID = input-OriginalTransactionUUID
            OriginalTransactionType = root_type SyncItemUUID = input-SyncItemUUID
            ActorUserUUID = auth-user_uuid
            VerifiedWorkerUserUUID = worker_auth-worker_user_uuid
            WorkerVerifiedAt = utclong_current( ) InitiatorSessionID = auth-session_id
            DeviceID = input-DeviceID VerificationMethod = 'PASSWORD'
            ShiftID = shift-shift_id
            WorkDate = shift-work_date
            ExecutedAt = shift-executed_at
            ShiftStartAt = shift-shift_start_at
            ShiftEndAt = shift-shift_end_at
            ShiftTimeZone = shift-shift_time_zone
            ShiftValidFrom = shift-shift_valid_from
            TransactionType = zcl_pp_txn_type=>recall WorkerID = input-WorkerID WorkID = input-WorkID
            FromWorkerID = input-WorkerID Quantity = input-Quantity
            UnitOfMeasure = input-UnitOfMeasure ExecutionDate = input-ExecutionDate
            TransactionStatus = zcl_pp_txn_type=>posted
            SourceChannel = zcl_pp_txn_type=>source_mobile ) ) ) ).
      APPEND VALUE #( %tky = operation-%tky %param = operation ) TO result.
    ENDLOOP.
  ENDMETHOD.

  " Xử lý xác nhận sản lượng của công nhân sau khi kiểm tra giao dịch gốc và quyền.
  METHOD confirm.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      DATA(input) = <key>-%param.
      TRY.
          DATA(auth) = zcl_mob_token_validator=>validate_token(
            token = CONV string( input-AccessToken ) device_id = input-DeviceID
            required_func = func_confirm ).
        CATCH cx_abap_message_digest zcx_mob_config.
          report_instance_failure(
            EXPORTING operation_uuid = <key>-%tky-OperationUUID
                      text = 'Không thể xác thực yêu cầu xác nhận'
            CHANGING failed = failed reported = reported ).
          CONTINUE.
      ENDTRY.
      IF auth-is_valid = abap_false.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = CONV string( auth-error_code )
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE ENTITY OperationAllocation ALL FIELDS
        WITH VALUE #( ( %tky = <key>-%tky ) ) RESULT DATA(operations).
      DATA(operation) = VALUE #( operations[ 1 ] OPTIONAL ).
      DATA(shift) = zcl_pp_shift_resolver=>resolve(
        plant = operation-Plant shift_id = input-ShiftID
        executed_at = input-ExecutedAt execution_date = input-ExecutionDate
        sync_item_uuid = input-SyncItemUUID ).
      IF operations IS INITIAL OR input-Quantity <= 0 OR input-WorkID IS INITIAL
         OR input-WorkerID IS INITIAL
         OR input-SyncItemUUID IS INITIAL OR input-OriginalTransactionUUID IS INITIAL
         OR shift-is_valid = abap_false.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = |CONFIRM_INPUT_INVALID { shift-error_code }|
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      input-ExecutionDate = shift-work_date.
      IF zcl_mob_token_validator=>has_func_op_scope(
           user_uuid = auth-user_uuid func_id = func_confirm
           plant = operation-Plant
           work_center = operation-WorkCenter
           work_id = input-WorkID
           ma_congdoan = operation-MaCongDoan
           effective_date = shift-work_date ) = abap_false.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                        text = 'MANAGER_OPERATION_NOT_ALLOWED'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      IF input-UnitOfMeasure <> operation-UnitOfMeasure.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'UNIT_OF_MEASURE_MISMATCH'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      TRY.
          DATA(worker_auth) = zcl_mob_token_validator=>verify_worker_password(
            worker_id = input-WorkerID password = CONV string( input-WorkerPassword ) ).
        CATCH cx_abap_message_digest zcx_mob_config.
          report_instance_failure(
            EXPORTING operation_uuid = <key>-%tky-OperationUUID
                      text = 'WORKER_AUTH_FAILED'
            CHANGING failed = failed reported = reported ).
          CONTINUE.
      ENDTRY.
      IF worker_auth-is_valid = abap_false.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'WORKER_AUTH_FAILED'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

      DATA(existing_txns) = read_operation_sync_receipts(
        operation_uuid = operation-OperationUUID
        sync_item_uuid = input-SyncItemUUID ).
      IF lines( existing_txns ) > 1.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'SYNC_RECEIPT_DUPLICATE'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      IF existing_txns IS NOT INITIAL.
        DATA(existing_txn) = existing_txns[ 1 ].
        IF existing_txn-actor_user_uuid = auth-user_uuid
           AND existing_txn-operation_uuid = operation-OperationUUID
          AND existing_txn-transaction_type = zcl_pp_txn_type=>confirm
          AND existing_txn-worker_id = input-WorkerID
          AND existing_txn-work_id = input-WorkID
          AND existing_txn-quantity = input-Quantity
          AND existing_txn-uom = input-UnitOfMeasure
          AND existing_txn-shift_id = input-ShiftID
          AND existing_txn-executed_at = input-ExecutedAt
          AND existing_txn-execution_date = input-ExecutionDate
          AND existing_txn-original_transaction_uuid = input-OriginalTransactionUUID.
          APPEND VALUE #( %tky = operation-%tky %param = operation ) TO result.
        ELSE.
          report_instance_failure(
            EXPORTING operation_uuid = <key>-%tky-OperationUUID
                      text = 'IDEMPOTENCY_KEY_REUSED'
            CHANGING failed = failed reported = reported ).
        ENDIF.
        CONTINUE.
      ENDIF.

      DATA(worker_balances) = read_worker_balances( operation-OperationUUID ).
      DATA(balance_check) = validate_worker_balance(
        balances = worker_balances
        worker_identifier = input-WorkerID
        quantity = input-Quantity
        uom = input-UnitOfMeasure ).
      IF balance_check-is_valid = abap_false.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = CONV string( balance_check-error_code )
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      DATA(balance) = balance_check-balance.

      DATA(lineage) = get_usable_txn_qty(
        operation_uuid = operation-OperationUUID
        original_transaction_uuid = input-OriginalTransactionUUID
        worker_id = input-WorkerID
        uom = input-UnitOfMeasure ).
      IF lineage-is_valid = abap_false.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'CONFIRM_ORIGINAL_TRANSACTION_INVALID'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      IF input-Quantity > lineage-usable_quantity.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'CONFIRM_ORIGINAL_QUANTITY_EXCEEDED'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      DATA(worker_access) = check_worker_access(
        user_uuid = worker_auth-worker_user_uuid
        worker_id = input-WorkerID
        plant = operation-Plant
        work_center = operation-WorkCenter
        work_id = input-WorkID
        ma_congdoan = operation-MaCongDoan
        effective_date = input-ExecutionDate ).
      IF worker_access-is_valid = abap_false.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = CONV string( worker_access-error_code )
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      DATA(original_type) = lineage-source_transaction_type.

      MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY EmployeeAllocation UPDATE FIELDS
          ( CompletedQuantity RemainingQuantity LastExecutionDate LastSyncAt )
        WITH VALUE #( ( EmployeeAllocationUUID = balance-employee_allocation_uuid
          CompletedQuantity = balance-completed_qty + input-Quantity
          RemainingQuantity = balance-remaining_qty - input-Quantity
          LastExecutionDate = input-ExecutionDate LastSyncAt = utclong_current( ) ) )
        ENTITY OperationAllocation CREATE BY \_Transactions FIELDS
          ( OriginalTransactionUUID OriginalTransactionType SyncItemUUID ActorUserUUID
            VerifiedWorkerUserUUID WorkerVerifiedAt InitiatorSessionID DeviceID
            VerificationMethod TransactionType WorkerID WorkID Quantity UnitOfMeasure
             ExecutionDate ShiftID WorkDate ExecutedAt ShiftStartAt ShiftEndAt ShiftTimeZone ShiftValidFrom
             TransactionStatus SourceChannel )
        WITH VALUE #( ( %tky = operation-%tky %target = VALUE #(
          ( %cid = |CFM{ sy-tabix }| OriginalTransactionUUID = input-OriginalTransactionUUID
            OriginalTransactionType = original_type SyncItemUUID = input-SyncItemUUID
            ActorUserUUID = auth-user_uuid
            VerifiedWorkerUserUUID = worker_auth-worker_user_uuid
            WorkerVerifiedAt = utclong_current( ) InitiatorSessionID = auth-session_id
            DeviceID = input-DeviceID VerificationMethod = 'PASSWORD'
            ShiftID = shift-shift_id
            WorkDate = shift-work_date
            ExecutedAt = shift-executed_at
            ShiftStartAt = shift-shift_start_at
            ShiftEndAt = shift-shift_end_at
            ShiftTimeZone = shift-shift_time_zone
            ShiftValidFrom = shift-shift_valid_from
            TransactionType = zcl_pp_txn_type=>confirm WorkerID = input-WorkerID WorkID = input-WorkID
            Quantity = input-Quantity UnitOfMeasure = input-UnitOfMeasure
            ExecutionDate = input-ExecutionDate TransactionStatus = zcl_pp_txn_type=>posted
            SourceChannel = zcl_pp_txn_type=>source_mobile ) ) ) ).
      APPEND VALUE #( %tky = operation-%tky %param = operation ) TO result.
    ENDLOOP.
  ENDMETHOD.

  " Đảo một giao dịch xác nhận đã ghi nhận và hoàn trả số dư phù hợp.
  METHOD reverse.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      DATA(input) = <key>-%param.
      TRY.
          DATA(auth) = zcl_mob_token_validator=>validate_token(
            token = CONV string( input-AccessToken ) device_id = input-DeviceID
            required_func = func_reverse ).
        CATCH cx_abap_message_digest zcx_mob_config.
          report_instance_failure(
            EXPORTING operation_uuid = <key>-%tky-OperationUUID
                      text = 'Không thể xác thực yêu cầu đảo xác nhận'
            CHANGING failed = failed reported = reported ).
          CONTINUE.
      ENDTRY.
      IF auth-is_valid = abap_false.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = CONV string( auth-error_code )
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE ENTITY OperationAllocation ALL FIELDS
        WITH VALUE #( ( %tky = <key>-%tky ) ) RESULT DATA(operations).
      IF operations IS INITIAL OR input-WorkID IS INITIAL
         OR input-TransactionUUID IS INITIAL
         OR input-SyncItemUUID IS INITIAL OR input-Reason IS INITIAL.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'REVERSE_INPUT_INVALID'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      DATA(operation) = operations[ 1 ].
      IF zcl_mob_token_validator=>has_func_op_scope(
           user_uuid = auth-user_uuid func_id = func_reverse
           plant = operation-Plant
           work_center = operation-WorkCenter
           work_id = input-WorkID
           ma_congdoan = operation-MaCongDoan
           effective_date = cl_abap_context_info=>get_system_date( ) ) = abap_false.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                        text = 'MANAGER_OPERATION_NOT_ALLOWED'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

      DATA(existing_receipts) = read_operation_sync_receipts(
        operation_uuid = operation-OperationUUID
        sync_item_uuid = input-SyncItemUUID ).
      IF lines( existing_receipts ) > 1.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'SYNC_RECEIPT_DUPLICATE'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      IF existing_receipts IS NOT INITIAL.
        DATA(existing_receipt) = existing_receipts[ 1 ].
        IF existing_receipt-actor_user_uuid = auth-user_uuid
          AND existing_receipt-operation_uuid = operation-OperationUUID
          AND existing_receipt-transaction_type = zcl_pp_txn_type=>reverse
          AND existing_receipt-work_id = input-WorkID
          AND existing_receipt-original_transaction_uuid = input-TransactionUUID.
          APPEND VALUE #( %tky = operation-%tky %param = operation ) TO result.
        ELSE.
          report_instance_failure(
            EXPORTING operation_uuid = <key>-%tky-OperationUUID
                      text = 'IDEMPOTENCY_KEY_REUSED'
            CHANGING failed = failed reported = reported ).
        ENDIF.
        CONTINUE.
      ENDIF.

      SELECT FROM ztb_pp_alloc_txn
        FIELDS transaction_uuid, worker_id, work_id, quantity, uom, execution_date,
               shift_id, work_date, executed_at, shift_start_at, shift_end_at, shift_time_zone, shift_valid_from
        WHERE transaction_uuid = @input-TransactionUUID
          AND operation_uuid = @operation-OperationUUID
          AND transaction_type = @zcl_pp_txn_type=>confirm
          AND transaction_status = @zcl_pp_txn_type=>posted
        INTO TABLE @DATA(originals) UP TO 2 ROWS.
      IF lines( originals ) <> 1.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'CONFIRM_TRANSACTION_NOT_FOUND'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      DATA(original) = originals[ 1 ].
      IF original-work_id IS NOT INITIAL AND original-work_id <> input-WorkID.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'WORK_CONTEXT_MISMATCH'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

      SELECT FROM ztb_pp_alloc_txn
        FIELDS transaction_uuid
        WHERE original_transaction_uuid = @input-TransactionUUID
          AND transaction_type = @zcl_pp_txn_type=>reverse
          AND transaction_status = @zcl_pp_txn_type=>posted
        INTO TABLE @DATA(reversals) UP TO 1 ROWS.
      IF reversals IS NOT INITIAL.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'TRANSACTION_ALREADY_REVERSED'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

      SELECT FROM ztb_pp_alloc_txn
        FIELDS SUM( quantity ) AS correction_qty
        WHERE original_transaction_uuid = @input-TransactionUUID
          AND transaction_type = @zcl_pp_txn_type=>correction
          AND transaction_status = @zcl_pp_txn_type=>posted
        INTO @DATA(corrections).
      DATA effective_qty TYPE ztb_pp_alloc_txn-quantity.
      effective_qty = original-quantity + corrections.
      IF effective_qty <= 0.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'NOTHING_TO_REVERSE'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

      DATA(worker_balances) = read_worker_balances( operation-OperationUUID ).
      DELETE worker_balances WHERE worker_id <> original-worker_id.
      IF lines( worker_balances ) <> 1.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'WORKER_BALANCE_NOT_FOUND'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      DATA(balance) = worker_balances[ 1 ].
      IF balance-uom <> original-uom OR balance-completed_qty < effective_qty.
        report_instance_failure(
          EXPORTING operation_uuid = <key>-%tky-OperationUUID
                    text = 'REVERSE_BALANCE_INCONSISTENT'
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY EmployeeAllocation UPDATE FIELDS
          ( CompletedQuantity RemainingQuantity LastExecutionDate LastSyncAt )
        WITH VALUE #( ( EmployeeAllocationUUID = balance-employee_allocation_uuid
          CompletedQuantity = balance-completed_qty - effective_qty
          RemainingQuantity = balance-remaining_qty + effective_qty
          LastExecutionDate = cl_abap_context_info=>get_system_date( )
          LastSyncAt = utclong_current( ) ) )
        ENTITY OperationAllocation CREATE BY \_Transactions FIELDS
          ( OriginalTransactionUUID OriginalTransactionType SyncItemUUID ActorUserUUID
            InitiatorSessionID DeviceID VerificationMethod TransactionType WorkerID
             WorkID Quantity UnitOfMeasure ExecutionDate ShiftID WorkDate ExecutedAt ShiftStartAt
             ShiftEndAt ShiftTimeZone
             ShiftValidFrom TransactionStatus ReasonCode ReasonText
            SourceChannel ReversalReason )
        WITH VALUE #( ( %tky = operation-%tky %target = VALUE #(
          ( %cid = |REV{ sy-tabix }| OriginalTransactionUUID = input-TransactionUUID
            OriginalTransactionType = zcl_pp_txn_type=>confirm
            SyncItemUUID = input-SyncItemUUID ActorUserUUID = auth-user_uuid
            InitiatorSessionID = auth-session_id DeviceID = input-DeviceID
            VerificationMethod = 'SESSION'
            TransactionType = zcl_pp_txn_type=>reverse WorkerID = original-worker_id
            WorkID = COND #( WHEN original-work_id IS INITIAL THEN input-WorkID ELSE original-work_id )
            Quantity = effective_qty UnitOfMeasure = original-uom
            ExecutionDate = original-execution_date
            ShiftID = original-shift_id
            WorkDate = original-work_date
            ExecutedAt = original-executed_at
            ShiftStartAt = original-shift_start_at
            ShiftEndAt = original-shift_end_at
            ShiftTimeZone = original-shift_time_zone
            ShiftValidFrom = original-shift_valid_from
            TransactionStatus = zcl_pp_txn_type=>posted ReasonCode = 'USER_REVERSAL'
            ReasonText = input-Reason ReversalReason = input-Reason
            SourceChannel = zcl_pp_txn_type=>source_mobile ) ) ) ).
      APPEND VALUE #( %tky = operation-%tky %param = operation ) TO result.
    ENDLOOP.
  ENDMETHOD.

  " Facade static action: xác thực token, resolve công đoạn rồi gọi action giao ban đầu.
  METHOD submitInitialAssign.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      DATA(input) = <key>-%param.
      DATA(cid) = <key>-%cid.
      TRY.
          DATA(auth) = zcl_mob_token_validator=>validate_token(
            token = CONV string( input-AccessToken ) device_id = input-DeviceID
            required_func = func_initial_assign ).
        CATCH cx_abap_message_digest zcx_mob_config.
          report_failure( EXPORTING cid = cid text = 'AUTH_FAILED'
                          CHANGING failed = failed reported = reported ).
          CONTINUE.
      ENDTRY.
      IF auth-is_valid = abap_false.
        report_failure( EXPORTING cid = cid text = CONV string( auth-error_code )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      DATA(context) = ensure_operation(
        production_order = input-ProductionOrder
        operation_no = input-Operation
        user_uuid = auth-user_uuid
        func_id = func_initial_assign
        work_id = input-WorkID
        effective_date = input-ExecutionDate ).
      IF context-is_valid = abap_false.
        report_failure( EXPORTING cid = cid text = CONV string( context-error_code )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY OperationAllocation EXECUTE initialAssign
        FROM VALUE #( ( %tky = VALUE #( OperationUUID = context-operation_uuid )
                        %param = input ) )
        FAILED DATA(action_failed)
        REPORTED DATA(action_reported).
      IF action_failed-operationallocation IS NOT INITIAL.
        forward_action_failure(
          EXPORTING cid = cid operation_uuid = context-operation_uuid
                    action_reported = action_reported
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY OperationAllocation BY \_Transactions
          FIELDS ( TransactionUUID SyncItemUUID )
          WITH VALUE #( ( %key-OperationUUID = context-operation_uuid ) )
          RESULT DATA(receipt_rows).
      DATA(receipt_count) = 0.
      DATA txn_uuid TYPE ztb_pp_alloc_txn-transaction_uuid.
      LOOP AT receipt_rows ASSIGNING FIELD-SYMBOL(<receipt>)
        WHERE SyncItemUUID = input-SyncItemUUID.
        receipt_count = receipt_count + 1.
        txn_uuid = <receipt>-TransactionUUID.
        IF receipt_count > 1.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF receipt_count <> 1.
        report_failure( EXPORTING cid = cid
                          text = COND string(
                            WHEN receipt_count = 0 THEN 'SYNC_RECEIPT_NOT_FOUND'
                            ELSE 'SYNC_RECEIPT_DUPLICATE' )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      result = VALUE #( BASE result ( %cid = cid %param = VALUE #(
        Status = 'SUCCESS' SyncItemUUID = input-SyncItemUUID TransactionUUID = txn_uuid
        ProductionOrder = context-production_order Operation = context-operation_no
        MaCongDoan = context-ma_congdoan Message = 'Đã ghi nhận giao việc' ) ) ).
    ENDLOOP.
  ENDMETHOD.

  " Facade static action: xác thực token, resolve công đoạn rồi gọi action điều chuyển.
  METHOD submitTransfer.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      DATA(input) = <key>-%param.
      DATA(cid) = <key>-%cid.
      TRY.
          DATA(auth) = zcl_mob_token_validator=>validate_token(
            token = CONV string( input-AccessToken ) device_id = input-DeviceID
            required_func = func_transfer ).
        CATCH cx_abap_message_digest zcx_mob_config.
          report_failure( EXPORTING cid = cid text = 'AUTH_FAILED'
                          CHANGING failed = failed reported = reported ).
          CONTINUE.
      ENDTRY.
      IF auth-is_valid = abap_false.
        report_failure( EXPORTING cid = cid text = CONV string( auth-error_code )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      DATA(context) = ensure_operation(
        production_order = input-ProductionOrder
        operation_no = input-Operation
        user_uuid = auth-user_uuid
        func_id = func_transfer
        work_id = input-WorkID
        effective_date = input-ExecutionDate ).
      IF context-is_valid = abap_false.
        report_failure( EXPORTING cid = cid text = CONV string( context-error_code )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE ENTITY OperationAllocation EXECUTE transfer
        FROM VALUE #( ( %tky = VALUE #( OperationUUID = context-operation_uuid ) %param = input ) )
        FAILED DATA(action_failed)
        REPORTED DATA(action_reported).
      IF action_failed-operationallocation IS NOT INITIAL.
        forward_action_failure(
          EXPORTING cid = cid operation_uuid = context-operation_uuid
                    action_reported = action_reported
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY OperationAllocation BY \_Transactions
          FIELDS ( TransactionUUID SyncItemUUID )
          WITH VALUE #( ( %key-OperationUUID = context-operation_uuid ) )
          RESULT DATA(receipt_rows).
      DATA(receipt_count) = 0.
      DATA txn_uuid TYPE ztb_pp_alloc_txn-transaction_uuid.
      LOOP AT receipt_rows ASSIGNING FIELD-SYMBOL(<receipt>)
        WHERE SyncItemUUID = input-SyncItemUUID.
        receipt_count = receipt_count + 1.
        txn_uuid = <receipt>-TransactionUUID.
        IF receipt_count > 1.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF receipt_count <> 1.
        report_failure( EXPORTING cid = cid
                          text = COND string(
                            WHEN receipt_count = 0 THEN 'SYNC_RECEIPT_NOT_FOUND'
                            ELSE 'SYNC_RECEIPT_DUPLICATE' )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      result = VALUE #( BASE result ( %cid = cid %param = VALUE #(
        Status = 'SUCCESS' SyncItemUUID = input-SyncItemUUID TransactionUUID = txn_uuid
        ProductionOrder = context-production_order Operation = context-operation_no
        MaCongDoan = context-ma_congdoan Message = 'Đã ghi nhận điều chuyển' ) ) ).
    ENDLOOP.
  ENDMETHOD.

  " Facade static action: xác thực token, resolve công đoạn rồi gọi action thu hồi.
  METHOD submitRecall.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      DATA(input) = <key>-%param.
      DATA(cid) = <key>-%cid.
      TRY.
          DATA(auth) = zcl_mob_token_validator=>validate_token(
            token = CONV string( input-AccessToken ) device_id = input-DeviceID
            required_func = func_recall ).
        CATCH cx_abap_message_digest zcx_mob_config.
          report_failure( EXPORTING cid = cid text = 'AUTH_FAILED'
                          CHANGING failed = failed reported = reported ).
          CONTINUE.
      ENDTRY.
      IF auth-is_valid = abap_false.
        report_failure( EXPORTING cid = cid text = CONV string( auth-error_code )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      DATA(context) = ensure_operation(
        production_order = input-ProductionOrder
        operation_no = input-Operation
        user_uuid = auth-user_uuid
        func_id = func_recall
        work_id = input-WorkID
        effective_date = input-ExecutionDate ).
      IF context-is_valid = abap_false.
        report_failure( EXPORTING cid = cid text = CONV string( context-error_code )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE ENTITY OperationAllocation EXECUTE recall
        FROM VALUE #( ( %tky = VALUE #( OperationUUID = context-operation_uuid ) %param = input ) )
        FAILED DATA(action_failed)
        REPORTED DATA(action_reported).
      IF action_failed-operationallocation IS NOT INITIAL.
        forward_action_failure(
          EXPORTING cid = cid operation_uuid = context-operation_uuid
                    action_reported = action_reported
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY OperationAllocation BY \_Transactions
          FIELDS ( TransactionUUID SyncItemUUID )
          WITH VALUE #( ( %key-OperationUUID = context-operation_uuid ) )
          RESULT DATA(receipt_rows).
      DATA(receipt_count) = 0.
      DATA txn_uuid TYPE ztb_pp_alloc_txn-transaction_uuid.
      LOOP AT receipt_rows ASSIGNING FIELD-SYMBOL(<receipt>)
        WHERE SyncItemUUID = input-SyncItemUUID.
        receipt_count = receipt_count + 1.
        txn_uuid = <receipt>-TransactionUUID.
        IF receipt_count > 1.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF receipt_count <> 1.
        report_failure( EXPORTING cid = cid
                          text = COND string(
                            WHEN receipt_count = 0 THEN 'SYNC_RECEIPT_NOT_FOUND'
                            ELSE 'SYNC_RECEIPT_DUPLICATE' )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      result = VALUE #( BASE result ( %cid = cid %param = VALUE #(
        Status = 'SUCCESS' SyncItemUUID = input-SyncItemUUID TransactionUUID = txn_uuid
        ProductionOrder = context-production_order Operation = context-operation_no
        MaCongDoan = context-ma_congdoan Message = 'Đã ghi nhận thu hồi' ) ) ).
    ENDLOOP.
  ENDMETHOD.

  " Facade static action: xác thực token, resolve công đoạn và xử lý xác nhận idempotent.
  METHOD submitConfirm.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      DATA(input) = <key>-%param.
      DATA(cid) = <key>-%cid.
      TRY.
          DATA(auth) = zcl_mob_token_validator=>validate_token(
            token = CONV string( input-AccessToken ) device_id = input-DeviceID
            required_func = func_confirm ).
        CATCH cx_abap_message_digest zcx_mob_config.
          report_failure( EXPORTING cid = cid text = 'AUTH_FAILED'
                          CHANGING failed = failed reported = reported ).
          CONTINUE.
      ENDTRY.
      IF auth-is_valid = abap_false.
        report_failure( EXPORTING cid = cid text = CONV string( auth-error_code )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      DATA(context) = ensure_operation(
        production_order = input-ProductionOrder
        operation_no = input-Operation
        user_uuid = auth-user_uuid
        func_id = func_confirm
        work_id = input-WorkID
        effective_date = input-ExecutionDate ).
      IF context-is_valid = abap_false.
        report_failure( EXPORTING cid = cid text = CONV string( context-error_code )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      DATA(existing_receipts) = find_persisted_sync_receipts(
        input-SyncItemUUID ).
      IF lines( existing_receipts ) > 1.
        report_failure( EXPORTING cid = cid text = 'SYNC_RECEIPT_DUPLICATE'
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      IF existing_receipts IS NOT INITIAL.
        DATA(existing_receipt) = existing_receipts[ 1 ].
        IF existing_receipt-actor_user_uuid = auth-user_uuid
           AND existing_receipt-transaction_type = zcl_pp_txn_type=>confirm
           AND existing_receipt-production_order = input-ProductionOrder
           AND existing_receipt-operation_no = input-Operation
           AND existing_receipt-original_transaction_uuid = input-OriginalTransactionUUID
           AND existing_receipt-worker_id = input-WorkerID
           AND existing_receipt-work_id = input-WorkID
           AND existing_receipt-quantity = input-Quantity
           AND existing_receipt-uom = input-UnitOfMeasure
           AND existing_receipt-shift_id = input-ShiftID
           AND existing_receipt-executed_at = input-ExecutedAt
           AND existing_receipt-execution_date = input-ExecutionDate.
          result = VALUE #( BASE result ( %cid = cid %param = VALUE #(
            Status = 'SUCCESS' SyncItemUUID = input-SyncItemUUID
            TransactionUUID = existing_receipt-transaction_uuid
            ProductionOrder = existing_receipt-production_order
            Operation = existing_receipt-operation_no
            MaCongDoan = existing_receipt-ma_congdoan
            Message = 'Đã ghi nhận sản lượng' ) ) ).
        ELSE.
          report_failure( EXPORTING cid = cid text = 'IDEMPOTENCY_KEY_REUSED'
                          CHANGING failed = failed reported = reported ).
        ENDIF.
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE ENTITY OperationAllocation EXECUTE confirm
        FROM VALUE #( ( %tky = VALUE #( OperationUUID = context-operation_uuid ) %param = input ) )
        FAILED DATA(action_failed)
        REPORTED DATA(action_reported).
      IF action_failed-operationallocation IS NOT INITIAL.
        forward_action_failure(
          EXPORTING cid = cid operation_uuid = context-operation_uuid
                    action_reported = action_reported
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY OperationAllocation BY \_Transactions
          FIELDS ( TransactionUUID SyncItemUUID )
          WITH VALUE #( ( %key-OperationUUID = context-operation_uuid ) )
          RESULT DATA(receipt_rows).
      DATA(receipt_count) = 0.
      DATA txn_uuid TYPE ztb_pp_alloc_txn-transaction_uuid.
      LOOP AT receipt_rows ASSIGNING FIELD-SYMBOL(<receipt>)
        WHERE SyncItemUUID = input-SyncItemUUID.
        receipt_count = receipt_count + 1.
        txn_uuid = <receipt>-TransactionUUID.
        IF receipt_count > 1.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF receipt_count <> 1.
        report_failure( EXPORTING cid = cid
                          text = COND string(
                            WHEN receipt_count = 0 THEN 'SYNC_RECEIPT_NOT_FOUND'
                            ELSE 'SYNC_RECEIPT_DUPLICATE' )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      result = VALUE #( BASE result ( %cid = cid %param = VALUE #(
        Status = 'SUCCESS' SyncItemUUID = input-SyncItemUUID TransactionUUID = txn_uuid
        ProductionOrder = context-production_order Operation = context-operation_no
        MaCongDoan = context-ma_congdoan Message = 'Đã ghi nhận sản lượng' ) ) ).
    ENDLOOP.
  ENDMETHOD.

  " Facade static action: xác thực token, resolve công đoạn rồi gọi action đảo giao dịch.
  METHOD submitReverse.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      DATA(input) = <key>-%param.
      DATA(cid) = <key>-%cid.
      TRY.
          DATA(auth) = zcl_mob_token_validator=>validate_token(
            token = CONV string( input-AccessToken ) device_id = input-DeviceID
            required_func = func_reverse ).
        CATCH cx_abap_message_digest zcx_mob_config.
          report_failure( EXPORTING cid = cid text = 'AUTH_FAILED'
                          CHANGING failed = failed reported = reported ).
          CONTINUE.
      ENDTRY.
      IF auth-is_valid = abap_false.
        report_failure( EXPORTING cid = cid text = CONV string( auth-error_code )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      DATA(context) = ensure_operation(
        production_order = input-ProductionOrder
        operation_no = input-Operation
        user_uuid = auth-user_uuid
        func_id = func_reverse
        work_id = input-WorkID ).
      IF context-is_valid = abap_false.
        report_failure( EXPORTING cid = cid text = CONV string( context-error_code )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE ENTITY OperationAllocation EXECUTE reverse
        FROM VALUE #( ( %tky = VALUE #( OperationUUID = context-operation_uuid ) %param = input ) )
        FAILED DATA(action_failed)
        REPORTED DATA(action_reported).
      IF action_failed-operationallocation IS NOT INITIAL.
        forward_action_failure(
          EXPORTING cid = cid operation_uuid = context-operation_uuid
                    action_reported = action_reported
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY OperationAllocation BY \_Transactions
          FIELDS ( TransactionUUID SyncItemUUID )
          WITH VALUE #( ( %key-OperationUUID = context-operation_uuid ) )
          RESULT DATA(receipt_rows).
      DATA(receipt_count) = 0.
      DATA txn_uuid TYPE ztb_pp_alloc_txn-transaction_uuid.
      LOOP AT receipt_rows ASSIGNING FIELD-SYMBOL(<receipt>)
        WHERE SyncItemUUID = input-SyncItemUUID.
        receipt_count = receipt_count + 1.
        txn_uuid = <receipt>-TransactionUUID.
        IF receipt_count > 1.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF receipt_count <> 1.
        report_failure( EXPORTING cid = cid
                          text = COND string(
                            WHEN receipt_count = 0 THEN 'SYNC_RECEIPT_NOT_FOUND'
                            ELSE 'SYNC_RECEIPT_DUPLICATE' )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      result = VALUE #( BASE result ( %cid = cid %param = VALUE #(
        Status = 'SUCCESS' SyncItemUUID = input-SyncItemUUID TransactionUUID = txn_uuid
        ProductionOrder = context-production_order Operation = context-operation_no
        MaCongDoan = context-ma_congdoan Message = 'Đã đảo giao dịch xác nhận' ) ) ).
    ENDLOOP.
  ENDMETHOD.

  " Tra cứu trạng thái đồng bộ đã commit của một SyncItemUUID.
  METHOD getSyncStatus.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      DATA(input) = <key>-%param.
      DATA(cid) = <key>-%cid.
      TRY.
          DATA(auth) = zcl_mob_token_validator=>validate_token(
            token = CONV string( input-AccessToken ) device_id = input-DeviceID ).
        CATCH cx_abap_message_digest zcx_mob_config.
          report_failure( EXPORTING cid = cid text = 'AUTH_FAILED'
                          CHANGING failed = failed reported = reported ).
          CONTINUE.
      ENDTRY.
      IF auth-is_valid = abap_false OR input-SyncItemUUID IS INITIAL.
        report_failure( EXPORTING cid = cid
          text = COND string( WHEN auth-is_valid = abap_false
                              THEN CONV string( auth-error_code ) ELSE 'SYNC_ITEM_REQUIRED' )
          CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

      SELECT FROM ztb_pp_alloc_txn AS txn
        INNER JOIN ztb_pp_op_alloc AS op ON op~operation_uuid = txn~operation_uuid
        FIELDS txn~transaction_uuid, txn~transaction_type, txn~worker_id,
               txn~quantity, txn~uom, txn~execution_date,
               txn~shift_id, txn~work_date, txn~executed_at,
               txn~shift_start_at, txn~shift_end_at, txn~shift_time_zone, txn~shift_valid_from,
               op~production_order, op~operation_no
        WHERE txn~sync_item_uuid = @input-SyncItemUUID
          AND txn~actor_user_uuid = @auth-user_uuid
          AND txn~transaction_status = @zcl_pp_txn_type=>posted
        INTO TABLE @DATA(receipts) UP TO 2 ROWS.
      IF lines( receipts ) > 1.
        report_failure( EXPORTING cid = cid text = 'SYNC_RECEIPT_DUPLICATE'
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      IF receipts IS INITIAL.
        result = VALUE #( BASE result ( %cid = cid %param = VALUE #(
          Status = 'NOT_FOUND' SyncItemUUID = input-SyncItemUUID
          Message = 'SAP chưa chứng minh request này đã được commit; không được coi là FAILED' ) ) ).
        CONTINUE.
      ENDIF.
      DATA(receipt) = receipts[ 1 ].
      result = VALUE #( BASE result ( %cid = cid %param = VALUE #(
        Status = 'SUCCESS' SyncItemUUID = input-SyncItemUUID
        TransactionUUID = receipt-transaction_uuid TransactionType = receipt-transaction_type
        ProductionOrder = receipt-production_order Operation = receipt-operation_no
        WorkerID = receipt-worker_id Quantity = receipt-quantity
        UnitOfMeasure = receipt-uom ExecutionDate = receipt-execution_date
        ShiftID = receipt-shift_id
        WorkDate = COND #( WHEN receipt-work_date IS INITIAL
                           THEN receipt-execution_date
                           ELSE receipt-work_date )
        ExecutedAt = receipt-executed_at
        ShiftStartAt = receipt-shift_start_at
        ShiftEndAt = receipt-shift_end_at
        ShiftTimeZone = receipt-shift_time_zone
        ShiftValidFrom = receipt-shift_valid_from
        Message = 'Request đã được commit vào ledger CASLA' ) ) ).
    ENDLOOP.
  ENDMETHOD.

  " Đưa lỗi nghiệp vụ vào failed và reported của instance RAP.
  METHOD report_instance_failure.
    APPEND VALUE #(
      %tky = VALUE #( OperationUUID = operation_uuid ) )
      TO failed-operationallocation.
    APPEND VALUE #(
      %tky = VALUE #( OperationUUID = operation_uuid )
      %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-error text = text ) )
      TO reported-operationallocation.
  ENDMETHOD.

  " Chuyển lỗi từ bound action ra kết quả của static facade action.
  METHOD forward_action_failure.
    DATA(message_forwarded) = abap_false.

    "Map instance errors to the current static action request.
    "Do not copy the inner %tky into the outer response.
    LOOP AT action_reported-operationallocation ASSIGNING FIELD-SYMBOL(<message>).
      IF <message>-%tky-OperationUUID IS NOT INITIAL
         AND <message>-%tky-OperationUUID <> operation_uuid.
        CONTINUE.
      ENDIF.
      IF <message>-%msg IS NOT BOUND.
        CONTINUE.
      ENDIF.
      IF <message>-%msg->m_severity <> if_abap_behv_message=>severity-error.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( %cid = cid %msg = <message>-%msg )
        TO reported-operationallocation.
      message_forwarded = abap_true.
    ENDLOOP.

    IF message_forwarded = abap_true.
      APPEND VALUE #( %cid = cid ) TO failed-operationallocation.
    ELSE.
      report_failure(
        EXPORTING cid = cid text = 'BUSINESS_VALIDATION_FAILED'
        CHANGING failed = failed reported = reported ).
    ENDIF.
  ENDMETHOD.

  " Đưa lỗi của static action vào failed và reported theo CID tương ứng.
  METHOD report_failure.
    APPEND VALUE #( %cid = cid ) TO failed-operationallocation.
    APPEND VALUE #( %cid = cid
      %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-error text = text ) )
      TO reported-operationallocation.
  ENDMETHOD.

  " Xác thực token, đọc lịch sử theo quyền, ca, lệnh sản xuất và công đoạn rồi trả kết quả.
  METHOD getWorkHistory.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.
    IF lines( keys ) > 1.
      LOOP AT keys ASSIGNING FIELD-SYMBOL(<history_key>).
        report_failure( EXPORTING cid = CONV string( <history_key>-%cid )
                          text = 'Mỗi yêu cầu chỉ được tra cứu một lần'
                        CHANGING failed = failed reported = reported ).
      ENDLOOP.
      RETURN.
    ENDIF.
    DATA(input) = VALUE #( keys[ 1 ]-%param OPTIONAL ).
    DATA(cid) = CONV string( keys[ 1 ]-%cid ).
    TRY.
        DATA(history) = zcl_pp_work_history=>read(
          access_token = CONV string( input-AccessToken ) device_id = input-DeviceID
          range_code = input-RangeCode date_from = input-DateFrom date_to = input-DateTo
          worker_id = input-WorkerID
          production_order = input-ProductionOrder operation_no = input-Operation
          shift_id = input-ShiftID work_id = input-WorkID
          include_entries = xsdbool( input-SummaryOnly = abap_false ) ).
      CATCH cx_abap_message_digest zcx_mob_config INTO DATA(error).
        report_failure( EXPORTING cid = cid text = error->get_text( )
                        CHANGING failed = failed reported = reported ).
        RETURN.
    ENDTRY.
    IF history-is_valid = abap_false.
      report_failure( EXPORTING cid = cid text = |Không tra cứu được: { history-error_code }|
                      CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    result = VALUE #( ( %cid = cid %param = VALUE #(
      ScopeCode = history-scope_code DateFrom = history-date_from DateTo = history-date_to
      WorkerCount = history-worker_count EntryCount = history-entry_count
      IsTruncated = history-is_truncated
      _Workers = VALUE #( FOR summary IN history-workers
        ( WorkerID = summary-worker_id WorkerName = summary-worker_name
          WorkID = summary-work_id
          WorkName = summary-work_name
          BoPhan = summary-bo_phan
          Location = summary-location
          AssignedQuantity = summary-assigned
          TransferredInQuantity = summary-transferred_in
          TransferredOutQuantity = summary-transferred_out
          RecalledQuantity = summary-recalled
          CompletedQuantity = summary-completed
          RemainingQuantity = summary-remaining UnitOfMeasure = summary-uom
          TransactionCount = summary-txn_count ) )
      _Entries = VALUE #( FOR entry IN history-entries
        ( TransactionUUID = entry-transaction_uuid ExecutionDate = entry-execution_date
          ShiftID = entry-shift_id
          OriginalTransactionUUID = entry-original_transaction_uuid
          WorkDate = entry-work_date
          ExecutedAt = entry-executed_at
          ShiftStartAt = entry-shift_start_at
          ShiftEndAt = entry-shift_end_at
          ShiftTimeZone = entry-shift_time_zone
          ShiftValidFrom = entry-shift_valid_from
          WorkerID = entry-worker_id WorkerName = entry-worker_name
          ProductionOrder = entry-production_order Operation = entry-operation_no
          OperationName = entry-operation_name
          SalesOrder = alpha_out_no_gaps( entry-sales_order )
          SalesOrderItem = alpha_out_no_gaps( entry-sales_order_item )
          Product = alpha_out_no_gaps( entry-product ) ProductName = entry-product_name
          Plant = entry-plant WorkCenter = entry-work_center WorkID = entry-work_id
          TransactionType = entry-transaction_type Quantity = entry-quantity
          UnitOfMeasure = entry-uom TransactionStatus = entry-transaction_status ) ) ) ) ).
  ENDMETHOD.

  " Pre-check lúc quét QR: xác thực quyền quản lý và trả snapshot sản lượng.
  " Snapshot đọc từ ZTB_PP_EMP_ALLOC; action giao việc vẫn kiểm tra lại khi commit.
  METHOD checkOperationAccess.
    DATA initial_assigned TYPE ztb_pp_emp_alloc-initial_assigned_qty.
    DATA transferred_in TYPE ztb_pp_emp_alloc-transferred_in_qty.
    DATA transferred_out TYPE ztb_pp_emp_alloc-transferred_out_qty.
    DATA recalled TYPE ztb_pp_emp_alloc-recalled_qty.
    DATA completed TYPE ztb_pp_emp_alloc-completed_qty.
    DATA remaining TYPE ztb_pp_emp_alloc-remaining_qty.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      DATA(input) = <key>-%param.
      DATA(cid) = CONV string( <key>-%cid ).
      CLEAR: initial_assigned, transferred_in, transferred_out,
             recalled, completed, remaining.

      TRY.
          DATA(auth) = zcl_mob_token_validator=>validate_token(
            token = CONV string( input-AccessToken )
            device_id = input-DeviceID ).
        CATCH cx_abap_message_digest zcx_mob_config.
          report_failure( EXPORTING cid = cid text = 'AUTH_FAILED'
                          CHANGING failed = failed reported = reported ).
          CONTINUE.
      ENDTRY.
      IF auth-is_valid = abap_false.
        report_failure( EXPORTING cid = cid text = CONV string( auth-error_code )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

      IF input-ProductionOrder IS INITIAL
         OR input-Operation IS INITIAL
         OR input-WorkID IS INITIAL
         OR input-ShiftID IS INITIAL.
        report_failure( EXPORTING cid = cid text = 'OPERATION_ACCESS_INPUT_REQUIRED'
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

      DATA(live) = zcl_pp_operation_guard=>resolve(
        production_order = input-ProductionOrder
        operation_no = input-Operation ).
      IF live-is_valid = abap_false.
        report_failure( EXPORTING cid = cid text = CONV string( live-error_code )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

      DATA(executed_at) = COND utclong(
        WHEN input-ExecutedAt IS INITIAL THEN utclong_current( )
        ELSE input-ExecutedAt ).
      DATA(shift) = zcl_pp_shift_resolver=>resolve(
        plant = live-plant
        shift_id = input-ShiftID
        executed_at = executed_at
        execution_date = VALUE #( ) ).
      IF shift-is_valid = abap_false.
        report_failure( EXPORTING cid = cid text = CONV string( shift-error_code )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

      IF zcl_mob_token_validator=>has_func_op_scope(
           user_uuid = auth-user_uuid
           func_id = func_initial_assign
           plant = live-plant
           work_center = live-work_center
           work_id = input-WorkID
           ma_congdoan = live-ma_congdoan
           effective_date = shift-work_date ) = abap_false.
        report_failure( EXPORTING cid = cid text = 'MANAGER_OPERATION_NOT_ALLOWED'
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

      DATA(work_operation_context) = check_work_operation_context(
        work_id = input-WorkID
        plant = live-plant
        work_center = live-work_center
        ma_congdoan = live-ma_congdoan
        effective_date = shift-work_date ).
      IF work_operation_context-is_valid = abap_false.
        report_failure( EXPORTING cid = cid
                          text = CONV string( work_operation_context-error_code )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

      SELECT FROM ztb_pp_op_alloc
        FIELDS operation_uuid
        WHERE production_order = @input-ProductionOrder
          AND operation_no = @input-Operation
        INTO TABLE @DATA(snapshots)
        UP TO 2 ROWS.
      IF lines( snapshots ) > 1.
        report_failure( EXPORTING cid = cid text = 'OPERATION_SNAPSHOT_DUPLICATE'
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

      DATA(operation_uuid) = VALUE sysuuid_x16( snapshots[ 1 ]-operation_uuid OPTIONAL ).

      IF operation_uuid IS NOT INITIAL.
        SELECT FROM ztb_pp_emp_alloc
          FIELDS SUM( initial_assigned_qty ) AS initial_assigned,
                 SUM( transferred_in_qty ) AS transferred_in,
                 SUM( transferred_out_qty ) AS transferred_out,
                 SUM( recalled_qty ) AS recalled,
                 SUM( completed_qty ) AS completed,
                 SUM( remaining_qty ) AS remaining
          WHERE operation_uuid = @operation_uuid
            AND uom = @live-uom
          INTO @DATA(totals).
        initial_assigned = totals-initial_assigned.
        transferred_in = totals-transferred_in.
        transferred_out = totals-transferred_out.
        recalled = totals-recalled.
        completed = totals-completed.
        remaining = totals-remaining.
      ENDIF.

      DATA(current_assigned) = remaining + completed.
      DATA(unassigned) = live-operation_qty - current_assigned.
      result = VALUE #( BASE result ( %cid = cid %param = VALUE #(
        IsAllowed = abap_true
        Message = 'Có quyền thao tác'
        ProductionOrder = live-production_order
        Operation = live-operation_no
        MaCongDoan = live-ma_congdoan
        Plant = live-plant
        WorkCenter = live-work_center
        WorkID = input-WorkID
        WorkName = work_operation_context-work_name
        WorkBoPhan = work_operation_context-work_bo_phan
        Location = work_operation_context-location
        OperationName = work_operation_context-operation_name
        OperationBoPhan = work_operation_context-operation_bo_phan
        OperationQuantity = live-operation_qty
        InitialAssignedQuantity = initial_assigned
        TransferredInQuantity = transferred_in
        TransferredOutQuantity = transferred_out
        RecalledQuantity = recalled
        CompletedQuantity = completed
        RemainingQuantity = remaining
        CurrentAssignedQuantity = current_assigned
        UnassignedQuantity = unassigned
        UnitOfMeasure = live-uom
        ShiftID = shift-shift_id
        WorkDate = shift-work_date
        ExecutedAt = shift-executed_at ) ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD alpha_out_no_gaps.
    rv_value = |{ iv_value ALPHA = OUT }|.
    CONDENSE rv_value NO-GAPS.
  ENDMETHOD.



ENDCLASS.

