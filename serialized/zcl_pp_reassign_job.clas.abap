CLASS zcl_pp_reassign_job DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_apj_rt_run.
    TYPES ledger_rows TYPE STANDARD TABLE OF ztb_pp_alloc_txn WITH EMPTY KEY.
    TYPES: BEGIN OF calculation,
             entries TYPE ledger_rows,
             error_code TYPE c LENGTH 40,
           END OF calculation.
    CLASS-METHODS run
      IMPORTING target_date TYPE d OPTIONAL
      RAISING cx_apj_rt_content.
    CLASS-METHODS calculate
      IMPORTING rows TYPE ledger_rows target_date TYPE d
      RETURNING VALUE(result) TYPE calculation.
  PRIVATE SECTION.
    TYPES ledger_index TYPE HASHED TABLE OF ztb_pp_alloc_txn WITH UNIQUE KEY transaction_uuid.
    TYPES: BEGIN OF bucket,
             root_id TYPE sysuuid_x16,
             source TYPE ztb_pp_alloc_txn,
             quantity TYPE ztb_pp_alloc_txn-quantity,
             posted TYPE ztb_pp_alloc_txn-quantity,
           END OF bucket,
           buckets TYPE STANDARD TABLE OF bucket WITH EMPTY KEY.
    TYPES: BEGIN OF debit,
             worker_id TYPE ztb_pp_alloc_txn-worker_id,
             uom TYPE ztb_pp_alloc_txn-uom,
             quantity TYPE ztb_pp_alloc_txn-quantity,
           END OF debit,
           debits TYPE SORTED TABLE OF debit WITH UNIQUE KEY worker_id uom.
    CLASS-METHODS business_date
      IMPORTING row TYPE ztb_pp_alloc_txn
      RETURNING VALUE(result) TYPE d.
    CLASS-METHODS root_of
      IMPORTING row TYPE ztb_pp_alloc_txn ledger TYPE ledger_index
      RETURNING VALUE(result) TYPE ztb_pp_alloc_txn.
    CLASS-METHODS collect_day
      IMPORTING ledger TYPE ledger_index target_date TYPE d
      EXPORTING error_code TYPE calculation-error_code
      CHANGING balances TYPE buckets deductions TYPE debits.
    CLASS-METHODS deduct_unlinked
      CHANGING balances TYPE buckets deductions TYPE debits.
ENDCLASS.

