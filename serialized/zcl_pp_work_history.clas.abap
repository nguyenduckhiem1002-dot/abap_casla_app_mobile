"Read model cho lịch sử giao việc/hoàn thành hiển thị trên mobile app.
"Toàn bộ số liệu báo cáo lấy từ transaction data trong ZTB_PP_ALLOC_TXN
"kết hợp với operation tương ứng. ZI_PP_WorkerRef, wrapper của bảng đối tác
"ZTB_KB_NHANCONG, chỉ cung cấp tên nhân công và không dùng để quyết định quyền
"xem row; việc nhân công chuyển Work Center không được làm lịch sử cũ xuất hiện
"hoặc biến mất.
CLASS zcl_pp_work_history DEFINITION
  PUBLIC FINAL CREATE PRIVATE.

  PUBLIC SECTION.
    "Parameter của method không khai báo được LENGTH trực tiếp, nên các mã ngắn
    "được đặt thành named type để tái sử dụng trong signature bên dưới.
    TYPES range_selection TYPE c LENGTH 1.
    TYPES scope_selection TYPE c LENGTH 1.
    TYPES failure_code TYPE c LENGTH 40.

    CONSTANTS:
      range_day    TYPE range_selection VALUE 'D',
      range_week   TYPE range_selection VALUE 'W',
      range_month  TYPE range_selection VALUE 'M',
      range_custom TYPE range_selection VALUE 'C'.
    CONSTANTS:
      "Scope thực tế đã áp dụng được trả lại để app hiển thị đúng nhãn màn hình.
      scope_team TYPE scope_selection VALUE 'T',
      scope_self TYPE scope_selection VALUE 'S'.
    CONSTANTS:
      "Các RBAC function quyết định caller được dùng scope nào.
      func_team TYPE ztb_mob_func-func_id VALUE 'PP_HIST_TEAM',
      func_self TYPE ztb_mob_func-func_id VALUE 'PP_HIST_SELF'.
    CONSTANTS:
      "Cửa sổ mặc định cho mọi role. Custom range có thể lùi xa hơn nhưng độ dài
      "mỗi lần query không được vượt max_custom_days.
      default_days    TYPE i VALUE 30,
      max_custom_days TYPE i VALUE 92,
      "Giới hạn an toàn; chạm scan cap thì result-is_truncated được bật.
      max_scan_rows   TYPE i VALUE 20000,
      max_entry_rows  TYPE i VALUE 1000.

    TYPES: BEGIN OF worker_summary,
             worker_id   TYPE ztb_pp_alloc_txn-worker_id,
             worker_name TYPE zi_pp_workerref-workername,
             work_id     TYPE ztb_mob_work-work_id,
             work_name   TYPE ztb_mob_work-work_name,
             bo_phan     TYPE ztb_mob_work-bo_phan,
             location    TYPE ztb_mob_work-location,
             assigned    TYPE ztb_pp_alloc_txn-quantity,
             transferred_in  TYPE ztb_pp_alloc_txn-quantity,
             transferred_out TYPE ztb_pp_alloc_txn-quantity,
             recalled    TYPE ztb_pp_alloc_txn-quantity,
             completed   TYPE ztb_pp_alloc_txn-quantity,
             remaining   TYPE ztb_pp_alloc_txn-quantity,
             uom         TYPE ztb_pp_alloc_txn-uom,
             txn_count   TYPE i,
           END OF worker_summary,
           worker_summaries TYPE SORTED TABLE OF worker_summary
                            WITH UNIQUE KEY worker_id work_id uom.

    TYPES: BEGIN OF history_entry,
             transaction_uuid   TYPE ztb_pp_alloc_txn-transaction_uuid,
             execution_date     TYPE ztb_pp_alloc_txn-execution_date,
             shift_id TYPE ztb_pp_alloc_txn-shift_id,
             work_date TYPE ztb_pp_alloc_txn-work_date,
             executed_at TYPE ztb_pp_alloc_txn-executed_at,
             shift_start_at TYPE ztb_pp_alloc_txn-shift_start_at,
             shift_end_at TYPE ztb_pp_alloc_txn-shift_end_at,
             shift_time_zone TYPE ztb_pp_alloc_txn-shift_time_zone,
             shift_valid_from TYPE ztb_pp_alloc_txn-shift_valid_from,
             worker_id          TYPE ztb_pp_alloc_txn-worker_id,
             worker_name        TYPE zi_pp_workerref-workername,
             production_order   TYPE ztb_pp_op_alloc-production_order,
             operation_no       TYPE ztb_pp_op_alloc-operation_no,
             operation_name     TYPE string,
             sales_order        TYPE string,
             sales_order_item   TYPE string,
             product            TYPE string,
             product_name      TYPE string,
             plant              TYPE ztb_pp_op_alloc-plant,
             work_center        TYPE ztb_pp_op_alloc-work_center,
             work_id            TYPE ztb_mob_work-work_id,
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
                production_order TYPE ztb_pp_op_alloc-production_order OPTIONAL
                operation_no    TYPE ztb_pp_op_alloc-operation_no OPTIONAL
                shift_id TYPE ztb_pp_shift-shift_id OPTIONAL
                work_id TYPE ztb_mob_work-work_id OPTIONAL
                include_entries TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(result)   TYPE history
      RAISING   cx_abap_message_digest zcx_mob_config.

  PRIVATE SECTION.
    TYPES: BEGIN OF root_key,
             transaction_uuid TYPE ztb_pp_alloc_txn-transaction_uuid,
             worker_id TYPE ztb_pp_alloc_txn-worker_id,
             work_id TYPE ztb_mob_work-work_id,
           END OF root_key,
           root_keys TYPE SORTED TABLE OF root_key
                      WITH UNIQUE KEY transaction_uuid worker_id work_id.
    TYPES: BEGIN OF txn_link,
             transaction_uuid TYPE ztb_pp_alloc_txn-transaction_uuid,
             original_transaction_uuid TYPE ztb_pp_alloc_txn-original_transaction_uuid,
             worker_id TYPE ztb_pp_alloc_txn-worker_id,
             work_id TYPE ztb_mob_work-work_id,
           END OF txn_link,
           txn_links TYPE STANDARD TABLE OF txn_link WITH EMPTY KEY.
    CLASS-METHODS expand_roots
      IMPORTING derived TYPE txn_links
      CHANGING roots TYPE root_keys.

    TYPES: BEGIN OF ledger_row,
             transaction_uuid   TYPE ztb_pp_alloc_txn-transaction_uuid,
             original_transaction_uuid
               TYPE ztb_pp_alloc_txn-original_transaction_uuid,
             execution_date     TYPE ztb_pp_alloc_txn-execution_date,
             shift_id TYPE ztb_pp_alloc_txn-shift_id,
             work_date TYPE ztb_pp_alloc_txn-work_date,
             executed_at TYPE ztb_pp_alloc_txn-executed_at,
             shift_start_at TYPE ztb_pp_alloc_txn-shift_start_at,
             shift_end_at TYPE ztb_pp_alloc_txn-shift_end_at,
             shift_time_zone TYPE ztb_pp_alloc_txn-shift_time_zone,
             shift_valid_from TYPE ztb_pp_alloc_txn-shift_valid_from,
             work_id           TYPE ztb_mob_work-work_id,
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
             ma_congdoan        TYPE ztb_pp_op_alloc-ma_congdoan,
             operation_name     TYPE string,
             sales_order        TYPE string,
             sales_order_item   TYPE string,
             product            TYPE string,
             product_name       TYPE string,
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
           master_rows TYPE SORTED TABLE OF master_row
                       WITH NON-UNIQUE KEY worker_id valid_from.

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
                shift_id TYPE ztb_pp_shift-shift_id
                work_id TYPE ztb_mob_work-work_id OPTIONAL
                production_order TYPE ztb_pp_op_alloc-production_order OPTIONAL
                operation_no TYPE ztb_pp_op_alloc-operation_no OPTIONAL
      RETURNING VALUE(result) TYPE ledger_rows.

    CLASS-METHODS select_team
      IMPORTING user_uuid     TYPE sysuuid_x16
                worker        TYPE ztb_pp_alloc_txn-worker_id
                date_from     TYPE d
                date_to       TYPE d
                shift_id TYPE ztb_pp_shift-shift_id
                work_id TYPE ztb_mob_work-work_id OPTIONAL
                production_order TYPE ztb_pp_op_alloc-production_order OPTIONAL
                operation_no TYPE ztb_pp_op_alloc-operation_no OPTIONAL
      RETURNING VALUE(result) TYPE ledger_rows.

    CLASS-METHODS summarize
      IMPORTING rows          TYPE ledger_rows
      RETURNING VALUE(result) TYPE worker_summaries.

    CLASS-METHODS build_entries
      IMPORTING rows          TYPE ledger_rows
      RETURNING VALUE(result) TYPE history_entries.

    CLASS-METHODS add_quantity
      IMPORTING worker          TYPE ztb_pp_alloc_txn-worker_id
                work_id         TYPE ztb_mob_work-work_id
                uom             TYPE ztb_pp_alloc_txn-uom
                assigned        TYPE ztb_pp_alloc_txn-quantity DEFAULT 0
                transferred_in  TYPE ztb_pp_alloc_txn-quantity DEFAULT 0
                transferred_out TYPE ztb_pp_alloc_txn-quantity DEFAULT 0
                recalled        TYPE ztb_pp_alloc_txn-quantity DEFAULT 0
                completed       TYPE ztb_pp_alloc_txn-quantity DEFAULT 0
      CHANGING  summaries TYPE worker_summaries.

    CLASS-METHODS enrich_work_context
      CHANGING summaries TYPE worker_summaries.

    CLASS-METHODS read_master
      IMPORTING history       TYPE history
      RETURNING VALUE(result) TYPE master_rows.

    CLASS-METHODS resolve_names
      CHANGING history TYPE history.

    CLASS-METHODS enrich_business_details
      CHANGING rows TYPE ledger_rows.
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

    "Scope luôn được suy ra từ RBAC function của caller, không lấy từ dữ liệu
    "device gửi. Supervisor thấy các assignment do mình ghi nhận; người dùng
    "khác chỉ được xem row của chính mình.
    DATA(worker_filter) = worker_id.
    DATA(permissions) = zcl_mob_token_validator=>get_permissions(
      auth-user_uuid ).
    IF line_exists( permissions[ func_id = func_team ] ).
      result-scope_code = scope_team.
    ELSEIF line_exists( permissions[ func_id = func_self ] ).
      result-scope_code = scope_self.
      "Self view bỏ qua worker filter mà caller gửi lên.
      worker_filter = worker_of_account( auth-user_uuid ).
      IF worker_filter IS INITIAL.
        result-error_code = 'WORKER_NOT_MAPPED'.
        RETURN.
      ENDIF.
    ELSE.
      result-error_code = 'MISSING_PERMISSION'.
      RETURN.
    ENDIF.

    IF ( production_order IS INITIAL AND operation_no IS NOT INITIAL )
       OR ( production_order IS NOT INITIAL AND operation_no IS INITIAL ).
      result-error_code = 'OPERATION_FILTER_INCOMPLETE'.
      RETURN.
    ENDIF.

    DATA(history_func) = COND ztb_mob_func-func_id(
      WHEN result-scope_code = scope_team THEN func_team
      ELSE func_self ).
    IF work_id IS NOT INITIAL
       AND zcl_mob_token_validator=>has_func_work_scope(
             user_uuid = auth-user_uuid
             func_id = history_func
             work_id = work_id ) = abap_false.
        result-error_code = 'WORK_CONTEXT_NOT_ALLOWED'.
        RETURN.
    ENDIF.
    IF production_order IS NOT INITIAL AND operation_no IS NOT INITIAL.
      SELECT FROM ztb_pp_op_alloc
        FIELDS plant, work_center
        WHERE production_order = @production_order
          AND operation_no = @operation_no
        INTO TABLE @DATA(operation_scopes).
      IF operation_scopes IS INITIAL.
        result-error_code = 'OPERATION_NOT_FOUND'.
        RETURN.
      ENDIF.
      LOOP AT operation_scopes ASSIGNING FIELD-SYMBOL(<operation_scope>).
        IF zcl_mob_token_validator=>has_func_op_scope(
             user_uuid = auth-user_uuid
             func_id = history_func
             plant = <operation_scope>-plant
             work_center = <operation_scope>-work_center
             work_id = work_id ) = abap_false.
          result-error_code = 'WORK_CONTEXT_NOT_ALLOWED'.
          RETURN.
        ENDIF.
      ENDLOOP.
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
                        date_to = result-date_to shift_id = shift_id
                        work_id = work_id
                        production_order = production_order
                        operation_no = operation_no )
      ELSE select_team( user_uuid = auth-user_uuid
                        worker = worker_filter
                        date_from = result-date_from
                        date_to = result-date_to shift_id = shift_id
                        work_id = work_id
                        production_order = production_order
                        operation_no = operation_no ) ).

    enrich_business_details( CHANGING rows = rows ).

    result-entry_count = lines( rows ).
    result-is_truncated = xsdbool( result-entry_count >= max_scan_rows ).
    result-workers = summarize( rows ).
    enrich_work_context( CHANGING summaries = result-workers ).
    DATA unique_workers TYPE SORTED TABLE OF ztb_pp_alloc_txn-worker_id
                        WITH UNIQUE KEY table_line.
    LOOP AT result-workers INTO DATA(worker_summary_row).
      INSERT worker_summary_row-worker_id INTO TABLE unique_workers.
    ENDLOOP.
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
    "Client không gửi range hoặc gửi code từ app version mới sẽ nhận cửa sổ
    "mặc định theo tháng thay vì một query không giới hạn.
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
          "Vẫn có thể xem kỳ cũ, nhưng một lần gọi không được trải rộng quá số
          "ngày giới hạn này.
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
        "Áp dụng cho range_month và các giá trị đã normalize về range_month ở trên.
        effective_from = today - ( default_days - 1 ).
        effective_to = today.
    ENDCASE.
  ENDMETHOD.

  METHOD worker_of_account.
    "Account lưu WorkerID ở field riêng, cũng là field verify_worker_password dùng
    "để lookup. Field phía account rộng hơn field ledger nên ID không vừa sẽ bị
    "reject thay vì truncate; truncate có thể vô tình trỏ sang lịch sử người khác.
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
             txn~execution_date, txn~shift_id, txn~work_date, txn~executed_at, txn~shift_start_at,
             txn~shift_end_at, txn~shift_time_zone, txn~shift_valid_from, txn~worker_id,
             txn~work_id,
             txn~from_worker_id, txn~to_worker_id, txn~transaction_type,
             txn~quantity, txn~uom, txn~transaction_status,
             op~production_order, op~operation_no, op~ma_congdoan,
             op~plant, op~work_center
      WHERE ( txn~work_date BETWEEN @date_from AND @date_to
           OR ( txn~work_date = '00000000' AND txn~execution_date BETWEEN @date_from AND @date_to ) )
        AND ( @shift_id = ' ' OR txn~shift_id = @shift_id )
        AND ( @work_id = ' ' OR txn~work_id = @work_id )
        AND ( @production_order = ' ' OR op~production_order = @production_order )
        AND ( @operation_no = ' ' OR op~operation_no = @operation_no )
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
    "Bước 1: lấy các assignment supervisor này đã ghi nhận. Scope được đóng băng
    "trong ledger: row thuộc scope vì supervisor đã book assignment, không phải
    "vì Work Center hiện tại trong master data. Nhân công chuyển team vẫn còn
    "xuất hiện trong lịch sử của team cũ.
    SELECT DISTINCT txn~transaction_uuid, txn~operation_uuid, txn~worker_id,
                    txn~from_worker_id, txn~to_worker_id, txn~work_id
      FROM ztb_pp_alloc_txn AS txn
      INNER JOIN ztb_pp_op_alloc AS op
        ON op~operation_uuid = txn~operation_uuid
      WHERE txn~actor_user_uuid = @user_uuid
        AND txn~transaction_type IN ( @zcl_pp_txn_type=>initial_assign,
                                  @zcl_pp_txn_type=>transfer )
        AND txn~transaction_status = @zcl_pp_txn_type=>posted
        AND ( txn~work_date <= @date_to AND txn~work_date <> '00000000'
           OR ( txn~work_date = '00000000' AND txn~execution_date <= @date_to ) )
        AND ( @work_id = ' ' OR txn~work_id = @work_id )
        AND ( @production_order = ' ' OR op~production_order = @production_order )
        AND ( @operation_no = ' ' OR op~operation_no = @operation_no )
        AND ( @worker = ' '
           OR txn~worker_id = @worker
           OR txn~from_worker_id = @worker
           OR txn~to_worker_id = @worker )
      INTO TABLE @DATA(booked).
    IF booked IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF scope_key,
             operation_uuid TYPE ztb_pp_alloc_txn-operation_uuid,
             worker_id      TYPE ztb_pp_alloc_txn-worker_id,
             work_id        TYPE ztb_mob_work-work_id,
           END OF scope_key.
    DATA scope TYPE SORTED TABLE OF scope_key
               WITH UNIQUE KEY operation_uuid worker_id.
    DATA roots TYPE root_keys.
    LOOP AT booked ASSIGNING FIELD-SYMBOL(<booked>).
      IF <booked>-worker_id IS NOT INITIAL.
        INSERT VALUE #( operation_uuid = <booked>-operation_uuid
                        worker_id = <booked>-worker_id
                        work_id = <booked>-work_id ) INTO TABLE scope.
        INSERT VALUE #( transaction_uuid = <booked>-transaction_uuid
                        worker_id = <booked>-worker_id
                        work_id = <booked>-work_id ) INTO TABLE roots.
      ENDIF.
      IF <booked>-from_worker_id IS NOT INITIAL.
        INSERT VALUE #( operation_uuid = <booked>-operation_uuid
                        worker_id = <booked>-from_worker_id
                        work_id = <booked>-work_id ) INTO TABLE scope.
        INSERT VALUE #( transaction_uuid = <booked>-transaction_uuid
                        worker_id = <booked>-from_worker_id
                        work_id = <booked>-work_id ) INTO TABLE roots.
      ENDIF.
      IF <booked>-to_worker_id IS NOT INITIAL.
        INSERT VALUE #( operation_uuid = <booked>-operation_uuid
                        worker_id = <booked>-to_worker_id
                        work_id = <booked>-work_id ) INTO TABLE scope.
        INSERT VALUE #( transaction_uuid = <booked>-transaction_uuid
                        worker_id = <booked>-to_worker_id
                        work_id = <booked>-work_id ) INTO TABLE roots.
      ENDIF.
    ENDLOOP.
    IF worker IS NOT INITIAL.
      DELETE scope WHERE worker_id <> worker.
    ENDIF.
    IF scope IS INITIAL.
      RETURN.
    ENDIF.

    "Include derived corrections/reversals by following the original receipt chain.
    SELECT FROM @scope AS scope_row
      INNER JOIN ztb_pp_alloc_txn AS txn
        ON txn~operation_uuid = scope_row~operation_uuid
       AND txn~worker_id = scope_row~worker_id
       AND txn~work_id = scope_row~work_id
      FIELDS DISTINCT txn~transaction_uuid, txn~original_transaction_uuid,
             txn~worker_id, txn~work_id
      WHERE txn~transaction_status = @zcl_pp_txn_type=>posted
      INTO TABLE @DATA(derived)
      ##itab_db_select.
    expand_roots( EXPORTING derived = derived CHANGING roots = roots ).

    "Bước 2: lấy mọi POSTED row của các cặp operation/worker trong scope, gồm cả
    "CONFIRM do worker ghi sau đó. Nếu thiếu các row này thì cột progress sẽ trống
    "đối với supervisor chỉ thực hiện assignment.
    SELECT FROM @scope AS scope_row
      INNER JOIN ztb_pp_alloc_txn AS txn
        ON txn~operation_uuid = scope_row~operation_uuid
       AND txn~work_id = scope_row~work_id
       AND ( txn~worker_id = scope_row~worker_id
          OR txn~from_worker_id = scope_row~worker_id
          OR txn~to_worker_id = scope_row~worker_id )
      INNER JOIN ztb_pp_op_alloc AS op
        ON op~operation_uuid = txn~operation_uuid
      FIELDS txn~transaction_uuid, txn~original_transaction_uuid,
             txn~operation_uuid, txn~execution_date, txn~shift_id, txn~work_date, txn~executed_at,
             txn~shift_start_at, txn~shift_end_at, txn~shift_time_zone, txn~shift_valid_from, txn~worker_id,
             txn~work_id,
             txn~from_worker_id, txn~to_worker_id, txn~transaction_type,
             txn~quantity, txn~uom, txn~transaction_status,
             op~production_order, op~operation_no, op~ma_congdoan,
             op~plant, op~work_center,
             scope_row~worker_id AS report_worker_id
      WHERE ( txn~work_date BETWEEN @date_from AND @date_to
           OR ( txn~work_date = '00000000' AND txn~execution_date BETWEEN @date_from AND @date_to ) )
        AND ( @shift_id = ' ' OR txn~shift_id = @shift_id )
        AND ( @work_id = ' ' OR txn~work_id = @work_id )
        AND ( @production_order = ' ' OR op~production_order = @production_order )
        AND ( @operation_no = ' ' OR op~operation_no = @operation_no )
        AND txn~transaction_status = @zcl_pp_txn_type=>posted
      INTO TABLE @DATA(candidates)
      UP TO @max_scan_rows ROWS
      ##itab_db_select.
    LOOP AT candidates ASSIGNING FIELD-SYMBOL(<candidate>).
      "Điều chỉnh phân bổ do admin tạo không có root assignment của supervisor;
      "scope operation/worker đã được xác lập ở bước 1 nên vẫn phải đưa row này
      "vào báo cáo team để số giao và số còn lại phản ánh đúng snapshot.
      IF <candidate>-transaction_type = zcl_pp_txn_type=>allocation_adjustment
         OR <candidate>-transaction_type = zcl_pp_txn_type=>recall_adjustment
         OR <candidate>-transaction_type = zcl_pp_txn_type=>confirm_adjustment.
        APPEND CORRESPONDING #( <candidate> ) TO result.
        CONTINUE.
      ENDIF.
        IF NOT line_exists( roots[
           transaction_uuid = <candidate>-transaction_uuid
           worker_id = <candidate>-report_worker_id
           work_id = <candidate>-work_id ] )
         AND NOT line_exists( roots[
           transaction_uuid = <candidate>-original_transaction_uuid
           worker_id = <candidate>-report_worker_id
           work_id = <candidate>-work_id ] ).
        "Derived row phải trỏ về root assignment/transfer. Rule này ngăn booking
        "của supervisor khác trên cùng operation/worker lọt vào số liệu hiện tại.
        CONTINUE.
      ENDIF.
      APPEND CORRESPONDING #( <candidate> ) TO result.
    ENDLOOP.
    SORT result BY execution_date DESCENDING transaction_uuid report_worker_id.
  ENDMETHOD.

  METHOD expand_roots.
    DATA(expanded) = abap_true.
    WHILE expanded = abap_true.
      expanded = abap_false.
      LOOP AT derived INTO DATA(child).
        IF line_exists( roots[ transaction_uuid = child-original_transaction_uuid
                               worker_id = child-worker_id
                               work_id = child-work_id ] )
           AND NOT line_exists( roots[ transaction_uuid = child-transaction_uuid
                                       worker_id = child-worker_id
                                       work_id = child-work_id ] ).
          INSERT VALUE #( transaction_uuid = child-transaction_uuid
                          worker_id = child-worker_id
                          work_id = child-work_id ) INTO TABLE roots.
          expanded = abap_true.
        ENDIF.
      ENDLOOP.
    ENDWHILE.
  ENDMETHOD.

  METHOD summarize.
    LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).
      CASE <row>-transaction_type.
        WHEN zcl_pp_txn_type=>initial_assign.
          IF <row>-worker_id <> <row>-report_worker_id.
            CONTINUE.
          ENDIF.
          add_quantity( EXPORTING worker = <row>-report_worker_id
                                  work_id = <row>-work_id
                                  uom = <row>-uom
                                  assigned = <row>-quantity
                        CHANGING summaries = result ).
        WHEN zcl_pp_txn_type=>transfer.
          IF <row>-to_worker_id = <row>-report_worker_id.
            add_quantity( EXPORTING worker = <row>-report_worker_id
                                    work_id = <row>-work_id
                                    uom = <row>-uom
                                    transferred_in = <row>-quantity
                          CHANGING summaries = result ).
          ENDIF.
          IF <row>-from_worker_id = <row>-report_worker_id.
            add_quantity( EXPORTING worker = <row>-report_worker_id
                                    work_id = <row>-work_id
                                    uom = <row>-uom
                                    transferred_out = <row>-quantity
                          CHANGING summaries = result ).
          ENDIF.
        WHEN zcl_pp_txn_type=>recall.
          IF <row>-worker_id <> <row>-report_worker_id.
            CONTINUE.
          ENDIF.
          add_quantity( EXPORTING worker = <row>-report_worker_id
                                  work_id = <row>-work_id
                                  uom = <row>-uom
                                  recalled = <row>-quantity
                        CHANGING summaries = result ).
        WHEN zcl_pp_txn_type=>confirm OR zcl_pp_txn_type=>correction.
          IF <row>-worker_id <> <row>-report_worker_id.
            CONTINUE.
          ENDIF.
          add_quantity( EXPORTING worker = <row>-report_worker_id
                                  work_id = <row>-work_id
                                  uom = <row>-uom
                                  completed = <row>-quantity
                        CHANGING summaries = result ).
        WHEN zcl_pp_txn_type=>reverse.
          IF <row>-worker_id <> <row>-report_worker_id.
            CONTINUE.
          ENDIF.
          add_quantity( EXPORTING worker = <row>-report_worker_id
                                  work_id = <row>-work_id
                                  uom = <row>-uom
                                  completed = <row>-quantity * -1
                        CHANGING summaries = result ).
        WHEN zcl_pp_txn_type=>allocation_adjustment.
          IF <row>-worker_id <> <row>-report_worker_id.
            CONTINUE.
          ENDIF.
          add_quantity( EXPORTING worker = <row>-report_worker_id
                                  work_id = <row>-work_id
                                  uom = <row>-uom
                                  assigned = <row>-quantity
                        CHANGING summaries = result ).
        WHEN zcl_pp_txn_type=>recall_adjustment.
          IF <row>-worker_id <> <row>-report_worker_id.
            CONTINUE.
          ENDIF.
          add_quantity( EXPORTING worker = <row>-report_worker_id
                                  work_id = <row>-work_id
                                  uom = <row>-uom
                                  recalled = <row>-quantity
                        CHANGING summaries = result ).
        WHEN zcl_pp_txn_type=>confirm_adjustment.
          IF <row>-worker_id <> <row>-report_worker_id.
            CONTINUE.
          ENDIF.
          add_quantity( EXPORTING worker = <row>-report_worker_id
                                  work_id = <row>-work_id
                                  uom = <row>-uom
                                  completed = <row>-quantity
                        CHANGING summaries = result ).
        WHEN OTHERS.
          "Transaction type chưa biết vẫn được tính số transaction nhưng không cộng
          "quantity, để thêm type mới sau này không âm thầm làm sai số liệu.
          add_quantity( EXPORTING worker = <row>-report_worker_id
                                  work_id = <row>-work_id
                                  uom = <row>-uom
                        CHANGING summaries = result ).
      ENDCASE.
    ENDLOOP.
    LOOP AT result ASSIGNING FIELD-SYMBOL(<summary>).
      <summary>-remaining = <summary>-assigned
                          + <summary>-transferred_in
                          - <summary>-transferred_out
                          - <summary>-recalled
                          - <summary>-completed.
    ENDLOOP.
  ENDMETHOD.

  METHOD add_quantity.
    IF worker IS INITIAL.
      RETURN.
    ENDIF.
    ASSIGN summaries[ worker_id = worker work_id = work_id uom = uom ]
      TO FIELD-SYMBOL(<summary>).
    IF sy-subrc <> 0.
      INSERT VALUE #( worker_id = worker work_id = work_id uom = uom ) INTO TABLE summaries
        ASSIGNING <summary>.
    ENDIF.
    <summary>-assigned = <summary>-assigned + assigned.
    <summary>-transferred_in = <summary>-transferred_in + transferred_in.
    <summary>-transferred_out = <summary>-transferred_out + transferred_out.
    <summary>-recalled = <summary>-recalled + recalled.
    <summary>-completed = <summary>-completed + completed.
    <summary>-txn_count = <summary>-txn_count + 1.
  ENDMETHOD.

  METHOD enrich_work_context.
    DATA wanted TYPE RANGE OF ztb_mob_work-work_id.
    LOOP AT summaries ASSIGNING FIELD-SYMBOL(<summary>)
      WHERE work_id IS NOT INITIAL.
      INSERT VALUE #( sign = 'I' option = 'EQ' low = <summary>-work_id )
        INTO TABLE wanted.
    ENDLOOP.
    IF wanted IS INITIAL.
      RETURN.
    ENDIF.
    SORT wanted BY low.
    DELETE ADJACENT DUPLICATES FROM wanted COMPARING low.

    SELECT FROM ztb_mob_work
      FIELDS work_id, work_name, bo_phan, location
      WHERE work_id IN @wanted
      INTO TABLE @DATA(contexts).

    LOOP AT summaries ASSIGNING <summary>.
      DATA(context) = VALUE #( contexts[ work_id = <summary>-work_id ] OPTIONAL ).
      <summary>-work_name = context-work_name.
      <summary>-bo_phan = context-bo_phan.
      <summary>-location = context-location.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_entries.
    LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>) TO max_entry_rows.
      APPEND VALUE #(
        transaction_uuid = <row>-transaction_uuid
        execution_date = <row>-execution_date
        shift_id = <row>-shift_id
        work_date = COND #( WHEN <row>-work_date IS INITIAL THEN <row>-execution_date ELSE <row>-work_date )
        executed_at = <row>-executed_at
        shift_start_at = <row>-shift_start_at
        shift_end_at = <row>-shift_end_at
        shift_time_zone = <row>-shift_time_zone
        shift_valid_from = <row>-shift_valid_from
        worker_id = <row>-report_worker_id
        production_order = <row>-production_order
        operation_no = <row>-operation_no
        operation_name = <row>-operation_name
        sales_order = <row>-sales_order
        sales_order_item = <row>-sales_order_item
        product = <row>-product
        product_name = <row>-product_name
        plant = <row>-plant
        work_center = <row>-work_center
        work_id = <row>-work_id
        transaction_type = <row>-transaction_type
        quantity = <row>-quantity
        uom = <row>-uom
        transaction_status = <row>-transaction_status ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD enrich_business_details.
    "Lấy các khóa duy nhất trước để tránh SELECT lặp lại cho từng dòng ledger.
    TYPES: BEGIN OF order_key,
             production_order TYPE ztb_pp_op_alloc-production_order,
           END OF order_key,
           order_keys TYPE SORTED TABLE OF order_key
                       WITH UNIQUE KEY production_order.
    TYPES: BEGIN OF product_key,
             product TYPE c LENGTH 40,
           END OF product_key,
           product_keys TYPE SORTED TABLE OF product_key
                        WITH UNIQUE KEY product.
    TYPES: BEGIN OF order_detail,
             production_order TYPE ztb_pp_op_alloc-production_order,
             sales_order      TYPE c LENGTH 10,
             sales_order_item TYPE c LENGTH 6,
             product          TYPE c LENGTH 40,
           END OF order_detail,
           order_details TYPE STANDARD TABLE OF order_detail WITH EMPTY KEY.
    TYPES: BEGIN OF product_detail,
             product      TYPE c LENGTH 40,
             product_name TYPE string,
           END OF product_detail,
           product_details TYPE STANDARD TABLE OF product_detail WITH EMPTY KEY.
    TYPES: BEGIN OF operation_detail,
             ma_congdoan    TYPE ztb_pp_op_alloc-ma_congdoan,
             valid_from     TYPE d,
             valid_to       TYPE d,
             operation_name TYPE string,
           END OF operation_detail,
           operation_details TYPE STANDARD TABLE OF operation_detail WITH EMPTY KEY.

    IF rows IS INITIAL.
      RETURN.
    ENDIF.

    DATA order_keys TYPE order_keys.
    DATA product_keys TYPE product_keys.
    DATA operation_codes TYPE RANGE OF ztb_pp_op_alloc-ma_congdoan.

    LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).
      IF <row>-production_order IS NOT INITIAL.
        INSERT VALUE #( production_order = <row>-production_order )
          INTO TABLE order_keys.
      ENDIF.
      IF <row>-ma_congdoan IS NOT INITIAL.
        INSERT VALUE #( sign = 'I' option = 'EQ' low = <row>-ma_congdoan )
          INTO TABLE operation_codes.
      ENDIF.
    ENDLOOP.
    SORT operation_codes BY low.
    DELETE ADJACENT DUPLICATES FROM operation_codes COMPARING low.

    DATA order_details TYPE order_details.
    IF order_keys IS NOT INITIAL.
      "I_ManufacturingOrder cung cấp product và liên kết sales order của LSX.
      SELECT FROM @order_keys AS order_key
        INNER JOIN I_ManufacturingOrder AS order_header
          ON order_header~ManufacturingOrder = order_key~production_order
        FIELDS order_key~production_order AS production_order,
               order_header~SalesOrder AS sales_order,
               order_header~SalesOrderItem AS sales_order_item,
               order_header~Product AS product
        INTO TABLE @order_details
        ##itab_db_select.

      LOOP AT order_details ASSIGNING FIELD-SYMBOL(<order_detail>).
        IF <order_detail>-product IS NOT INITIAL.
          INSERT VALUE #( product = <order_detail>-product )
            INTO TABLE product_keys.
        ENDIF.
      ENDLOOP.
    ENDIF.

    DATA product_details TYPE product_details.
    IF product_keys IS NOT INITIAL.
      "Text sản phẩm được đọc theo ngôn ngữ đăng nhập để hiển thị trên app.
      SELECT FROM @product_keys AS product_key
        INNER JOIN I_ProductText AS product_text
          ON product_text~Product = product_key~product
        FIELDS product_key~product AS product,
               product_text~ProductName AS product_name
        WHERE product_text~Language = @sy-langu
        INTO TABLE @product_details
        ##itab_db_select.
    ENDIF.

    DATA operation_details TYPE operation_details.
    IF operation_codes IS NOT INITIAL.
      "Tên công đoạn của ứng dụng được quản lý theo phiên bản hiệu lực nội bộ.
      SELECT FROM ZI_MD_CongDoan AS operation_master
        FIELDS operation_master~MaCongDoan AS ma_congdoan,
               operation_master~ValidFrom AS valid_from,
               operation_master~ValidTo AS valid_to,
               operation_master~TenCongDoan AS operation_name
        WHERE operation_master~MaCongDoan IN @operation_codes
        ORDER BY operation_master~ValidFrom DESCENDING
        INTO TABLE @operation_details.
    ENDIF.

    LOOP AT rows ASSIGNING <row>.
      DATA(order_info) = VALUE order_detail(
        order_details[ production_order = <row>-production_order ] OPTIONAL ).
      <row>-sales_order = order_info-sales_order.
      <row>-sales_order_item = order_info-sales_order_item.
      <row>-product = order_info-product.
      IF <row>-product IS NOT INITIAL.
        READ TABLE product_details ASSIGNING FIELD-SYMBOL(<product_info>)
          WITH KEY product = <row>-product.
        IF sy-subrc = 0.
          <row>-product_name = <product_info>-product_name.
        ENDIF.
      ENDIF.

      DATA(reference_date) = COND d(
        WHEN <row>-work_date IS INITIAL
        THEN <row>-execution_date
        ELSE <row>-work_date ).
      LOOP AT operation_details ASSIGNING FIELD-SYMBOL(<operation_detail>)
        WHERE ma_congdoan = <row>-ma_congdoan
          AND valid_from <= reference_date
          AND valid_to >= reference_date.
        <row>-operation_name = <operation_detail>-operation_name.
        EXIT.
      ENDLOOP.
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

    "Master data chỉ dùng để hiển thị và không filter theo Work Center để nhân công
    "đã chuyển chỗ vẫn giữ lịch sử. Nếu nhân công biến mất khỏi bảng đối tác thì
    "row lịch sử vẫn tồn tại, chỉ tên hiển thị bị trống.
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
      "Ưu tiên master record có hiệu lực đúng ngày booking để tên cũ vẫn hiển thị
      "chính xác trên các row lịch sử khi nhân công đã được đổi tên.
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
