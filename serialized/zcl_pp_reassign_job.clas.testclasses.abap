CLASS ltc_reassign DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    CONSTANTS root_id TYPE sysuuid_x16 VALUE '00000000000000000000000000000001'.
    METHODS grouped_assignments FOR TESTING.
    METHODS replay_after_late_confirm FOR TESTING.
    METHODS transfer_and_worker_isolation FOR TESTING.
    METHODS preserve_work_and_shift FOR TESTING.
    METHODS opening_and_legacy_date FOR TESTING.
    METHODS broken_lineage FOR TESTING.
    METHODS assignment RETURNING VALUE(result) TYPE ztb_pp_alloc_txn.
ENDCLASS.

CLASS ltc_reassign IMPLEMENTATION.
  METHOD assignment.
    result = VALUE #( transaction_uuid = root_id transaction_type = zcl_pp_txn_type=>initial_assign
      worker_id = 'WORKER01' to_worker_id = 'WORKER01' work_id = 'POSITION01' shift_id = 'DAY'
      work_date = '20260923' execution_date = '20260923' quantity = 100 uom = 'ST'
      transaction_status = zcl_pp_txn_type=>posted ).
  ENDMETHOD.

  METHOD grouped_assignments.
    DATA(rows) = VALUE zcl_pp_reassign_job=>ledger_rows( ( assignment( ) ) ).
    DATA(extra) = assignment( ).
    extra-transaction_uuid = '00000000000000000000000000000002'.
    extra-original_transaction_uuid = root_id.
    extra-quantity = 20.
    APPEND extra TO rows.
    DATA(effect) = extra.
    effect-transaction_uuid = '00000000000000000000000000000003'.
    effect-transaction_type = zcl_pp_txn_type=>confirm.
    effect-quantity = 30.
    APPEND effect TO rows.
    effect-transaction_uuid = '00000000000000000000000000000004'.
    effect-original_transaction_uuid = '00000000000000000000000000000003'.
    effect-transaction_type = zcl_pp_txn_type=>correction.
    effect-quantity = 5.
    APPEND effect TO rows.
    effect-transaction_uuid = '00000000000000000000000000000005'.
    effect-transaction_type = zcl_pp_txn_type=>reverse.
    effect-quantity = 35.
    APPEND effect TO rows.
    effect-transaction_uuid = '00000000000000000000000000000006'.
    effect-original_transaction_uuid = root_id.
    effect-transaction_type = zcl_pp_txn_type=>recall.
    effect-quantity = 10.
    APPEND effect TO rows.
    "Consumption may be read before credits; database order must not affect the result.
    SORT rows BY transaction_uuid DESCENDING.
    DATA(actual) = zcl_pp_reassign_job=>calculate( rows = rows target_date = '20260924' ).
    cl_abap_unit_assert=>assert_initial( actual-error_code ).
    cl_abap_unit_assert=>assert_equals( act = lines( actual-entries ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = actual-entries[ 1 ]-quantity exp = 110 ).
    cl_abap_unit_assert=>assert_equals( act = actual-entries[ 1 ]-original_transaction_uuid exp = root_id ).
    cl_abap_unit_assert=>assert_equals( act = actual-entries[ 1 ]-work_id exp = 'POSITION01' ).
    cl_abap_unit_assert=>assert_equals( act = actual-entries[ 1 ]-shift_id exp = 'DAY' ).
  ENDMETHOD.

  METHOD replay_after_late_confirm.
    DATA(rows) = VALUE zcl_pp_reassign_job=>ledger_rows( ( assignment( ) ) ).
    DATA(first) = zcl_pp_reassign_job=>calculate( rows = rows target_date = '20260924' ).
    DATA(receipt) = first-entries[ 1 ].
    receipt-transaction_uuid = '00000000000000000000000000000002'.
    APPEND receipt TO rows.
    DATA(replay) = zcl_pp_reassign_job=>calculate( rows = rows target_date = '20260924' ).
    cl_abap_unit_assert=>assert_initial( replay-entries ).
    DATA(late) = assignment( ).
    late-transaction_uuid = '00000000000000000000000000000003'.
    late-original_transaction_uuid = root_id.
    late-transaction_type = zcl_pp_txn_type=>confirm.
    late-quantity = 20.
    APPEND late TO rows.
    replay = zcl_pp_reassign_job=>calculate( rows = rows target_date = '20260924' ).
    cl_abap_unit_assert=>assert_initial( replay-error_code ).
    cl_abap_unit_assert=>assert_equals( act = lines( replay-entries ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = replay-entries[ 1 ]-quantity exp = -20 ).
    receipt = replay-entries[ 1 ].
    receipt-transaction_uuid = '00000000000000000000000000000004'.
    APPEND receipt TO rows.
    replay = zcl_pp_reassign_job=>calculate( rows = rows target_date = '20260924' ).
    cl_abap_unit_assert=>assert_initial( replay-entries ).
    DATA(next_day) = zcl_pp_reassign_job=>calculate( rows = rows target_date = '20260925' ).
    cl_abap_unit_assert=>assert_equals( act = next_day-entries[ 1 ]-quantity exp = 80 ).
  ENDMETHOD.

  METHOD transfer_and_worker_isolation.
    DATA(rows) = VALUE zcl_pp_reassign_job=>ledger_rows( ( assignment( ) ) ).
    DATA(transfer) = assignment( ).
    transfer-transaction_uuid = '00000000000000000000000000000002'.
    transfer-transaction_type = zcl_pp_txn_type=>transfer.
    CLEAR transfer-worker_id.
    transfer-from_worker_id = 'WORKER01'.
    transfer-to_worker_id = 'WORKER02'.
    transfer-quantity = 40.
    APPEND transfer TO rows.
    DATA(confirmation) = assignment( ).
    confirmation-transaction_uuid = '00000000000000000000000000000003'.
    confirmation-original_transaction_uuid = transfer-transaction_uuid.
    confirmation-transaction_type = zcl_pp_txn_type=>confirm.
    confirmation-worker_id = 'WORKER02'.
    confirmation-quantity = 10.
    APPEND confirmation TO rows.
    DATA(actual) = zcl_pp_reassign_job=>calculate( rows = rows target_date = '20260924' ).
    cl_abap_unit_assert=>assert_initial( actual-error_code ).
    cl_abap_unit_assert=>assert_equals( act = lines( actual-entries ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = actual-entries[ worker_id = 'WORKER01' ]-quantity exp = 60 ).
    cl_abap_unit_assert=>assert_equals( act = actual-entries[ worker_id = 'WORKER02' ]-quantity exp = 30 ).
  ENDMETHOD.

  METHOD opening_and_legacy_date.
    DATA(old) = assignment( ).
    old-work_date = '20260922'.
    old-execution_date = '20260922'.
    DATA(rows) = VALUE zcl_pp_reassign_job=>ledger_rows( ( old ) ).
    DATA(actual) = zcl_pp_reassign_job=>calculate( rows = rows target_date = '20260924' ).
    cl_abap_unit_assert=>assert_initial( actual-entries ).
    DATA(opening) = assignment( ).
    opening-transaction_uuid = '00000000000000000000000000000002'.
    opening-original_transaction_uuid = root_id.
    opening-transaction_type = zcl_pp_txn_type=>reassign.
    opening-quantity = 70.
    CLEAR opening-work_date.
    APPEND opening TO rows.
    DATA(adjustment) = assignment( ).
    adjustment-transaction_uuid = '00000000000000000000000000000003'.
    adjustment-transaction_type = zcl_pp_txn_type=>confirm_adjustment.
    adjustment-quantity = 10.
    APPEND adjustment TO rows.
    actual = zcl_pp_reassign_job=>calculate( rows = rows target_date = '20260924' ).
    cl_abap_unit_assert=>assert_initial( actual-error_code ).
    cl_abap_unit_assert=>assert_equals( act = actual-entries[ 1 ]-quantity exp = 60 ).
  ENDMETHOD.

  METHOD preserve_work_and_shift.
    DATA(rows) = VALUE zcl_pp_reassign_job=>ledger_rows( ( assignment( ) ) ).
    DATA(other) = assignment( ).
    other-transaction_uuid = '00000000000000000000000000000002'.
    other-work_id = 'POSITION02'.
    other-shift_id = 'NIGHT'.
    other-quantity = 50.
    APPEND other TO rows.
    DATA(today) = other.
    today-transaction_uuid = '00000000000000000000000000000003'.
    today-work_date = '20260924'.
    today-execution_date = '20260924'.
    APPEND today TO rows.
    DATA(actual) = zcl_pp_reassign_job=>calculate( rows = rows target_date = '20260924' ).
    cl_abap_unit_assert=>assert_initial( actual-error_code ).
    cl_abap_unit_assert=>assert_equals( act = lines( actual-entries ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = actual-entries[ work_id = 'POSITION01' ]-quantity exp = 100 ).
    cl_abap_unit_assert=>assert_equals( act = actual-entries[ work_id = 'POSITION02' ]-quantity exp = 50 ).
    cl_abap_unit_assert=>assert_equals( act = actual-entries[ work_id = 'POSITION02' ]-shift_id exp = 'NIGHT' ).
  ENDMETHOD.

  METHOD broken_lineage.
    DATA(row) = assignment( ).
    row-original_transaction_uuid = '00000000000000000000000000000002'.
    DATA(rows) = VALUE zcl_pp_reassign_job=>ledger_rows( ( row ) ).
    DATA(actual) = zcl_pp_reassign_job=>calculate( rows = rows target_date = '20260924' ).
    cl_abap_unit_assert=>assert_equals( act = actual-error_code exp = 'REASSIGN_LINEAGE_INVALID' ).
    cl_abap_unit_assert=>assert_initial( actual-entries ).
    row-original_transaction_uuid = root_id.
    rows = VALUE #( ( row ) ).
    actual = zcl_pp_reassign_job=>calculate( rows = rows target_date = '20260924' ).
    cl_abap_unit_assert=>assert_equals( act = actual-error_code exp = 'REASSIGN_LINEAGE_INVALID' ).
  ENDMETHOD.
ENDCLASS.