CLASS zcl_pp_reassign_job IMPLEMENTATION.
  METHOD if_apj_rt_run~execute.
    run( ).
  ENDMETHOD.

  METHOD run.
    DATA(day) = target_date.
    TRY.
        CONVERT UTCLONG utclong_current( )
          TIME ZONE cl_abap_context_info=>get_user_time_zone( ) INTO DATE DATA(today).
      CATCH cx_parameter_invalid_range cx_sy_conversion_error INTO DATA(date_error).
        RAISE EXCEPTION TYPE cx_apj_rt_content EXPORTING previous = date_error.
    ENDTRY.
    IF day IS INITIAL.
      day = today.
    ENDIF.
    IF day > today OR day <= '00010101'.
      RAISE EXCEPTION TYPE cx_apj_rt_content.
    ENDIF.
    DATA(previous_day) = CONV d( day - 1 ).
    "Only operations with activity yesterday or an existing snapshot to reconcile.
    SELECT DISTINCT operation_uuid FROM ztb_pp_alloc_txn
      WHERE transaction_status = @zcl_pp_txn_type=>posted
        AND ( work_date = @previous_day
           OR ( work_date = '00000000' AND execution_date = @previous_day )
           OR ( transaction_type = @zcl_pp_txn_type=>reassign AND work_date = @day ) )
      INTO TABLE @DATA(operations).
    LOOP AT operations INTO DATA(operation).
      "Bound action acquires the same operation lock as allocation commands.
      MODIFY ENTITIES OF zr_pp_opalloc
        ENTITY OperationAllocation EXECUTE reassignOvernight
        FROM VALUE #( ( OperationUUID = operation-operation_uuid %param-TargetDate = day ) )
        FAILED DATA(failed).
      IF failed IS NOT INITIAL.
        ROLLBACK ENTITIES.
        RAISE EXCEPTION TYPE cx_apj_rt_content.
      ENDIF.
      COMMIT ENTITIES RESPONSE OF zr_pp_opalloc FAILED DATA(commit_failed).
      IF sy-subrc <> 0 OR commit_failed IS NOT INITIAL.
        ROLLBACK ENTITIES.
        RAISE EXCEPTION TYPE cx_apj_rt_content.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD business_date.
    result = COND #( WHEN row-work_date IS NOT INITIAL THEN row-work_date ELSE row-execution_date ).
  ENDMETHOD.

  METHOD root_of.
    result = row.
    "Transfers start a new recipient lineage. REASSIGN is only an opening snapshot.
    "Bound traversal detects missing references and cycles without silently truncating chains.
    DO lines( ledger ) TIMES.
      IF result-original_transaction_uuid IS INITIAL
         OR result-transaction_type = zcl_pp_txn_type=>transfer.
        IF result-transaction_type <> zcl_pp_txn_type=>initial_assign
           AND result-transaction_type <> zcl_pp_txn_type=>transfer
           AND result-transaction_type <> zcl_pp_txn_type=>allocation_adjustment
           AND result-transaction_type <> zcl_pp_txn_type=>recall_adjustment
           AND result-transaction_type <> zcl_pp_txn_type=>confirm_adjustment.
          CLEAR result.
          RETURN.
        ENDIF.
        IF result-worker_id IS INITIAL.
          result-worker_id = result-to_worker_id.
        ENDIF.
        RETURN.
      ENDIF.
      READ TABLE ledger INTO result WITH TABLE KEY transaction_uuid = result-original_transaction_uuid.
      IF sy-subrc <> 0.
        CLEAR result.
        RETURN.
      ENDIF.
    ENDDO.
    CLEAR result.
  ENDMETHOD.

  METHOD collect_day.
    DATA(previous_day) = CONV d( target_date - 1 ).
    LOOP AT ledger INTO DATA(row).
      DATA(day) = business_date( row ).
      IF day <> previous_day AND NOT ( day = target_date
                                      AND row-transaction_type = zcl_pp_txn_type=>reassign ).
        CONTINUE.
      ENDIF.
      DATA(source) = root_of( row = row ledger = ledger ).
      DATA(worker) = COND #( WHEN row-transaction_type = zcl_pp_txn_type=>transfer
                            THEN row-to_worker_id
                            WHEN row-worker_id IS NOT INITIAL THEN row-worker_id ELSE row-to_worker_id ).
      IF source-transaction_uuid IS INITIAL OR source-worker_id IS INITIAL
         OR source-uom <> row-uom OR source-worker_id <> worker
         OR source-operation_uuid <> row-operation_uuid.
        error_code = 'REASSIGN_LINEAGE_INVALID'.
        RETURN.
      ENDIF.
      READ TABLE balances ASSIGNING FIELD-SYMBOL(<balance>)
        WITH KEY root_id = source-transaction_uuid.
      IF sy-subrc <> 0.
        APPEND VALUE #( root_id = source-transaction_uuid source = source ) TO balances ASSIGNING <balance>.
      ENDIF.
      IF day = target_date.
        <balance>-posted += row-quantity.
        CONTINUE.
      ENDIF.
      CASE row-transaction_type.
        WHEN zcl_pp_txn_type=>initial_assign OR zcl_pp_txn_type=>reassign
          OR zcl_pp_txn_type=>allocation_adjustment OR zcl_pp_txn_type=>reverse.
          <balance>-quantity += row-quantity.
        WHEN zcl_pp_txn_type=>confirm OR zcl_pp_txn_type=>recall
          OR zcl_pp_txn_type=>correction OR zcl_pp_txn_type=>recall_adjustment
          OR zcl_pp_txn_type=>confirm_adjustment.
          <balance>-quantity -= row-quantity.
        WHEN zcl_pp_txn_type=>transfer.
          <balance>-quantity += row-quantity.
          COLLECT VALUE debit( worker_id = row-from_worker_id uom = row-uom
                               quantity = row-quantity ) INTO deductions.
        WHEN OTHERS.
          error_code = 'REASSIGN_TYPE_UNSUPPORTED'.
          RETURN.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD deduct_unlinked.
    "Transfer-out and admin adjustments have no source root in the current model.
    "Consume oldest source groups deterministically, preserving the worker/unit total.
    SORT balances BY source-execution_date root_id.
    LOOP AT balances ASSIGNING FIELD-SYMBOL(<balance>) WHERE quantity < 0.
      COLLECT VALUE debit( worker_id = <balance>-source-worker_id uom = <balance>-source-uom
                           quantity = - <balance>-quantity ) INTO deductions.
      <balance>-quantity = 0.
    ENDLOOP.
    LOOP AT deductions ASSIGNING FIELD-SYMBOL(<debit>).
      LOOP AT balances ASSIGNING <balance>
        WHERE source-worker_id = <debit>-worker_id AND source-uom = <debit>-uom AND quantity > 0.
        DATA(consumed) = nmin( val1 = <balance>-quantity val2 = <debit>-quantity ).
        <balance>-quantity -= consumed.
        <debit>-quantity -= consumed.
        IF <debit>-quantity = 0.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD calculate.
    IF target_date <= '00010101'.
      result-error_code = 'REASSIGN_DATE_INVALID'.
      RETURN.
    ENDIF.
    DATA ledger TYPE ledger_index.
    LOOP AT rows INTO DATA(row) WHERE transaction_status = zcl_pp_txn_type=>posted.
      INSERT row INTO TABLE ledger.
      IF sy-subrc <> 0.
        result-error_code = 'REASSIGN_DUPLICATE_UUID'.
        RETURN.
      ENDIF.
    ENDLOOP.
    DATA balances TYPE buckets.
    DATA deductions TYPE debits.
    collect_day( EXPORTING ledger = ledger target_date = target_date
                 IMPORTING error_code = result-error_code
                 CHANGING balances = balances deductions = deductions ).
    IF result-error_code IS NOT INITIAL.
      RETURN.
    ENDIF.
    deduct_unlinked( CHANGING balances = balances deductions = deductions ).
    LOOP AT balances INTO DATA(balance).
      DATA(delta) = balance-quantity - balance-posted.
      IF delta = 0.
        CONTINUE.
      ENDIF.
      "Append a delta on replay, including negative corrections; never rewrite old receipts.
      APPEND VALUE #( operation_uuid = balance-source-operation_uuid
        original_transaction_uuid = balance-root_id
        original_transaction_type = balance-source-transaction_type
        worker_id = balance-source-worker_id to_worker_id = balance-source-worker_id
        work_id = balance-source-work_id shift_id = balance-source-shift_id
        transaction_type = zcl_pp_txn_type=>reassign quantity = delta uom = balance-source-uom
        execution_date = target_date work_date = target_date
        transaction_status = zcl_pp_txn_type=>posted source_channel = zcl_pp_txn_type=>source_system
        reason_code = 'DAILY_CARRY_FORWARD' ) TO result-entries.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
