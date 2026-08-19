"Read model for the work assignment / completion history shown in the
"mobile app. Everything reported here comes from transaction data
"(ZTB_PP_ALLOC_TXN joined to its operation). ZI_PP_WorkerRef - the wrapper
"over the partner table ZTB_KB_NHANCONG - supplies worker names only and is
"never used to decide who may see a row: a worker who moves to another work
"center must not make past rows appear or disappear.
CLASS zcl_pp_work_history DEFINITION
  PUBLIC FINAL CREATE PRIVATE.

  PUBLIC SECTION.
    "Method parameters cannot carry a LENGTH addition, so the short codes
    "get named types that the signatures below can reuse.
    TYPES range_selection TYPE c LENGTH 1.
    TYPES scope_selection TYPE c LENGTH 1.
    TYPES failure_code TYPE c LENGTH 40.

    CONSTANTS:
      range_day    TYPE range_selection VALUE 'D',
      range_week   TYPE range_selection VALUE 'W',
      range_month  TYPE range_selection VALUE 'M',
      range_custom TYPE range_selection VALUE 'C'.
    CONSTANTS:
      "Scope actually applied, echoed back so the app can label the screen.
      scope_team TYPE scope_selection VALUE 'T',
      scope_self TYPE scope_selection VALUE 'S'.
    CONSTANTS:
      "RBAC functions that decide which scope a caller gets.
      func_team TYPE ztb_mob_func-func_id VALUE 'PP_HIST_TEAM',
      func_self TYPE ztb_mob_func-func_id VALUE 'PP_HIST_SELF'.
    CONSTANTS:
      "Default window for every role. A custom range may reach further back
      "but never covers a wider span than max_custom_days.
      default_days    TYPE i VALUE 30,
      max_custom_days TYPE i VALUE 92,
      "Safety caps. Hitting the scan cap sets is_truncated on the result.
      max_scan_rows   TYPE i VALUE 20000,
      max_entry_rows  TYPE i VALUE 1000.

    TYPES: BEGIN OF worker_summary,
             worker_id   TYPE ztb_pp_alloc_txn-worker_id,
             worker_name TYPE zi_pp_workerref-workername,
             assigned    TYPE ztb_pp_alloc_txn-quantity,
             completed   TYPE ztb_pp_alloc_txn-quantity,
             remaining   TYPE ztb_pp_alloc_txn-quantity,
             uom         TYPE ztb_pp_alloc_txn-uom,
             txn_count   TYPE i,
           END OF worker_summary,
           worker_summaries TYPE SORTED TABLE OF worker_summary
                            WITH UNIQUE KEY worker_id uom.

    TYPES: BEGIN OF history_entry,
             transaction_uuid   TYPE ztb_pp_alloc_txn-transaction_uuid,
             execution_date     TYPE ztb_pp_alloc_txn-execution_date,
             worker_id          TYPE ztb_pp_alloc_txn-worker_id,
             worker_name        TYPE zi_pp_workerref-workername,
             production_order   TYPE ztb_pp_op_alloc-production_order,
             operation_no       TYPE ztb_pp_op_alloc-operation_no,
             plant              TYPE ztb_pp_op_alloc-plant,
             work_center        TYPE ztb_pp_op_alloc-work_center,
             transaction_type   TYPE ztb_pp_alloc_txn-transaction_type,
             quantity           TYPE ztb_pp_alloc_txn-quantity,
             uom                TYPE ztb_pp_alloc_txn-uom,
             transaction_status TYPE ztb_pp_alloc_txn-transaction_status,
           END OF history_entry,
           history_entries TYPE STANDARD TABLE OF history_entry
                           WITH EMPTY KEY.

    TYPES: BEGIN OF history,
             is_valid     TYPE abap_bool,
             error_code   TYPE failure_code,
             scope_code   TYPE scope_selection,
             date_from    TYPE d,
             date_to      TYPE d,
             is_truncated TYPE abap_bool,
             entry_count  TYPE i,
             worker_count TYPE i,
             workers      TYPE worker_summaries,
             entries      TYPE history_entries,
           END OF history.

    CLASS-METHODS read
      IMPORTING access_token    TYPE string
                device_id       TYPE ztb_mob_session-device_id
                range_code      TYPE range_selection
                date_from       TYPE d
                date_to         TYPE d
                worker_id       TYPE ztb_pp_alloc_txn-worker_id OPTIONAL
                include_entries TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(result)   TYPE history
      RAISING   cx_abap_message_digest.

  PRIVATE SECTION.
    TYPES: BEGIN OF ledger_row,
             transaction_uuid   TYPE ztb_pp_alloc_txn-transaction_uuid,
             original_transaction_uuid
               TYPE ztb_pp_alloc_txn-original_transaction_uuid,
             execution_date     TYPE ztb_pp_alloc_txn-execution_date,
             report_worker_id   TYPE ztb_pp_alloc_txn-worker_id,
             worker_id          TYPE ztb_pp_alloc_txn-worker_id,
             from_worker_id     TYPE ztb_pp_alloc_txn-from_worker_id,
             to_worker_id       TYPE ztb_pp_alloc_txn-to_worker_id,
             transaction_type   TYPE ztb_pp_alloc_txn-transaction_type,
             quantity           TYPE ztb_pp_alloc_txn-quantity,
             uom                TYPE ztb_pp_alloc_txn-uom,
             transaction_status TYPE ztb_pp_alloc_txn-transaction_status,
             production_order   TYPE ztb_pp_op_alloc-production_order,
             operation_no       TYPE ztb_pp_op_alloc-operation_no,
             plant              TYPE ztb_pp_op_alloc-plant,
             work_center        TYPE ztb_pp_op_alloc-work_center,
           END OF ledger_row,
           ledger_rows TYPE STANDARD TABLE OF ledger_row WITH EMPTY KEY.

    TYPES: BEGIN OF master_row,
             worker_id   TYPE zi_pp_workerref-workerid,
             worker_name TYPE zi_pp_workerref-workername,
             valid_from  TYPE zi_pp_workerref-validfrom,
             valid_to    TYPE zi_pp_workerref-validto,
           END OF master_row,
           master_rows TYPE STANDARD TABLE OF master_row WITH EMPTY KEY.

    CLASS-METHODS resolve_range
      IMPORTING range_code     TYPE range_selection
                date_from      TYPE d
                date_to        TYPE d
      EXPORTING effective_from TYPE d
                effective_to   TYPE d
                error_code     TYPE failure_code.

    CLASS-METHODS worker_of_account
      IMPORTING user_uuid     TYPE sysuuid_x16
      RETURNING VALUE(result) TYPE ztb_pp_alloc_txn-worker_id.

    CLASS-METHODS select_self
      IMPORTING worker        TYPE ztb_pp_alloc_txn-worker_id
                date_from     TYPE d
                date_to       TYPE d
      RETURNING VALUE(result) TYPE ledger_rows.

    CLASS-METHODS select_team
      IMPORTING user_uuid     TYPE sysuuid_x16
                worker        TYPE ztb_pp_alloc_txn-worker_id
                date_from     TYPE d
                date_to       TYPE d
      RETURNING VALUE(result) TYPE ledger_rows.

    CLASS-METHODS summarize
      IMPORTING rows          TYPE ledger_rows
      RETURNING VALUE(result) TYPE worker_summaries.

    CLASS-METHODS build_entries
      IMPORTING rows          TYPE ledger_rows
      RETURNING VALUE(result) TYPE history_entries.

    CLASS-METHODS add_quantity
      IMPORTING worker    TYPE ztb_pp_alloc_txn-worker_id
                uom       TYPE ztb_pp_alloc_txn-uom
                assigned  TYPE ztb_pp_alloc_txn-quantity DEFAULT 0
                completed TYPE ztb_pp_alloc_txn-quantity DEFAULT 0
      CHANGING  summaries TYPE worker_summaries.

    CLASS-METHODS read_master
      IMPORTING history       TYPE history
      RETURNING VALUE(result) TYPE master_rows.

    CLASS-METHODS resolve_names
      CHANGING history TYPE history.
