CLASS zcl_pp_alloc_lineage DEFINITION PUBLIC FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    TYPES ledger_rows TYPE STANDARD TABLE OF ztb_pp_alloc_txn WITH EMPTY KEY.
    TYPES: BEGIN OF allocation_group,
             operation_uuid TYPE sysuuid_x16,
             worker_id TYPE ztb_pp_alloc_txn-worker_id,
             work_id TYPE ztb_pp_alloc_txn-work_id,
             shift_id TYPE ztb_pp_alloc_txn-shift_id,
             work_date TYPE d,
             uom TYPE ztb_pp_alloc_txn-uom,
           END OF allocation_group.
    TYPES: BEGIN OF resolution,
             is_valid TYPE abap_bool,
             error_code TYPE c LENGTH 40,
             source_transaction_type TYPE ztb_pp_alloc_txn-transaction_type,
             root_transaction_uuid TYPE sysuuid_x16,
             root_transaction_type TYPE ztb_pp_alloc_txn-transaction_type,
             usable_quantity TYPE ztb_pp_alloc_txn-quantity,
             work_id TYPE ztb_pp_alloc_txn-work_id,
             shift_id TYPE ztb_pp_alloc_txn-shift_id,
             work_date TYPE d,
           END OF resolution.
    CLASS-METHODS resolve
      IMPORTING rows TYPE ledger_rows original_transaction_uuid TYPE sysuuid_x16
                worker_id TYPE ztb_pp_alloc_txn-worker_id uom TYPE ztb_pp_alloc_txn-uom
      RETURNING VALUE(result) TYPE resolution.
    CLASS-METHODS find_group_root
      IMPORTING rows TYPE ledger_rows allocation_group TYPE allocation_group
      RETURNING VALUE(result) TYPE resolution.
    TYPES error_code TYPE c LENGTH 40.
    CLASS-METHODS confirmation_error
      IMPORTING lineage TYPE resolution work_id TYPE ztb_pp_alloc_txn-work_id
                shift_id TYPE ztb_pp_alloc_txn-shift_id quantity TYPE ztb_pp_alloc_txn-quantity
      RETURNING VALUE(result) TYPE error_code.
    CLASS-METHODS recall_error
      IMPORTING lineage TYPE resolution work_id TYPE ztb_pp_alloc_txn-work_id
                shift_id TYPE ztb_pp_alloc_txn-shift_id quantity TYPE ztb_pp_alloc_txn-quantity
      RETURNING VALUE(result) TYPE error_code.
  PRIVATE SECTION.
    TYPES ledger_index TYPE HASHED TABLE OF ztb_pp_alloc_txn WITH UNIQUE KEY transaction_uuid.
    CLASS-METHODS context_matches
      IMPORTING lineage TYPE resolution work_id TYPE ztb_pp_alloc_txn-work_id
                shift_id TYPE ztb_pp_alloc_txn-shift_id
      RETURNING VALUE(result) TYPE abap_bool.
    CLASS-METHODS owner
      IMPORTING row TYPE ztb_pp_alloc_txn RETURNING VALUE(result) TYPE ztb_pp_alloc_txn-worker_id.
    CLASS-METHODS business_date
      IMPORTING row TYPE ztb_pp_alloc_txn RETURNING VALUE(result) TYPE d.
    CLASS-METHODS effect
      IMPORTING row TYPE ztb_pp_alloc_txn RETURNING VALUE(result) TYPE ztb_pp_alloc_txn-quantity.
    CLASS-METHODS normalize
      IMPORTING selected TYPE ztb_pp_alloc_txn ledger TYPE ledger_index
      RETURNING VALUE(result) TYPE ztb_pp_alloc_txn.
    CLASS-METHODS descendants
      IMPORTING root TYPE ztb_pp_alloc_txn ledger TYPE ledger_index
      RETURNING VALUE(result) TYPE ledger_rows.
    CLASS-METHODS available_quantity
      IMPORTING rows TYPE ledger_rows RETURNING VALUE(result) TYPE ztb_pp_alloc_txn-quantity.
ENDCLASS.



CLASS ZCL_PP_ALLOC_LINEAGE IMPLEMENTATION.


  METHOD context_matches.
    result = xsdbool(
      ( lineage-work_id IS INITIAL OR lineage-work_id = work_id )
      AND ( lineage-shift_id IS INITIAL OR lineage-shift_id = shift_id ) ).
  ENDMETHOD.


  METHOD confirmation_error.
    IF lineage-is_valid = abap_false.
      result = 'CONFIRM_ORIGINAL_TRANSACTION_INVALID'.
    ELSEIF context_matches( lineage = lineage work_id = work_id shift_id = shift_id ) = abap_false.
      result = 'CONFIRM_ORIGINAL_CONTEXT_MISMATCH'.
