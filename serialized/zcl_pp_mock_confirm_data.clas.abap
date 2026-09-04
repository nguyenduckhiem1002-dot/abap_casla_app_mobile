" Seed du lieu demo lich su san luong cho hai mobile user co san.
CLASS zcl_pp_mock_confirm_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    CONSTANTS:
      manager_username TYPE ztb_mob_user-normalized_username
        VALUE 'manager_67310035',
      operator_username TYPE ztb_mob_user-normalized_username VALUE 'duck',
      manager_role TYPE ztb_mob_role-role_id VALUE 'PP_MANAGER',
      operator_role TYPE ztb_mob_role-role_id VALUE 'PP_OPERATOR',
      function_assign TYPE ztb_mob_func-func_id VALUE 'PP_INITIAL_ASSIGN',
      function_team TYPE ztb_mob_func-func_id VALUE 'PP_HIST_TEAM',
      function_self TYPE ztb_mob_func-func_id VALUE 'PP_HIST_SELF',
      demo_order TYPE ztb_pp_op_alloc-production_order VALUE 'DEMO00000001',
      demo_operation TYPE ztb_pp_op_alloc-operation_no VALUE '0010',
      demo_process TYPE ztb_pp_op_alloc-ma_congdoan VALUE 'DEMO001',
      "ST la ma UoM noi bo SAP cho piece; Gateway V4 serialize thanh PCE.
      demo_uom TYPE ztb_pp_op_alloc-uom VALUE 'ST'.

    TYPES:
      BEGIN OF user_context,
        user_uuid TYPE ztb_mob_user-user_uuid,
        username TYPE ztb_mob_user-username,
        worker_id TYPE ztb_mob_user-worker_id,
      END OF user_context,
      BEGIN OF work_context,
        plant TYPE ztb_mob_work-plant,
        work_center TYPE ztb_mob_work-workcenter,
        work_id TYPE ztb_mob_work-work_id,
      END OF work_context,
      BEGIN OF seed_result,
        success TYPE abap_bool,
        created TYPE abap_bool,
        message TYPE string,
        operation_uuid TYPE ztb_pp_op_alloc-operation_uuid,
      END OF seed_result.

    CLASS-METHODS read_user
      IMPORTING normalized_username
                  TYPE ztb_mob_user-normalized_username
      RETURNING VALUE(user) TYPE user_context.

    CLASS-METHODS determine_work_context
      IMPORTING worker_id TYPE ztb_mob_user-worker_id
      RETURNING VALUE(context) TYPE work_context.

    CLASS-METHODS ensure_function
      IMPORTING func_id TYPE ztb_mob_func-func_id
                func_name TYPE ztb_mob_func-func_name
      RETURNING VALUE(success) TYPE abap_bool.

    CLASS-METHODS ensure_role
      IMPORTING role_id TYPE ztb_mob_role-role_id
                role_name TYPE ztb_mob_role-role_name
      RETURNING VALUE(success) TYPE abap_bool.

    CLASS-METHODS ensure_work
      IMPORTING context TYPE work_context
      RETURNING VALUE(success) TYPE abap_bool.

    CLASS-METHODS ensure_role_grant
      IMPORTING role_id TYPE ztb_mob_rol_fnc-role_id
                func_id TYPE ztb_mob_rol_fnc-func_id
      RETURNING VALUE(success) TYPE abap_bool.

    CLASS-METHODS ensure_role_work
      IMPORTING role_id TYPE ztb_mob_rol_wrk-role_id
                work_id TYPE ztb_mob_rol_wrk-work_id
      RETURNING VALUE(success) TYPE abap_bool.

    CLASS-METHODS ensure_user_role
      IMPORTING user_uuid TYPE ztb_mob_usr_rol-user_uuid
                role_id TYPE ztb_mob_usr_rol-role_id
      RETURNING VALUE(success) TYPE abap_bool.

    CLASS-METHODS ensure_demo_access
      IMPORTING manager TYPE user_context
                operator TYPE user_context
                context TYPE work_context
      RETURNING VALUE(success) TYPE abap_bool.

    CLASS-METHODS seed_production
      IMPORTING manager TYPE user_context
                operator TYPE user_context
                context TYPE work_context
      RETURNING VALUE(result) TYPE seed_result.

    CLASS-METHODS delete_demo_data
      RETURNING VALUE(success) TYPE abap_bool.
ENDCLASS.

