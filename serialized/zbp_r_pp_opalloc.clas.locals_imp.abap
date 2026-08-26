CLASS lhc_operationallocation DEFINITION
  INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.
    TYPES reported_response TYPE RESPONSE FOR REPORTED zr_pp_opalloc.
    TYPES failed_response TYPE RESPONSE FOR FAILED zr_pp_opalloc.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR OperationAllocation
      RESULT result.

    METHODS validateOperation FOR VALIDATE ON SAVE
      IMPORTING keys FOR OperationAllocation~validateOperation.

    METHODS initialAssign FOR MODIFY
      IMPORTING keys FOR ACTION OperationAllocation~initialAssign
      RESULT result.

    METHODS transfer FOR MODIFY
      IMPORTING keys FOR ACTION OperationAllocation~transfer
      RESULT result.

    METHODS recall FOR MODIFY
      IMPORTING keys FOR ACTION OperationAllocation~recall
      RESULT result.

    METHODS confirm FOR MODIFY
      IMPORTING keys FOR ACTION OperationAllocation~confirm
      RESULT result.

    METHODS reverse FOR MODIFY
      IMPORTING keys FOR ACTION OperationAllocation~reverse
      RESULT result.

    METHODS getWorkHistory FOR MODIFY
      IMPORTING keys FOR ACTION OperationAllocation~getWorkHistory
      RESULT result.

    METHODS report_failure
      IMPORTING cid TYPE string text TYPE string
      CHANGING failed TYPE failed_response reported TYPE reported_response.
ENDCLASS.

CLASS lhc_employeeallocation DEFINITION
  INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS validateBalance FOR VALIDATE ON SAVE
      IMPORTING keys FOR EmployeeAllocation~validateBalance.
ENDCLASS.