*    ELSEIF quantity > lineage-usable_quantity.
*      result = 'CONFIRM_ORIGINAL_QUANTITY_EXCEEDED'.
    ENDIF.
  ENDMETHOD.


  METHOD recall_error.
    "Eligibility belongs to the canonical credit; the selected row may be REASSIGN.
    IF lineage-is_valid = abap_false
       OR ( lineage-root_transaction_type <> zcl_pp_txn_type=>initial_assign
        AND lineage-root_transaction_type <> zcl_pp_txn_type=>transfer
        AND lineage-root_transaction_type <> zcl_pp_txn_type=>allocation_adjustment ).
      result = 'RECALL_NOT_ALLOWED'.
    ELSEIF context_matches( lineage = lineage work_id = work_id shift_id = shift_id ) = abap_false.
      result = 'RECALL_ORIGINAL_CONTEXT_MISMATCH'.
    ELSEIF quantity > lineage-usable_quantity.
      result = 'RECALL_ORIGINAL_QUANTITY_EXCEEDED'.
    ENDIF.
  ENDMETHOD.


  METHOD owner.
    result = COND #( WHEN row-transaction_type = zcl_pp_txn_type=>transfer THEN row-to_worker_id
                     WHEN row-worker_id IS NOT INITIAL THEN row-worker_id ELSE row-to_worker_id ).
  ENDMETHOD.


  METHOD business_date.
    result = COND #( WHEN row-work_date IS NOT INITIAL THEN row-work_date ELSE row-execution_date ).
  ENDMETHOD.


  METHOD effect.
    CASE row-transaction_type.
      WHEN zcl_pp_txn_type=>initial_assign OR zcl_pp_txn_type=>transfer
        OR zcl_pp_txn_type=>allocation_adjustment.
        result = row-quantity.
      WHEN zcl_pp_txn_type=>reverse.
        result = row-quantity + row-defect_quantity.
      WHEN zcl_pp_txn_type=>confirm OR zcl_pp_txn_type=>recall OR zcl_pp_txn_type=>correction
        OR zcl_pp_txn_type=>recall_adjustment OR zcl_pp_txn_type=>confirm_adjustment.
        result = - row-quantity - row-defect_quantity.
      WHEN OTHERS.
        "REASSIGN is an opening snapshot, never another allocation credit.
        result = 0.
    ENDCASE.
  ENDMETHOD.


  METHOD normalize.
    DATA(current) = selected.
    DO lines( ledger ) TIMES.
      IF current-operation_uuid <> selected-operation_uuid OR current-uom <> selected-uom
         OR owner( current ) <> owner( selected ) OR current-work_id <> selected-work_id
         OR current-shift_id <> selected-shift_id.
        RETURN.
      ENDIF.
      CASE current-transaction_type.
        WHEN zcl_pp_txn_type=>initial_assign OR zcl_pp_txn_type=>reassign.
          IF current-quantity <= 0.
            RETURN.
          ENDIF.
          IF current-original_transaction_uuid IS INITIAL.
            IF current-transaction_type = zcl_pp_txn_type=>initial_assign.
              result = current.
            ENDIF.
            RETURN.
          ENDIF.
        WHEN zcl_pp_txn_type=>transfer OR zcl_pp_txn_type=>allocation_adjustment
          OR zcl_pp_txn_type=>recall_adjustment OR zcl_pp_txn_type=>confirm_adjustment.
          IF effect( current ) > 0.
            result = current.
          ENDIF.
          RETURN.
        WHEN OTHERS.
          RETURN.
      ENDCASE.
      READ TABLE ledger INTO current WITH TABLE KEY transaction_uuid = current-original_transaction_uuid.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
    ENDDO.
    "Missing parents and cycles return no root. There is no fixed five-hop limit.
  ENDMETHOD.


  METHOD descendants.
    DATA ids TYPE SORTED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.
    INSERT root-transaction_uuid INTO TABLE ids.
    APPEND root TO result.
    DATA(changed) = abap_true.
    WHILE changed = abap_true.
      changed = abap_false.
      LOOP AT ledger INTO DATA(row).
        IF row-operation_uuid <> root-operation_uuid OR row-uom <> root-uom
           OR owner( row ) <> owner( root ) OR row-original_transaction_uuid IS INITIAL
           OR line_exists( ids[ table_line = row-transaction_uuid ] )
           OR NOT line_exists( ids[ table_line = row-original_transaction_uuid ] ).
          CONTINUE.
        ENDIF.
        INSERT row-transaction_uuid INTO TABLE ids.
        APPEND row TO result.
        changed = abap_true.
      ENDLOOP.
    ENDWHILE.
  ENDMETHOD.


  METHOD available_quantity.
    DATA snapshot_date TYPE d.
    LOOP AT rows INTO DATA(row).
      result += effect( row ).
      IF row-transaction_type = zcl_pp_txn_type=>reassign AND business_date( row ) > snapshot_date.
        snapshot_date = business_date( row ).
      ENDIF.
    ENDLOOP.
    IF snapshot_date IS NOT INITIAL.
      DATA opening_balance TYPE ztb_pp_alloc_txn-quantity.
      LOOP AT rows INTO row.
        IF row-transaction_type = zcl_pp_txn_type=>reassign.
          IF business_date( row ) = snapshot_date.
            opening_balance += row-quantity.
          ENDIF.
        ELSEIF business_date( row ) >= snapshot_date.
          opening_balance += effect( row ).
        ENDIF.
      ENDLOOP.
      "A snapshot can include transfer-out without a source lineage. Respect its
      "net amount (including replay deltas) as well as the original live capacity.
      result = nmin( val1 = result val2 = opening_balance ).
    ENDIF.
    result = nmax( val1 = 0 val2 = result ).
  ENDMETHOD.


  METHOD resolve.
    DATA ledger TYPE ledger_index.
    LOOP AT rows INTO DATA(row) WHERE transaction_status = zcl_pp_txn_type=>posted.
      INSERT row INTO TABLE ledger.
    ENDLOOP.
    DATA(selected) = VALUE #( ledger[ transaction_uuid = original_transaction_uuid ] OPTIONAL ).
    result-error_code = 'ORIGINAL_TRANSACTION_INVALID'.
    IF selected IS INITIAL OR selected-uom <> uom.
      RETURN.
    ENDIF.
    IF owner( selected ) <> worker_id.
      result-error_code = 'ORIGINAL_TRANSACTION_WORKER_MISMATCH'.
      RETURN.
    ENDIF.
    IF selected-transaction_type <> zcl_pp_txn_type=>initial_assign
       AND selected-transaction_type <> zcl_pp_txn_type=>reassign
       AND selected-transaction_type <> zcl_pp_txn_type=>transfer
       AND selected-transaction_type <> zcl_pp_txn_type=>allocation_adjustment
       AND selected-transaction_type <> zcl_pp_txn_type=>recall_adjustment
       AND selected-transaction_type <> zcl_pp_txn_type=>confirm_adjustment.
      result-error_code = 'ORIGINAL_TRANSACTION_TYPE_INVALID'.
      RETURN.
    ENDIF.
    IF ( selected-transaction_type = zcl_pp_txn_type=>reassign AND selected-quantity <= 0 )
       OR ( selected-transaction_type <> zcl_pp_txn_type=>reassign AND effect( selected ) <= 0 ).
      RETURN.
    ENDIF.
    DATA(root) = normalize( selected = selected ledger = ledger ).
    IF root IS INITIAL.
      RETURN.
    ENDIF.
    DATA(members) = descendants( root = root ledger = ledger ).
    result = VALUE #( is_valid = abap_true source_transaction_type = selected-transaction_type
      root_transaction_uuid = root-transaction_uuid root_transaction_type = root-transaction_type
      usable_quantity = available_quantity( members )
      work_id = root-work_id shift_id = root-shift_id work_date = business_date( root ) ).
  ENDMETHOD.


  METHOD find_group_root.
    IF allocation_group-shift_id IS INITIAL OR allocation_group-work_date IS INITIAL.
      RETURN.
    ENDIF.
    DATA candidates TYPE ledger_rows.
    LOOP AT rows INTO DATA(row)
      WHERE operation_uuid = allocation_group-operation_uuid
        AND worker_id = allocation_group-worker_id AND work_id = allocation_group-work_id
        AND shift_id = allocation_group-shift_id AND uom = allocation_group-uom
        AND transaction_status = zcl_pp_txn_type=>posted AND quantity > 0.
      IF business_date( row ) = allocation_group-work_date
         AND ( row-transaction_type = zcl_pp_txn_type=>initial_assign
            OR row-transaction_type = zcl_pp_txn_type=>reassign ).
        APPEND row TO candidates.
      ENDIF.
    ENDLOOP.
    "R before I: prefer today's carried group. Never rewrite a historical receipt.
    SORT candidates BY transaction_type DESCENDING executed_at transaction_uuid.
    IF candidates IS INITIAL.
      RETURN.
    ENDIF.
    result = resolve( rows = rows original_transaction_uuid = candidates[ 1 ]-transaction_uuid
                      worker_id = allocation_group-worker_id uom = allocation_group-uom ).
  ENDMETHOD.
ENDCLASS.
