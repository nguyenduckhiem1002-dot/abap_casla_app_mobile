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
               TransferredOutQuantity CompletedQuantity RemainingQuantity )
      WITH CORRESPONDING #( keys )
      RESULT DATA(allocations).

    LOOP AT allocations ASSIGNING FIELD-SYMBOL(<allocation>).
      DATA(expected_remaining) =
        <allocation>-InitialAssignedQuantity
        + <allocation>-TransferredInQuantity
        - <allocation>-TransferredOutQuantity
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
      DATA(input) = VALUE #( <key>-%param OPTIONAL ).
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

      TRY.
          DATA(worker_auth) = zcl_mob_token_validator=>verify_worker_password(
            worker_id = input-ToWorkerID
            password = CONV string( input-WorkerPassword ) ).
        CATCH cx_abap_message_digest zcx_mob_config.
          report_failure( EXPORTING cid = cid text = 'Không thể xác thực nhân công'
                          CHANGING failed = failed reported = reported ).
          CONTINUE.
      ENDTRY.
      IF worker_auth-is_valid = abap_false.
        report_failure( EXPORTING cid = cid text = CONV string( worker_auth-error_code )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = <key>-%tky )
        TO failed-operationallocation.
      APPEND VALUE #(
        %tky = <key>-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'INITIAL_ASSIGNMENT implementation is not activated yet' ) )
        TO reported-operationallocation.
    ENDLOOP.
  ENDMETHOD.

  METHOD transfer.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      APPEND VALUE #( %tky = <key>-%tky )
        TO failed-operationallocation.
      APPEND VALUE #(
        %tky = <key>-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'TRANSFER implementation is not activated yet' ) )
        TO reported-operationallocation.
    ENDLOOP.
  ENDMETHOD.

  METHOD confirm.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      DATA(input) = VALUE #( <key>-%param OPTIONAL ).
      DATA(cid) = CONV string( <key>-%cid ).
      
      TRY.
          DATA(auth) = zcl_mob_token_validator=>validate_token(
            token = CONV string( input-AccessToken )
            device_id = input-DeviceID
            required_func = 'PP_CONFIRM' ).
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

      TRY.
          DATA(worker_auth) = zcl_mob_token_validator=>verify_worker_password(
            worker_id = input-WorkerID
            password = CONV string( input-WorkerPassword ) ).
        CATCH cx_abap_message_digest zcx_mob_config.
          report_failure( EXPORTING cid = cid text = 'Không thể xác thực nhân công'
                          CHANGING failed = failed reported = reported ).
          CONTINUE.
      ENDTRY.
      IF worker_auth-is_valid = abap_false.
        report_failure( EXPORTING cid = cid text = CONV string( worker_auth-error_code )
                        CHANGING failed = failed reported = reported ).
        CONTINUE.
      ENDIF.

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
      CATCH cx_abap_message_digest zcx_mob_config.
        report_failure( EXPORTING cid = cid text = 'Không thể xác thực yêu cầu tra cứu'
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