CLASS zcl_pp_mock_confirm_data IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DATA(manager) = read_user( manager_username ).
    DATA(operator) = read_user( operator_username ).
    IF manager-user_uuid IS INITIAL OR operator-user_uuid IS INITIAL.
      out->write( 'Khong tim thay du hai user active: manager_67310035 va duck' ).
      RETURN.
    ENDIF.
    IF manager-worker_id IS INITIAL OR operator-worker_id IS INITIAL.
      out->write( 'Ca hai user phai co WorkerID truoc khi seed demo' ).
      RETURN.
    ENDIF.

    DATA(context) = determine_work_context( operator-worker_id ).
    IF ensure_demo_access( manager = manager
                           operator = operator
                           context = context ) = abap_false.
      out->write( 'Khong tao duoc role, function hoac Work ID demo' ).
      RETURN.
    ENDIF.

    DATA(result) = seed_production( manager = manager
                                    operator = operator
                                    context = context ).
    out->write( result-message ).
    IF result-success = abap_false.
      RETURN.
    ENDIF.
    out->write( |Work ID: { context-work_id }| ).
    out->write( |Lenh / cong doan: { demo_order } / { demo_operation }| ).
    out->write( |Operation UUID: { result-operation_uuid }| ).
    out->write( |Quan ly { manager-username } ({ manager-worker_id }) giao viec| ).
    out->write( |Nhan cong { operator-username } ({ operator-worker_id }): giao 100 ST, da lam 25 ST, con 75 ST| ).
    out->write( 'Manager xem team history; duck xem self history trong ngay hien tai.' ).
  ENDMETHOD.

  METHOD read_user.
    SELECT FROM ztb_mob_user
      FIELDS user_uuid, username, worker_id
      WHERE normalized_username = @normalized_username
        AND status = 'A'
      INTO TABLE @DATA(users)
      UP TO 2 ROWS.
    IF lines( users ) = 1.
      user = CORRESPONDING #( users[ 1 ] ).
    ENDIF.
  ENDMETHOD.

  METHOD determine_work_context.
    DATA(today) = cl_abap_context_info=>get_system_date( ).
    SELECT FROM zi_pp_workerref
      FIELDS Plant, WorkCenter
      WHERE WorkerID = @worker_id
        AND ValidFrom <= @today
        AND ValidTo >= @today
      ORDER BY ValidFrom DESCENDING
      INTO TABLE @DATA(worker_locations)
      UP TO 1 ROWS.
    IF worker_locations IS INITIAL.
      context-plant = 'D001'.
      context-work_center = 'DEMO001'.
    ELSE.
      context-plant = worker_locations[ 1 ]-Plant.
      context-work_center = worker_locations[ 1 ]-WorkCenter.
    ENDIF.
    context-work_id = CONV #( |DEMO_{ context-plant }_{ context-work_center }| ).
  ENDMETHOD.

  METHOD ensure_function.
    SELECT FROM ztb_mob_func
      FIELDS func_id
      WHERE func_id = @func_id
      INTO TABLE @DATA(existing)
      UP TO 1 ROWS.
    IF existing IS NOT INITIAL.
      success = abap_true.
      RETURN.
    ENDIF.
    GET TIME STAMP FIELD DATA(now).
    INSERT ztb_mob_func FROM @( VALUE #(
      func_id = func_id
      func_name = func_name
      app_module = 'PP'
      last_changed_at = now
      local_last_changed_at = now ) ).
    success = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD ensure_role.
    SELECT FROM ztb_mob_role
      FIELDS status
      WHERE role_id = @role_id
      INTO TABLE @DATA(existing)
      UP TO 1 ROWS.
    IF existing IS NOT INITIAL.
      success = xsdbool( existing[ 1 ]-status = 'A' ).
      RETURN.
    ENDIF.
    GET TIME STAMP FIELD DATA(now).
    DATA(current_user) = cl_abap_context_info=>get_user_technical_name( ).
    INSERT ztb_mob_role FROM @( VALUE #(
      role_id = role_id
      role_name = role_name
      status = 'A'
      created_by = current_user
      created_at = now
      last_changed_by = current_user
      last_changed_at = now
      local_last_changed_at = now ) ).
    success = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD ensure_work.
    SELECT FROM ztb_mob_work
      FIELDS plant, workcenter, is_active
      WHERE work_id = @context-work_id
      INTO TABLE @DATA(existing)
      UP TO 1 ROWS.
    IF existing IS NOT INITIAL.
      success = xsdbool( existing[ 1 ]-plant = context-plant
        AND existing[ 1 ]-workcenter = context-work_center
        AND existing[ 1 ]-is_active = 'A' ).
      RETURN.
    ENDIF.
    GET TIME STAMP FIELD DATA(now).
    INSERT ztb_mob_work FROM @( VALUE #(
      work_id = context-work_id
      work_name = |Demo san luong { context-plant }/{ context-work_center }|
      plant = context-plant
      workcenter = context-work_center
      bo_phan = 'PP'
      location = |Plant { context-plant }|
      is_active = 'A'
      last_changed_at = now
      local_last_changed_at = now ) ).
    success = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD ensure_role_grant.
    SELECT FROM ztb_mob_rol_fnc
      FIELDS role_id
      WHERE role_id = @role_id
        AND func_id = @func_id
      INTO TABLE @DATA(existing)
      UP TO 1 ROWS.
    IF existing IS NOT INITIAL.
      success = abap_true.
      RETURN.
    ENDIF.
    INSERT ztb_mob_rol_fnc FROM @( VALUE #(
      role_id = role_id func_id = func_id ) ).
    success = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD ensure_role_work.
    SELECT FROM ztb_mob_rol_wrk
      FIELDS role_id
      WHERE role_id = @role_id
        AND work_id = @work_id
      INTO TABLE @DATA(existing)
      UP TO 1 ROWS.
    IF existing IS NOT INITIAL.
      success = abap_true.
      RETURN.
    ENDIF.
    INSERT ztb_mob_rol_wrk FROM @( VALUE #(
      role_id = role_id work_id = work_id ) ).
    success = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD ensure_user_role.
    SELECT FROM ztb_mob_usr_rol
      FIELDS user_uuid
      WHERE user_uuid = @user_uuid
        AND role_id = @role_id
      INTO TABLE @DATA(existing)
      UP TO 1 ROWS.
    IF existing IS NOT INITIAL.
      success = abap_true.
      RETURN.
    ENDIF.
    INSERT ztb_mob_usr_rol FROM @( VALUE #(
      user_uuid = user_uuid role_id = role_id ) ).
    success = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD ensure_demo_access.
    success = ensure_function(
      func_id = function_assign func_name = 'Giao san luong ban dau' ).
    IF success = abap_false.
      RETURN.
    ENDIF.
    success = ensure_function(
      func_id = function_team func_name = 'Xem lich su cua doi' ).
    IF success = abap_false.
      RETURN.
    ENDIF.
    success = ensure_function(
      func_id = function_self func_name = 'Xem lich su ca nhan' ).
    IF success = abap_false OR ensure_work( context ) = abap_false.
      success = abap_false.
      RETURN.
    ENDIF.
    success = ensure_role(
      role_id = manager_role role_name = 'Quan ly san xuat' ).
    IF success = abap_false.
      RETURN.
    ENDIF.
    success = ensure_role(
      role_id = operator_role role_name = 'Nhan vien san xuat' ).
    IF success = abap_false.
      RETURN.
    ENDIF.

    success = ensure_role_grant( role_id = manager_role
                                 func_id = function_assign ).
    success = xsdbool( success = abap_true AND
      ensure_role_grant( role_id = manager_role
                         func_id = function_team ) = abap_true ).
    success = xsdbool( success = abap_true AND
      ensure_role_grant( role_id = manager_role
                         func_id = function_self ) = abap_true ).
    success = xsdbool( success = abap_true AND
      ensure_role_grant( role_id = operator_role
                         func_id = function_self ) = abap_true ).
    success = xsdbool( success = abap_true AND
      ensure_role_work( role_id = manager_role
                        work_id = context-work_id ) = abap_true ).
    success = xsdbool( success = abap_true AND
      ensure_role_work( role_id = operator_role
                        work_id = context-work_id ) = abap_true ).
    success = xsdbool( success = abap_true AND
      ensure_user_role( user_uuid = manager-user_uuid
                        role_id = manager_role ) = abap_true ).
    success = xsdbool( success = abap_true AND
      ensure_user_role( user_uuid = operator-user_uuid
                        role_id = operator_role ) = abap_true ).
  ENDMETHOD.

  METHOD seed_production.
    IF delete_demo_data( ) = abap_false.
      result-message = 'Khong xoa sach duoc bo du lieu demo cu'.
      RETURN.
    ENDIF.

    TRY.
        DATA(operation_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(operator_balance_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(assign_operator_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(confirm_operator_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(sync_assign_operator) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(sync_confirm_operator) = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        result-message = 'Khong tao duoc UUID cho du lieu demo'.
        RETURN.
    ENDTRY.

    GET TIME STAMP FIELD DATA(now).
    DATA(now_utc) = utclong_current( ).
    DATA(today) = cl_abap_context_info=>get_system_date( ).
    DATA(current_user) = cl_abap_context_info=>get_user_technical_name( ).
    DATA(operation) = VALUE ztb_pp_op_alloc(
      operation_uuid = operation_uuid
      production_order = demo_order
      operation_no = demo_operation
      ma_congdoan = demo_process
      plant = context-plant
      work_center = context-work_center
      operation_qty = '100.000'
      uom = demo_uom
      operation_status = 'REL'
      created_by = current_user
      created_at = now
      last_changed_by = current_user
      local_last_changed_at = now ).
    INSERT ztb_pp_op_alloc FROM @operation.
    IF sy-subrc <> 0.
      result-message = 'Khong insert duoc operation demo'.
      RETURN.
    ENDIF.

    DATA balances TYPE STANDARD TABLE OF ztb_pp_emp_alloc WITH EMPTY KEY.
    balances = VALUE #(
      ( emp_alloc_uuid = operator_balance_uuid
        operation_uuid = operation_uuid
        worker_id = operator-worker_id
        initial_assigned_qty = '100.000'
        completed_qty = '25.000'
        remaining_qty = '75.000'
        uom = demo_uom
        last_execution_date = today
        last_sync_at = now_utc
        created_by = current_user
        created_at = now
        last_changed_by = current_user
        local_last_changed_at = now ) ).
    INSERT ztb_pp_emp_alloc FROM TABLE @balances.
    IF sy-subrc <> 0.
      result-message = 'Da tao operation nhung khong insert duoc balance demo'.
      RETURN.
    ENDIF.

    DATA transactions TYPE STANDARD TABLE OF ztb_pp_alloc_txn WITH EMPTY KEY.
    transactions = VALUE #(
      ( transaction_uuid = assign_operator_uuid
        operation_uuid = operation_uuid
        sync_item_uuid = sync_assign_operator
        actor_user_uuid = manager-user_uuid
        verified_worker_user_uuid = operator-user_uuid
        worker_verified_at = now_utc
        device_id = 'ADT-DEMO-SEED'
        verification_method = 'SEED'
        transaction_type = zcl_pp_txn_type=>initial_assign
        to_worker_id = operator-worker_id
        worker_id = operator-worker_id
        quantity = '100.000'
        uom = demo_uom
        execution_date = today
        transaction_status = zcl_pp_txn_type=>posted
        reason_code = 'DEMO_VIEW_QTY'
        reason_text = 'Phan cong demo cho duck'
        source_channel = zcl_pp_txn_type=>source_system
        created_by = current_user
        created_at = now
        local_last_changed_at = now )
      ( transaction_uuid = confirm_operator_uuid
        operation_uuid = operation_uuid
        original_transaction_uuid = assign_operator_uuid
        sync_item_uuid = sync_confirm_operator
        actor_user_uuid = operator-user_uuid
        verified_worker_user_uuid = operator-user_uuid
        worker_verified_at = now_utc
        device_id = 'ADT-DEMO-SEED'
        verification_method = 'SEED'
        transaction_type = zcl_pp_txn_type=>confirm
        original_transaction_type = zcl_pp_txn_type=>initial_assign
        worker_id = operator-worker_id
        quantity = '25.000'
        uom = demo_uom
        execution_date = today
        transaction_status = zcl_pp_txn_type=>posted
        reason_code = 'DEMO_VIEW_QTY'
        reason_text = 'Xac nhan san luong demo cua duck'
        source_channel = zcl_pp_txn_type=>source_system
        created_by = current_user
        created_at = now
        local_last_changed_at = now ) ).
    INSERT ztb_pp_alloc_txn FROM TABLE @transactions.
    IF sy-subrc <> 0.
      result-message = 'Da tao balance nhung khong insert duoc ledger demo'.
      RETURN.
    ENDIF.

    result-success = abap_true.
    result-created = abap_true.
    result-operation_uuid = operation_uuid.
    result-message = 'Tao thanh cong Work ID, phan cong va san luong demo'.
  ENDMETHOD.

  METHOD delete_demo_data.
    SELECT FROM ztb_pp_op_alloc
      FIELDS operation_uuid
      WHERE production_order = @demo_order
        AND operation_no = @demo_operation
      INTO TABLE @DATA(demo_operations).

    LOOP AT demo_operations INTO DATA(demo_operation_row).
      DELETE FROM ztb_pp_alloc_txn
        WHERE operation_uuid = @demo_operation_row-operation_uuid.
      DELETE FROM ztb_pp_emp_alloc
        WHERE operation_uuid = @demo_operation_row-operation_uuid.
      DELETE FROM ztb_pp_op_alloc
        WHERE operation_uuid = @demo_operation_row-operation_uuid.
    ENDLOOP.

    SELECT FROM ztb_pp_op_alloc
      FIELDS operation_uuid
      WHERE production_order = @demo_order
        AND operation_no = @demo_operation
      INTO TABLE @DATA(remaining_operations)
      UP TO 1 ROWS.
    success = xsdbool( remaining_operations IS INITIAL ).
  ENDMETHOD.
ENDCLASS.