CLASS lhc_employeeallocation IMPLEMENTATION.
  METHOD validateBalance.
    READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
      ENTITY EmployeeAllocation
      FIELDS ( InitialAssignedQuantity TransferredInQuantity
               TransferredOutQuantity RecalledQuantity CompletedQuantity
               RemainingQuantity )
      WITH CORRESPONDING #( keys )
      RESULT DATA(allocations).

    LOOP AT allocations ASSIGNING FIELD-SYMBOL(<allocation>).
      DATA(expected_remaining) =
        <allocation>-InitialAssignedQuantity
        + <allocation>-TransferredInQuantity
        - <allocation>-TransferredOutQuantity
        - <allocation>-RecalledQuantity
        - <allocation>-CompletedQuantity.
      IF expected_remaining < 0
         OR <allocation>-RemainingQuantity <> expected_remaining.
        APPEND VALUE #( %tky = <allocation>-%tky )
          TO failed-employeeallocation.
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
  METHOD get_global_authorizations.
    "Domain mutations are internal until submitSync validates the mobile token.
    result-%create = if_abap_behv=>auth-unauthorized.
    result-%update = if_abap_behv=>auth-unauthorized.
    result-%action-initialAssign = if_abap_behv=>auth-unauthorized.
    result-%action-transfer = if_abap_behv=>auth-unauthorized.
    result-%action-recall = if_abap_behv=>auth-unauthorized.
    result-%action-confirm = if_abap_behv=>auth-unauthorized.
    result-%action-reverse = if_abap_behv=>auth-unauthorized.
    "The history query mutates nothing and does its own token check.
    result-%action-getWorkHistory = if_abap_behv=>auth-allowed.
  ENDMETHOD.

  METHOD validateOperation.
    READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
      ENTITY OperationAllocation
      FIELDS ( OperationQuantity UnitOfMeasure Plant WorkCenter )
      WITH CORRESPONDING #( keys )
      RESULT DATA(operations).

    LOOP AT operations ASSIGNING FIELD-SYMBOL(<operation>).
      IF <operation>-OperationQuantity <= 0.
        APPEND VALUE #( %tky = <operation>-%tky )
          TO failed-operationallocation.
        APPEND VALUE #(
          %tky = <operation>-%tky
          %element-OperationQuantity = if_abap_behv=>mk-on
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Operation quantity must be greater than zero' ) )
          TO reported-operationallocation.
      ENDIF.

      IF <operation>-UnitOfMeasure IS INITIAL
         OR <operation>-Plant IS INITIAL
         OR <operation>-WorkCenter IS INITIAL.
        APPEND VALUE #( %tky = <operation>-%tky )
          TO failed-operationallocation.
        APPEND VALUE #(
          %tky = <operation>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Plant, work center and unit are mandatory' ) )
          TO reported-operationallocation.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD initialAssign.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      DATA(input) = <key>-%param.
      DATA(cid) = CONV string( <key>-%cid ).
      TRY.
          DATA(auth) = zcl_mob_token_validator=>validate_token(
            token = CONV string( input-AccessToken )
            device_id = input-DeviceID
            required_func = 'PP_INITIAL_ASSIGN' ).
        CATCH cx_abap_message_digest zcx_mob_config.
          report_failure( EXPORTING cid = cid text = 'Không thể xác thực yêu cầu'
                          CHANGING failed = failed reported = reported ).
          CONTINUE.
      ENDTRY.
      IF auth-is_valid = abap_false.
        report_failure( EXPORTING cid = cid text = CONV string( auth-error_code )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY OperationAllocation ALL FIELDS
        WITH VALUE #( ( %tky = <key>-%tky ) ) RESULT DATA(operations).
      IF operations IS INITIAL OR input-Quantity <= 0
         OR input-ToWorkerID IS INITIAL
         OR input-SyncItemUUID IS INITIAL OR input-ExecutionDate IS INITIAL.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-operationallocation.
        APPEND VALUE #( %tky = <key>-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Thiếu dữ liệu giao việc bắt buộc' ) )
          TO reported-operationallocation.
        CONTINUE.
      ENDIF.
      DATA(operation) = operations[ 1 ].
      IF input-UnitOfMeasure <> operation-UnitOfMeasure
         OR zcl_pp_worker_validator=>is_worker_active(
           worker_id = input-ToWorkerID plant = operation-Plant
           work_center = operation-WorkCenter
           execution_date = input-ExecutionDate ) = abap_false.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-operationallocation.
        APPEND VALUE #( %tky = <key>-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Nhân công không hợp lệ tại ngày, nhà máy hoặc tổ đã chọn' ) )
          TO reported-operationallocation.
        CONTINUE.
      ENDIF.
      TRY.
          DATA(worker_auth) = zcl_mob_token_validator=>verify_worker_password(
            worker_id = input-ToWorkerID
            password = CONV string( input-WorkerPassword ) ).
        CATCH cx_abap_message_digest zcx_mob_config INTO DATA(auth_error).
          APPEND VALUE #( %tky = <key>-%tky ) TO failed-operationallocation.
          APPEND VALUE #( %tky = <key>-%tky %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = auth_error->get_text( ) ) ) TO reported-operationallocation.
          CONTINUE.
      ENDTRY.
      IF worker_auth-is_valid = abap_false.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-operationallocation.
        APPEND VALUE #( %tky = <key>-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = |Xác minh nhân công thất bại: { worker_auth-error_code }| ) )
          TO reported-operationallocation.
        CONTINUE.
      ENDIF.
      SELECT SINGLE transaction_uuid FROM ztb_pp_alloc_txn
        WHERE sync_item_uuid = @input-SyncItemUUID
        INTO @DATA(existing_txn).
      IF existing_txn IS NOT INITIAL.
        APPEND VALUE #( %tky = operation-%tky %param = operation ) TO result.
        CONTINUE.
      ENDIF.
      SELECT FROM ztb_pp_emp_alloc
        FIELDS SUM( initial_assigned_qty ) AS assigned
        WHERE operation_uuid = @operation-OperationUUID
        INTO @DATA(operation_balance).
      IF operation_balance-assigned + input-Quantity
         > operation-OperationQuantity.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-operationallocation.
        APPEND VALUE #( %tky = <key>-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Tổng số lượng giao vượt số lượng công đoạn' ) )
          TO reported-operationallocation.
        CONTINUE.
      ENDIF.
      SELECT SINGLE FROM ztb_pp_emp_alloc
        FIELDS emp_alloc_uuid, initial_assigned_qty, remaining_qty
        WHERE operation_uuid = @operation-OperationUUID
          AND worker_id = @input-ToWorkerID
        INTO @DATA(balance).
      IF balance IS INITIAL.
        MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE
          ENTITY OperationAllocation CREATE BY \_Employees FIELDS
            ( WorkerID InitialAssignedQuantity RemainingQuantity
              UnitOfMeasure LastExecutionDate )
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
          WITH VALUE #( ( EmployeeAllocationUUID = balance-emp_alloc_uuid
            InitialAssignedQuantity = balance-initial_assigned_qty + input-Quantity
            RemainingQuantity = balance-remaining_qty + input-Quantity
            LastExecutionDate = input-ExecutionDate ) ).
      ENDIF.
      MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY OperationAllocation CREATE BY \_Transactions FIELDS
          ( SyncItemUUID ActorUserUUID TransactionType WorkerID ToWorkerID
            Quantity UnitOfMeasure ExecutionDate TransactionStatus )
        WITH VALUE #( ( %tky = operation-%tky %target = VALUE #(
          ( %cid = |TXN{ sy-tabix }| SyncItemUUID = input-SyncItemUUID
            ActorUserUUID = auth-user_uuid
            TransactionType = zcl_pp_txn_type=>initial_assign
            WorkerID = input-ToWorkerID ToWorkerID = input-ToWorkerID
            Quantity = input-Quantity UnitOfMeasure = input-UnitOfMeasure
            ExecutionDate = input-ExecutionDate
            TransactionStatus = zcl_pp_txn_type=>posted ) ) ) ).
      APPEND VALUE #( %tky = operation-%tky %param = operation ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD transfer.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      DATA(input) = <key>-%param.
      DATA(cid) = CONV string( <key>-%cid ).
      TRY.
          DATA(auth) = zcl_mob_token_validator=>validate_token(
            token = CONV string( input-AccessToken )
            device_id = input-DeviceID ).
        CATCH cx_abap_message_digest zcx_mob_config.
          report_failure( EXPORTING cid = cid text = 'Không thể xác thực yêu cầu điều chuyển'
                          CHANGING failed = failed reported = reported ).
          CONTINUE.
      ENDTRY.
      IF auth-is_valid = abap_false.
        report_failure( EXPORTING cid = cid text = CONV string( auth-error_code )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY OperationAllocation ALL FIELDS
        WITH VALUE #( ( %tky = <key>-%tky ) ) RESULT DATA(operations).
      IF operations IS INITIAL OR input-Quantity <= 0
         OR input-FromWorkerID IS INITIAL OR input-ToWorkerID IS INITIAL
         OR input-FromWorkerID = input-ToWorkerID
         OR input-SyncItemUUID IS INITIAL
         OR input-ExecutionDate IS INITIAL.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-operationallocation.
        APPEND VALUE #( %tky = <key>-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Thiếu hoặc sai dữ liệu điều chuyển' ) )
          TO reported-operationallocation.
        CONTINUE.
      ENDIF.
      DATA(operation) = operations[ 1 ].
      TRY.
          DATA(worker_auth) = zcl_mob_token_validator=>verify_worker_password(
            worker_id = input-ToWorkerID
            password = CONV string( input-WorkerPassword ) ).
        CATCH cx_abap_message_digest zcx_mob_config INTO DATA(auth_error).
          APPEND VALUE #( %tky = <key>-%tky ) TO failed-operationallocation.
          APPEND VALUE #( %tky = <key>-%tky %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = auth_error->get_text( ) ) ) TO reported-operationallocation.
          CONTINUE.
      ENDTRY.
      IF worker_auth-is_valid = abap_false
         OR input-UnitOfMeasure <> operation-UnitOfMeasure
         OR zcl_pp_worker_validator=>is_worker_active(
           worker_id = input-ToWorkerID plant = operation-Plant
           work_center = operation-WorkCenter
           execution_date = input-ExecutionDate ) = abap_false.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-operationallocation.
        APPEND VALUE #( %tky = <key>-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Nhân công nhận việc hoặc mật khẩu không hợp lệ' ) )
          TO reported-operationallocation.
        CONTINUE.
      ENDIF.
      SELECT SINGLE transaction_uuid FROM ztb_pp_alloc_txn
        WHERE sync_item_uuid = @input-SyncItemUUID INTO @DATA(existing_txn).
      IF existing_txn IS NOT INITIAL.
        APPEND VALUE #( %tky = operation-%tky %param = operation ) TO result.
        CONTINUE.
      ENDIF.
      SELECT FROM ztb_pp_emp_alloc
        FIELDS emp_alloc_uuid, worker_id, transferred_in_qty,
               transferred_out_qty, remaining_qty, uom
        WHERE operation_uuid = @operation-OperationUUID
          AND worker_id IN ( @input-FromWorkerID, @input-ToWorkerID )
        INTO TABLE @DATA(balances).
      DATA(source) = VALUE #( balances[ worker_id = input-FromWorkerID ] OPTIONAL ).
      DATA(target) = VALUE #( balances[ worker_id = input-ToWorkerID ] OPTIONAL ).
      IF source IS INITIAL OR source-uom <> input-UnitOfMeasure
         OR source-remaining_qty < input-Quantity.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-operationallocation.
        APPEND VALUE #( %tky = <key>-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Số dư nhân công nguồn không đủ để điều chuyển' ) )
          TO reported-operationallocation.
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY EmployeeAllocation UPDATE FIELDS
          ( TransferredOutQuantity RemainingQuantity LastExecutionDate )
        WITH VALUE #( ( EmployeeAllocationUUID = source-emp_alloc_uuid
          TransferredOutQuantity = source-transferred_out_qty + input-Quantity
          RemainingQuantity = source-remaining_qty - input-Quantity
          LastExecutionDate = input-ExecutionDate ) ).
      IF target IS INITIAL.
        MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE
          ENTITY OperationAllocation CREATE BY \_Employees FIELDS
            ( WorkerID TransferredInQuantity RemainingQuantity UnitOfMeasure
              LastExecutionDate )
          WITH VALUE #( ( %tky = operation-%tky %target = VALUE #(
            ( %cid = |TRG{ sy-tabix }| WorkerID = input-ToWorkerID
              TransferredInQuantity = input-Quantity
              RemainingQuantity = input-Quantity UnitOfMeasure = input-UnitOfMeasure
              LastExecutionDate = input-ExecutionDate ) ) ) ).
      ELSE.
        MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE
          ENTITY EmployeeAllocation UPDATE FIELDS
            ( TransferredInQuantity RemainingQuantity LastExecutionDate )
          WITH VALUE #( ( EmployeeAllocationUUID = target-emp_alloc_uuid
            TransferredInQuantity = target-transferred_in_qty + input-Quantity
            RemainingQuantity = target-remaining_qty + input-Quantity
            LastExecutionDate = input-ExecutionDate ) ).
      ENDIF.
      MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY OperationAllocation CREATE BY \_Transactions FIELDS
          ( SyncItemUUID ActorUserUUID TransactionType FromWorkerID ToWorkerID
            Quantity UnitOfMeasure ExecutionDate TransactionStatus )
        WITH VALUE #( ( %tky = operation-%tky %target = VALUE #(
          ( %cid = |TRN{ sy-tabix }| SyncItemUUID = input-SyncItemUUID
            ActorUserUUID = auth-user_uuid
            TransactionType = zcl_pp_txn_type=>transfer
            FromWorkerID = input-FromWorkerID ToWorkerID = input-ToWorkerID
            Quantity = input-Quantity UnitOfMeasure = input-UnitOfMeasure
            ExecutionDate = input-ExecutionDate
            TransactionStatus = zcl_pp_txn_type=>posted ) ) ) ).
      APPEND VALUE #( %tky = operation-%tky %param = operation ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD recall.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      DATA(input) = <key>-%param.
      DATA(cid) = CONV string( <key>-%cid ).
      TRY.
          DATA(auth) = zcl_mob_token_validator=>validate_token(
            token = CONV string( input-AccessToken )
            device_id = input-DeviceID ).
        CATCH cx_abap_message_digest zcx_mob_config.
          report_failure( EXPORTING cid = cid text = 'Không thể xác thực yêu cầu thu hồi'
                          CHANGING failed = failed reported = reported ).
          CONTINUE.
      ENDTRY.
      IF auth-is_valid = abap_false.
        report_failure( EXPORTING cid = cid text = CONV string( auth-error_code )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.
      READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY OperationAllocation ALL FIELDS
        WITH VALUE #( ( %tky = <key>-%tky ) ) RESULT DATA(operations).
      IF operations IS INITIAL OR input-Quantity <= 0
         OR input-WorkerID IS INITIAL
         OR input-SyncItemUUID IS INITIAL
         OR input-OriginalTransactionUUID IS INITIAL
         OR input-ExecutionDate IS INITIAL.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-operationallocation.
        APPEND VALUE #( %tky = <key>-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Thiếu dữ liệu thu hồi bắt buộc' ) )
          TO reported-operationallocation.
        CONTINUE.
      ENDIF.
      DATA(operation) = operations[ 1 ].
      TRY.
          DATA(worker_auth) = zcl_mob_token_validator=>verify_worker_password(
            worker_id = input-WorkerID
            password = CONV string( input-WorkerPassword ) ).
        CATCH cx_abap_message_digest zcx_mob_config INTO DATA(auth_error).
          APPEND VALUE #( %tky = <key>-%tky ) TO failed-operationallocation.
          APPEND VALUE #( %tky = <key>-%tky %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = auth_error->get_text( ) ) ) TO reported-operationallocation.
          CONTINUE.
      ENDTRY.
      IF worker_auth-is_valid = abap_false.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-operationallocation.
        APPEND VALUE #( %tky = <key>-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = |Xác minh nhân công thất bại: { worker_auth-error_code }| ) )
          TO reported-operationallocation.
        CONTINUE.
      ENDIF.
      SELECT SINGLE transaction_uuid FROM ztb_pp_alloc_txn
        WHERE sync_item_uuid = @input-SyncItemUUID INTO @DATA(existing_txn).
      IF existing_txn IS NOT INITIAL.
        APPEND VALUE #( %tky = operation-%tky %param = operation ) TO result.
        CONTINUE.
      ENDIF.
      SELECT SINGLE FROM ztb_pp_alloc_txn
        FIELDS transaction_type
        WHERE transaction_uuid = @input-OriginalTransactionUUID
          AND operation_uuid = @operation-OperationUUID
          AND transaction_status = @zcl_pp_txn_type=>posted
        INTO @DATA(root_type).
      SELECT SINGLE FROM ztb_pp_emp_alloc
        FIELDS emp_alloc_uuid, recalled_qty, remaining_qty, uom
        WHERE operation_uuid = @operation-OperationUUID
          AND worker_id = @input-WorkerID INTO @DATA(balance).
      IF ( root_type <> zcl_pp_txn_type=>initial_assign
           AND root_type <> zcl_pp_txn_type=>transfer )
         OR balance IS INITIAL OR balance-uom <> input-UnitOfMeasure
         OR balance-remaining_qty < input-Quantity.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-operationallocation.
        APPEND VALUE #( %tky = <key>-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Thu hồi vượt số dư hoặc không thuộc giao dịch giao việc' ) )
          TO reported-operationallocation.
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zr_pp_opalloc IN LOCAL MODE
        ENTITY EmployeeAllocation UPDATE FIELDS
          ( RecalledQuantity RemainingQuantity LastExecutionDate )
        WITH VALUE #( ( EmployeeAllocationUUID = balance-emp_alloc_uuid
          RecalledQuantity = balance-recalled_qty + input-Quantity
          RemainingQuantity = balance-remaining_qty - input-Quantity
          LastExecutionDate = input-ExecutionDate ) )
        ENTITY OperationAllocation CREATE BY \_Transactions FIELDS
          ( OriginalTransactionUUID SyncItemUUID ActorUserUUID
            TransactionType WorkerID FromWorkerID Quantity UnitOfMeasure
            ExecutionDate TransactionStatus )
        WITH VALUE #( ( %tky = operation-%tky %target = VALUE #(
          ( %cid = |RCL{ sy-tabix }|
            OriginalTransactionUUID = input-OriginalTransactionUUID
            SyncItemUUID = input-SyncItemUUID
            ActorUserUUID = auth-user_uuid
            TransactionType = zcl_pp_txn_type=>recall
            WorkerID = input-WorkerID FromWorkerID = input-WorkerID
            Quantity = input-Quantity UnitOfMeasure = input-UnitOfMeasure
            ExecutionDate = input-ExecutionDate
            TransactionStatus = zcl_pp_txn_type=>posted ) ) ) ).
      APPEND VALUE #( %tky = operation-%tky %param = operation ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD confirm.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      APPEND VALUE #( %tky = <key>-%tky )
        TO failed-operationallocation.
      APPEND VALUE #(
        %tky = <key>-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'SAP production confirmation adapter is not configured' ) )
        TO reported-operationallocation.
    ENDLOOP.
  ENDMETHOD.

  METHOD reverse.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      APPEND VALUE #( %tky = <key>-%tky )
        TO failed-operationallocation.
      APPEND VALUE #(
        %tky = <key>-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'REVERSE implementation is not activated yet' ) )
        TO reported-operationallocation.
    ENDLOOP.
  ENDMETHOD.

  METHOD report_failure.
    APPEND VALUE #( %cid = cid ) TO failed-operationallocation.
    APPEND VALUE #( %cid = cid
      %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-error
        text = text ) ) TO reported-operationallocation.
  ENDMETHOD.

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
          access_token = CONV string( input-AccessToken )
          device_id = input-DeviceID
          range_code = input-RangeCode
          date_from = input-DateFrom
          date_to = input-DateTo
          worker_id = input-WorkerID
          include_entries = xsdbool( input-SummaryOnly = abap_false ) ).
      CATCH cx_abap_message_digest zcx_mob_config INTO DATA(error).
        report_failure( EXPORTING cid = cid text = error->get_text( )
                        CHANGING failed = failed reported = reported ).
        RETURN.
    ENDTRY.
    IF history-is_valid = abap_false.
      report_failure( EXPORTING cid = cid
                        text = |Không tra cứu được: { history-error_code }|
                      CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    result = VALUE #( ( %cid = cid %param = VALUE #(
      ScopeCode = history-scope_code
      DateFrom = history-date_from
      DateTo = history-date_to
      WorkerCount = history-worker_count
      EntryCount = history-entry_count
      IsTruncated = history-is_truncated
      _Workers = VALUE #( FOR summary IN history-workers
        ( WorkerID = summary-worker_id
          WorkerName = summary-worker_name
          AssignedQuantity = summary-assigned
          CompletedQuantity = summary-completed
          RemainingQuantity = summary-remaining
          UnitOfMeasure = summary-uom
          TransactionCount = summary-txn_count ) )
      _Entries = VALUE #( FOR entry IN history-entries
        ( TransactionUUID = entry-transaction_uuid
          ExecutionDate = entry-execution_date
          WorkerID = entry-worker_id
          WorkerName = entry-worker_name
          ProductionOrder = entry-production_order
          Operation = entry-operation_no
          Plant = entry-plant
          WorkCenter = entry-work_center
          TransactionType = entry-transaction_type
          Quantity = entry-quantity
          UnitOfMeasure = entry-uom
          TransactionStatus = entry-transaction_status ) ) ) ) ).
  ENDMETHOD.
ENDCLASS.
