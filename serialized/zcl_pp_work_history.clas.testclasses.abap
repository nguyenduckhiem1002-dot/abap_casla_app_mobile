CLASS ltc_history DEFINITION DEFERRED.
CLASS zcl_pp_work_history DEFINITION LOCAL FRIENDS ltc_history.

CLASS ltc_history DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS correction_and_reverse FOR TESTING.
    METHODS ancestor_scope FOR TESTING.
    METHODS legacy_work_date FOR TESTING.
ENDCLASS.

CLASS ltc_history IMPLEMENTATION.
  METHOD correction_and_reverse.
    DATA(rows) = VALUE zcl_pp_work_history=>ledger_rows(
      ( worker_id = 'HD000001' report_worker_id = 'HD000001' uom = 'ST'
        transaction_type = zcl_pp_txn_type=>initial_assign quantity = 100 )
      ( worker_id = 'HD000001' report_worker_id = 'HD000001' uom = 'ST'
        transaction_type = zcl_pp_txn_type=>confirm quantity = 25 )
      ( worker_id = 'HD000001' report_worker_id = 'HD000001' uom = 'ST'
        transaction_type = zcl_pp_txn_type=>recall quantity = 20 )
      ( worker_id = 'HD000001' report_worker_id = 'HD000001' uom = 'ST'
        transaction_type = zcl_pp_txn_type=>correction quantity = 10 )
      ( worker_id = 'HD000001' report_worker_id = 'HD000001' uom = 'ST'
        transaction_type = zcl_pp_txn_type=>reverse quantity = 35 ) ).
    DATA(actual) = zcl_pp_work_history=>summarize( rows ).
    cl_abap_unit_assert=>assert_equals( act = actual[ 1 ]-completed exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = actual[ 1 ]-remaining exp = 80 ).
    cl_abap_unit_assert=>assert_equals( act = actual[ 1 ]-txn_count exp = 5 ).
  ENDMETHOD.
  METHOD ancestor_scope.
    DATA roots TYPE zcl_pp_work_history=>root_keys.
    roots = VALUE #( ( transaction_uuid = '00000000000000000000000000000001' worker_id = 'HD000001' ) ).
    DATA(links) = VALUE zcl_pp_work_history=>txn_links(
      ( transaction_uuid = '00000000000000000000000000000003'
        original_transaction_uuid = '00000000000000000000000000000002' worker_id = 'HD000001' )
      ( transaction_uuid = '00000000000000000000000000000002'
        original_transaction_uuid = '00000000000000000000000000000001' worker_id = 'HD000001' )
      ( transaction_uuid = '00000000000000000000000000000004'
        original_transaction_uuid = '00000000000000000000000000000001' worker_id = 'OTHER' ) ).
    zcl_pp_work_history=>expand_roots( EXPORTING derived = links CHANGING roots = roots ).
    cl_abap_unit_assert=>assert_equals( act = lines( roots ) exp = 3 ).
    cl_abap_unit_assert=>assert_true( xsdbool(
      line_exists( roots[ transaction_uuid = '00000000000000000000000000000003' worker_id = 'HD000001' ] ) ) ).
  ENDMETHOD.
  METHOD legacy_work_date.
    DATA(rows) = VALUE zcl_pp_work_history=>ledger_rows(
      ( execution_date = '20260907' report_worker_id = 'HD000001' )
      ( execution_date = '20260908' work_date = '20260907' shift_id = 'NIGHT'
        report_worker_id = 'HD000001' ) ).
    DATA(actual) = zcl_pp_work_history=>build_entries( rows ).
    cl_abap_unit_assert=>assert_equals( act = actual[ 1 ]-work_date exp = '20260907' ).
    cl_abap_unit_assert=>assert_initial( actual[ 1 ]-shift_id ).
    cl_abap_unit_assert=>assert_equals( act = actual[ 2 ]-work_date exp = '20260907' ).
    cl_abap_unit_assert=>assert_equals( act = actual[ 2 ]-shift_id exp = 'NIGHT' ).
  ENDMETHOD.
ENDCLASS.