ENDCLASS.

CLASS zcl_pp_work_history IMPLEMENTATION.
  METHOD read.
    DATA(auth) = zcl_mob_token_validator=>validate_token(
      token = access_token
      device_id = device_id ).
    IF auth-is_valid = abap_false.
      result-error_code = auth-error_code.
      RETURN.
    ENDIF.

    "Scope comes from the RBAC functions of the caller, never from anything
    "the device sent. A supervisor sees the assignments they booked;
    "everybody else may only look at their own rows.
    DATA(worker_filter) = worker_id.
    DATA(permissions) = zcl_mob_token_validator=>get_permissions(
      auth-user_uuid ).
    IF line_exists( permissions[ func_id = func_team ] ).
      result-scope_code = scope_team.
    ELSEIF line_exists( permissions[ func_id = func_self ] ).
      result-scope_code = scope_self.
      "A self view ignores whichever worker the caller asked for.
      worker_filter = worker_of_account( auth-user_uuid ).
      IF worker_filter IS INITIAL.
        result-error_code = 'WORKER_NOT_MAPPED'.
        RETURN.
      ENDIF.
    ELSE.
      result-error_code = 'MISSING_PERMISSION'.
      RETURN.
    ENDIF.

    DATA range_error TYPE failure_code.
    resolve_range(
      EXPORTING range_code = range_code
                date_from = date_from
                date_to = date_to
      IMPORTING effective_from = result-date_from
                effective_to = result-date_to
                error_code = range_error ).
    IF range_error IS NOT INITIAL.
      result-error_code = range_error.
      CLEAR result-date_from.
      CLEAR result-date_to.
      RETURN.
    ENDIF.

    DATA(rows) = COND ledger_rows(
      WHEN result-scope_code = scope_self
      THEN select_self( worker = worker_filter
                        date_from = result-date_from
                        date_to = result-date_to )
      ELSE select_team( user_uuid = auth-user_uuid
                        worker = worker_filter
                        date_from = result-date_from
                        date_to = result-date_to ) ).

    result-entry_count = lines( rows ).
    result-is_truncated = xsdbool( result-entry_count >= max_scan_rows ).
    result-workers = summarize( rows ).
    DATA unique_workers TYPE SORTED TABLE OF ztb_pp_alloc_txn-worker_id
                        WITH UNIQUE KEY table_line.
    unique_workers = VALUE #( FOR summary IN result-workers
                              ( summary-worker_id ) ).
    result-worker_count = lines( unique_workers ).
    IF include_entries = abap_true.
      result-entries = build_entries( rows ).
      IF result-entry_count > max_entry_rows.
        result-is_truncated = abap_true.
      ENDIF.
    ENDIF.
    resolve_names( CHANGING history = result ).
    result-is_valid = abap_true.
  ENDMETHOD.

  METHOD resolve_range.
    DATA(today) = cl_abap_context_info=>get_system_date( ).
    "A client that sends nothing, or a code from a newer app version, gets
    "the default month window rather than an unbounded query.
    DATA(selection) = COND range_selection(
      WHEN range_code = range_day
        OR range_code = range_week
        OR range_code = range_custom
      THEN range_code
      ELSE range_month ).
    CASE selection.
      WHEN range_custom.
        IF date_from IS INITIAL OR date_to IS INITIAL OR date_from > date_to.
          error_code = 'RANGE_INVALID'.
          RETURN.
        ENDIF.
        IF date_to > today.
          error_code = 'RANGE_IN_FUTURE'.
          RETURN.
        ENDIF.
        IF date_to - date_from >= max_custom_days.
          "Older periods stay reachable; one call just may not span more
          "days than this.
          error_code = 'RANGE_TOO_WIDE'.
          RETURN.
        ENDIF.
        effective_from = date_from.
        effective_to = date_to.
      WHEN range_day.
        effective_from = today.
        effective_to = today.
      WHEN range_week.
        effective_from = today - 6.
        effective_to = today.
      WHEN OTHERS.
        "range_month, and anything normalised into it above.
        effective_from = today - ( default_days - 1 ).
        effective_to = today.
    ENDCASE.
  ENDMETHOD.

  METHOD worker_of_account.
    "The account carries the worker id in its own field, the same one
    "verify_worker_password looks accounts up by. It is wider there than in
    "the ledger, so an id that does not fit is refused instead of truncated:
    "a truncated id would quietly point at somebody else's rows.
    SELECT FROM ztb_mob_user
      FIELDS worker_id
      WHERE user_uuid = @user_uuid
      INTO TABLE @DATA(accounts)
      UP TO 1 ROWS.
    IF accounts IS INITIAL.
      RETURN.
    ENDIF.
    DATA(candidate) = to_upper(
      condense( CONV string( accounts[ 1 ]-worker_id ) ) ).
    IF candidate IS INITIAL.
      RETURN.
    ENDIF.
    result = CONV #( candidate ).
    IF CONV string( result ) <> candidate.
      CLEAR result.
    ENDIF.
  ENDMETHOD.

  METHOD select_self.
    SELECT FROM ztb_pp_alloc_txn AS txn
      INNER JOIN ztb_pp_op_alloc AS op
        ON op~operation_uuid = txn~operation_uuid
      FIELDS txn~transaction_uuid, txn~original_transaction_uuid,
             txn~execution_date, txn~worker_id,
             txn~from_worker_id, txn~to_worker_id, txn~transaction_type,
             txn~quantity, txn~uom, txn~transaction_status,
             op~production_order, op~operation_no, op~plant, op~work_center
      WHERE txn~execution_date BETWEEN @date_from AND @date_to
        AND txn~transaction_status = @zcl_pp_txn_type=>posted
        AND ( txn~worker_id = @worker
           OR txn~from_worker_id = @worker
           OR txn~to_worker_id = @worker )
      ORDER BY txn~execution_date DESCENDING, txn~transaction_uuid
      INTO CORRESPONDING FIELDS OF TABLE @result
      UP TO @max_scan_rows ROWS.
    LOOP AT result ASSIGNING FIELD-SYMBOL(<row>).
      <row>-report_worker_id = worker.
    ENDLOOP.
  ENDMETHOD.

  METHOD select_team.
    "Step 1 - what this supervisor booked. Scope is frozen in the ledger: a
    "row is in scope because the supervisor booked the assignment, never
    "because of any current work center in master data. A worker who moves
    "to another team therefore keeps appearing in the old team's history.
    SELECT DISTINCT transaction_uuid, operation_uuid, worker_id,
                    from_worker_id, to_worker_id
      FROM ztb_pp_alloc_txn
      WHERE actor_user_uuid = @user_uuid
        AND transaction_type IN ( @zcl_pp_txn_type=>initial_assign,
                                  @zcl_pp_txn_type=>transfer )
        AND transaction_status = @zcl_pp_txn_type=>posted
        AND execution_date <= @date_to
        AND ( @worker = ' '
           OR worker_id = @worker
           OR from_worker_id = @worker
           OR to_worker_id = @worker )
      INTO TABLE @DATA(booked).
    IF booked IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF scope_key,
             operation_uuid TYPE ztb_pp_alloc_txn-operation_uuid,
             worker_id      TYPE ztb_pp_alloc_txn-worker_id,
           END OF scope_key.
    DATA scope TYPE SORTED TABLE OF scope_key
               WITH UNIQUE KEY operation_uuid worker_id.
    TYPES: BEGIN OF root_key,
             transaction_uuid TYPE ztb_pp_alloc_txn-transaction_uuid,
             worker_id        TYPE ztb_pp_alloc_txn-worker_id,
           END OF root_key.
    DATA roots TYPE SORTED TABLE OF root_key
               WITH UNIQUE KEY transaction_uuid worker_id.
    LOOP AT booked ASSIGNING FIELD-SYMBOL(<booked>).
      IF <booked>-worker_id IS NOT INITIAL.
        INSERT VALUE #( operation_uuid = <booked>-operation_uuid
                        worker_id = <booked>-worker_id ) INTO TABLE scope.
        INSERT VALUE #( transaction_uuid = <booked>-transaction_uuid
                        worker_id = <booked>-worker_id ) INTO TABLE roots.
      ENDIF.
      IF <booked>-from_worker_id IS NOT INITIAL.
        INSERT VALUE #( operation_uuid = <booked>-operation_uuid
                        worker_id = <booked>-from_worker_id ) INTO TABLE scope.
        INSERT VALUE #( transaction_uuid = <booked>-transaction_uuid
                        worker_id = <booked>-from_worker_id ) INTO TABLE roots.
      ENDIF.
      IF <booked>-to_worker_id IS NOT INITIAL.
        INSERT VALUE #( operation_uuid = <booked>-operation_uuid
                        worker_id = <booked>-to_worker_id ) INTO TABLE scope.
        INSERT VALUE #( transaction_uuid = <booked>-transaction_uuid
                        worker_id = <booked>-to_worker_id ) INTO TABLE roots.
      ENDIF.
    ENDLOOP.
    IF worker IS NOT INITIAL.
      DELETE scope WHERE worker_id <> worker.
    ENDIF.
    IF scope IS INITIAL.
      RETURN.
    ENDIF.

    "Step 2 - every posted row for those operation/worker pairs, including
    "the confirmations the worker posted later. Without those the progress
    "columns would stay empty for a supervisor who only assigns.
    SELECT FROM ztb_pp_alloc_txn AS txn
      INNER JOIN ztb_pp_op_alloc AS op
        ON op~operation_uuid = txn~operation_uuid
      FIELDS txn~transaction_uuid, txn~original_transaction_uuid,
             txn~execution_date, txn~worker_id,
             txn~from_worker_id, txn~to_worker_id, txn~transaction_type,
             txn~quantity, txn~uom, txn~transaction_status,
             op~production_order, op~operation_no, op~plant, op~work_center
      FOR ALL ENTRIES IN @scope
      WHERE txn~operation_uuid = @scope-operation_uuid
        AND ( txn~worker_id = @scope-worker_id
           OR txn~from_worker_id = @scope-worker_id
           OR txn~to_worker_id = @scope-worker_id )
        AND txn~execution_date BETWEEN @date_from AND @date_to
        AND txn~transaction_status = @zcl_pp_txn_type=>posted
      INTO TABLE @DATA(candidates)
      UP TO @max_scan_rows ROWS.
    "FOR ALL ENTRIES rules out ORDER BY here, so the newest-first order the
    "app expects is applied after the read.
    LOOP AT candidates ASSIGNING FIELD-SYMBOL(<candidate>).
      LOOP AT scope ASSIGNING FIELD-SYMBOL(<scope>)
        WHERE operation_uuid = <candidate>-operation_uuid.
        IF <candidate>-worker_id <> <scope>-worker_id
           AND <candidate>-from_worker_id <> <scope>-worker_id
           AND <candidate>-to_worker_id <> <scope>-worker_id.
          CONTINUE.
        ENDIF.
        IF NOT line_exists( roots[
             transaction_uuid = <candidate>-transaction_uuid
             worker_id = <scope>-worker_id ] )
           AND NOT line_exists( roots[
             transaction_uuid = <candidate>-original_transaction_uuid
             worker_id = <scope>-worker_id ] ).
          "Derived rows must point to the assignment/transfer root. This is
          "what prevents another supervisor's booking on the same operation
          "and worker from leaking into this supervisor's figures.
          CONTINUE.
        ENDIF.
        APPEND CORRESPONDING #( <candidate> ) TO result
          ASSIGNING FIELD-SYMBOL(<result_row>).
        <result_row>-report_worker_id = <scope>-worker_id.
        IF lines( result ) >= max_scan_rows.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF lines( result ) >= max_scan_rows.
        EXIT.
      ENDIF.
    ENDLOOP.
    SORT result BY execution_date DESCENDING transaction_uuid report_worker_id.
  ENDMETHOD.

  METHOD summarize.
    LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).
      CASE <row>-transaction_type.
        WHEN zcl_pp_txn_type=>initial_assign.
          IF <row>-worker_id <> <row>-report_worker_id.
            CONTINUE.
          ENDIF.
          add_quantity( EXPORTING worker = <row>-report_worker_id
                                  uom = <row>-uom
                                  assigned = <row>-quantity
                        CHANGING summaries = result ).
        WHEN zcl_pp_txn_type=>transfer.
          IF <row>-to_worker_id = <row>-report_worker_id.
            add_quantity( EXPORTING worker = <row>-report_worker_id
                                    uom = <row>-uom
                                    assigned = <row>-quantity
                          CHANGING summaries = result ).
          ENDIF.
          IF <row>-from_worker_id = <row>-report_worker_id.
            add_quantity( EXPORTING worker = <row>-report_worker_id
                                    uom = <row>-uom
                                    assigned = <row>-quantity * -1
                          CHANGING summaries = result ).
          ENDIF.
        WHEN zcl_pp_txn_type=>confirm.
          IF <row>-worker_id <> <row>-report_worker_id.
            CONTINUE.
          ENDIF.
          add_quantity( EXPORTING worker = <row>-report_worker_id
                                  uom = <row>-uom
                                  completed = <row>-quantity
                        CHANGING summaries = result ).
        WHEN zcl_pp_txn_type=>reverse.
          IF <row>-worker_id <> <row>-report_worker_id.
            CONTINUE.
          ENDIF.
          add_quantity( EXPORTING worker = <row>-report_worker_id
                                  uom = <row>-uom
                                  completed = <row>-quantity * -1
                        CHANGING summaries = result ).
        WHEN OTHERS.
          "An unknown type is counted but not booked, so adding a
          "transaction type later cannot silently distort the figures.
          add_quantity( EXPORTING worker = <row>-report_worker_id
                                  uom = <row>-uom
                        CHANGING summaries = result ).
      ENDCASE.
    ENDLOOP.
    LOOP AT result ASSIGNING FIELD-SYMBOL(<summary>).
      <summary>-remaining = <summary>-assigned - <summary>-completed.
    ENDLOOP.
  ENDMETHOD.

  METHOD add_quantity.
    IF worker IS INITIAL.
      RETURN.
    ENDIF.
    ASSIGN summaries[ worker_id = worker uom = uom ]
      TO FIELD-SYMBOL(<summary>).
    IF sy-subrc <> 0.
      INSERT VALUE #( worker_id = worker uom = uom ) INTO TABLE summaries
        ASSIGNING <summary>.
    ENDIF.
    <summary>-assigned = <summary>-assigned + assigned.
    <summary>-completed = <summary>-completed + completed.
    <summary>-txn_count = <summary>-txn_count + 1.
  ENDMETHOD.

  METHOD build_entries.
    LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>) TO max_entry_rows.
      APPEND VALUE #(
        transaction_uuid = <row>-transaction_uuid
        execution_date = <row>-execution_date
        worker_id = <row>-report_worker_id
        production_order = <row>-production_order
        operation_no = <row>-operation_no
        plant = <row>-plant
        work_center = <row>-work_center
        transaction_type = <row>-transaction_type
        quantity = <row>-quantity
        uom = <row>-uom
        transaction_status = <row>-transaction_status ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD read_master.
    DATA wanted TYPE RANGE OF zi_pp_workerref-workerid.
    LOOP AT history-workers ASSIGNING FIELD-SYMBOL(<summary>).
      INSERT VALUE #( sign = 'I' option = 'EQ' low = <summary>-worker_id )
        INTO TABLE wanted.
    ENDLOOP.
    LOOP AT history-entries ASSIGNING FIELD-SYMBOL(<entry>).
      INSERT VALUE #( sign = 'I' option = 'EQ' low = <entry>-worker_id )
        INTO TABLE wanted.
    ENDLOOP.
    IF wanted IS INITIAL.
      RETURN.
    ENDIF.
    SORT wanted BY low.
    DELETE ADJACENT DUPLICATES FROM wanted COMPARING low.

    "Master data is read for display only and with no work center filter,
    "so a worker who moved keeps their history. Rows also survive a worker
    "disappearing from the partner table: the name is blank, never the row.
    SELECT FROM zi_pp_workerref
      FIELDS workerid AS worker_id, workername AS worker_name,
             validfrom AS valid_from, validto AS valid_to
      WHERE workerid IN @wanted
      INTO TABLE @result.
  ENDMETHOD.

  METHOD resolve_names.
    DATA(master) = read_master( history ).
    IF master IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT history-workers ASSIGNING FIELD-SYMBOL(<summary>).
      <summary>-worker_name = VALUE #(
        master[ worker_id = <summary>-worker_id ]-worker_name OPTIONAL ).
      LOOP AT master ASSIGNING FIELD-SYMBOL(<summary_master>)
        WHERE worker_id = <summary>-worker_id
          AND valid_from <= history-date_to
          AND valid_to >= history-date_to.
        <summary>-worker_name = <summary_master>-worker_name.
        EXIT.
      ENDLOOP.
    ENDLOOP.
    LOOP AT history-entries ASSIGNING FIELD-SYMBOL(<entry>).
      "Prefer the master record that was valid on the day of the booking, so
      "a renamed worker still reads correctly in old rows.
      <entry>-worker_name = VALUE #(
        master[ worker_id = <entry>-worker_id ]-worker_name OPTIONAL ).
      LOOP AT master ASSIGNING FIELD-SYMBOL(<dated>)
        WHERE worker_id = <entry>-worker_id
          AND valid_from <= <entry>-execution_date
          AND valid_to >= <entry>-execution_date.
        <entry>-worker_name = <dated>-worker_name.
        EXIT.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
