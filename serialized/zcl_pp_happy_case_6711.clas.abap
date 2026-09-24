CLASS zcl_pp_happy_case_6711 DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    CONSTANTS:
      c_plant         TYPE ztb_mob_work-plant
        VALUE '6711',
      c_work_center   TYPE ztb_mob_work-workcenter
        VALUE 'CLXM1VLT',
      c_work_id       TYPE ztb_mob_work-work_id
        VALUE '6711_CLXM1VLT_MAY1_KQ3',
      c_manager       TYPE ztb_mob_user-worker_id
        VALUE 'bachdv',
      c_operator      TYPE ztb_mob_user-worker_id
        VALUE 'KHIEMND1',
      c_manager_role  TYPE ztb_mob_role-role_id
  VALUE 'PP_MANAGER_6711',

      c_operator_role TYPE ztb_mob_role-role_id
        VALUE 'PP_OPERATOR_6711',
      c_password      TYPE string
        VALUE '123456',
      c_iterations    TYPE i
        VALUE 10000.

    DATA error_text TYPE string.

    METHODS ensure_account
      IMPORTING
        worker_id        TYPE ztb_mob_user-worker_id
      RETURNING
        VALUE(user_uuid) TYPE sysuuid_x16
      RAISING
        cx_uuid_error
        cx_abap_message_digest
        zcx_mob_config.

    METHODS ensure_role
      IMPORTING
        role_id        TYPE ztb_mob_role-role_id
        role_name      TYPE ztb_mob_role-role_name
      RETURNING
        VALUE(success) TYPE abap_bool.

    METHODS ensure_work
      RETURNING VALUE(success) TYPE abap_bool.

    METHODS ensure_access
      IMPORTING
        manager_uuid   TYPE sysuuid_x16
        operator_uuid  TYPE sysuuid_x16
      RETURNING
        VALUE(success) TYPE abap_bool.
    METHODS seed_workers
      RETURNING VALUE(success) TYPE abap_bool
      RAISING   cx_uuid_error.

    METHODS seed_shifts
      RETURNING VALUE(success) TYPE abap_bool.

ENDCLASS.



CLASS ZCL_PP_HAPPY_CASE_6711 IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.




    TRY.


        DATA(manager_uuid) = ensure_account( c_manager ).
        "Kiem tra cau hinh auth truoc khi ghi du lieu.
        DATA(password_secret) =
          zcl_mob_sec_config=>get_password_secret( ).

        DATA(token_secret) =
          zcl_mob_sec_config=>get_token_secret( ).

        IF password_secret IS INITIAL OR token_secret IS INITIAL.
          out->write( 'Thieu PASSWORD_PEPPER hoac TOKEN_SECRET.' ).
          RETURN.
        ENDIF.


        IF manager_uuid IS INITIAL.
          ROLLBACK WORK.
          out->write( error_text ).
          RETURN.
        ENDIF.

        DATA(operator_uuid) = ensure_account( c_operator ).

        IF operator_uuid IS INITIAL.
          ROLLBACK WORK.
          out->write( error_text ).
          RETURN.
        ENDIF.

        IF ensure_access(
             manager_uuid  = manager_uuid
             operator_uuid = operator_uuid ) = abap_false.

          ROLLBACK WORK.
          out->write( error_text ).
          RETURN.
        ENDIF.

        "Kiem tra lai bang chinh logic doc quyen cua mobile.
        DATA(manager_permissions) =
          zcl_mob_token_validator=>get_permissions(
            user_uuid = manager_uuid ).

        DATA(operator_permissions) =
          zcl_mob_token_validator=>get_permissions(
            user_uuid = operator_uuid ).

        IF NOT line_exists(
             manager_permissions[ func_id = 'PP_INITIAL_ASSIGN' ] )
           OR NOT line_exists(
             manager_permissions[ func_id = 'PP_HIST_TEAM' ] )
           OR NOT line_exists(
             operator_permissions[ func_id = 'PP_CONFIRM' ] )
           OR NOT line_exists(
             operator_permissions[ func_id = 'PP_HIST_SELF' ] ).

          ROLLBACK WORK.
          out->write( 'Thieu quyen sau khi tao role/function.' ).
          RETURN.
        ENDIF.

        "Khong de role cu bien nhan vien thanh quan ly.
        IF line_exists(
             operator_permissions[ func_id = 'PP_INITIAL_ASSIGN' ] )
           OR line_exists(
             operator_permissions[ func_id = 'PP_TRANSFER' ] )
           OR line_exists(
             operator_permissions[ func_id = 'PP_RECALL' ] )
           OR line_exists(
             operator_permissions[ func_id = 'PP_REVERSE' ] )
           OR line_exists(
             operator_permissions[ func_id = 'PP_HIST_TEAM' ] ).

          ROLLBACK WORK.
          out->write(
            'KHIEMND1 dang co quyen quan ly tu role da ton tai. '
            && 'Kiem tra lai role cua user; class khong tu xoa role cu.' ).
          RETURN.
        ENDIF.

        IF zcl_mob_token_validator=>has_work_scope(
             user_uuid   = manager_uuid
             plant       = c_plant
             work_center = c_work_center ) = abap_false
           OR zcl_mob_token_validator=>has_work_scope(
             user_uuid   = operator_uuid
             plant       = c_plant
             work_center = c_work_center ) = abap_false.

          ROLLBACK WORK.
          out->write( 'Work scope cua hai user chua hop le.' ).
          RETURN.
        ENDIF.

        COMMIT WORK.

      CATCH cx_uuid_error
            cx_abap_message_digest
            zcx_mob_config
            cx_sy_open_sql_db INTO DATA(error).

        ROLLBACK WORK.
        out->write( error->get_text( ) ).
        RETURN.
    ENDTRY.

    out->write( 'Da commit thanh cong bo tai khoan happy case.' ).
    out->write( |Quan ly: { c_manager }| ).
    out->write( |Nhan vien: { c_operator }| ).
    out->write( |Work ID: { c_work_id }| ).
    out->write( |Plant / Work Center: { c_plant } / { c_work_center }| ).
    out->write( |Manager UUID: { manager_uuid }| ).
    out->write( |Operator UUID: { operator_uuid }| ).

    out->write( 'Quyen quan ly:' ).
    out->write( manager_permissions ).

    out->write( 'Quyen nhan vien:' ).
    out->write( operator_permissions ).

    DATA(today) = cl_abap_context_info=>get_system_date( ).

    SELECT FROM zi_pp_shift
      FIELDS Plant,
             ShiftID,
             ShiftName,
             StartTime,
             EndTime,
             EndDayOffset,
             SAPTimeZone,
             ValidFrom,
             ValidTo
      WHERE Plant = @c_plant
        AND ShiftID = '1'
        AND IsActive = 'A'
        AND ValidFrom <= @today
        AND ValidTo >= @today
      INTO TABLE @DATA(shifts).

    IF shifts IS INITIAL.
      out->write(
        'Chua co cau hinh ca 1 dang hieu luc cho Plant 6711. '
        && 'Can tao gio ca va mui gio SAP dung thuc te.' ).
    ELSE.
      out->write( 'Cau hinh ca 1 hien co:' ).
      out->write( shifts ).
    ENDIF.

    out->write(
      'Buoc test: BACHDV giao san luong cho KHIEMND1; '
      && 'KHIEMND1 xac nhan; BACHDV xem team history.' ).

  ENDMETHOD.


  METHOD ensure_account.

    DATA(today) = cl_abap_context_info=>get_system_date( ).

    SELECT FROM zi_pp_workerref
      FIELDS WorkerID, WorkerName, ValidFrom, ValidTo
      WHERE WorkerID = @worker_id
        AND Plant = @c_plant
        AND WorkCenter = @c_work_center
        AND ValidFrom <= @today
        AND ValidTo >= @today
      INTO TABLE @DATA(workers)
      UP TO 2 ROWS.

    IF lines( workers ) <> 1.
      error_text =
        |Nhan cong { worker_id }: can dung 1 dong dang hieu luc |
        && |tai { c_plant }/{ c_work_center }.|.
      RETURN.
    ENDIF.

    DATA(normalized) =
      CONV ztb_mob_user-normalized_username(
        to_lower( CONV string( worker_id ) ) ).

    SELECT FROM ztb_mob_user
      FIELDS *
      WHERE normalized_username = @normalized
         OR worker_id = @worker_id
         OR username = @worker_id
      INTO TABLE @DATA(accounts)
      UP TO 2 ROWS.

    IF accounts IS NOT INITIAL.

      IF lines( accounts ) <> 1.
        error_text =
          |Username/Worker ID { worker_id } dang bi trung mapping.|.
        RETURN.
      ENDIF.

      DATA(account) = accounts[ 1 ].

      IF account-worker_id <> worker_id
         OR account-normalized_username <> normalized
         OR account-status <> 'A'.

        error_text =
          |Tai khoan { worker_id } da co nhung mapping/status khong dung.|.
        RETURN.
      ENDIF.

      IF account-locked_until IS NOT INITIAL
         AND account-locked_until > utclong_current( ).

        error_text = |Tai khoan { worker_id } dang bi khoa.|.
        RETURN.
      ENDIF.

      IF account-password_change_required = abap_true.
        error_text =
          |Tai khoan { worker_id } dang yeu cau doi mat khau. |
          && 'Hoan tat doi mat khau truoc khi test nghiep vu.'.
        RETURN.
      ENDIF.

      DATA(verification) =
        zcl_mob_password_service=>verify_worker(
          worker_id = worker_id
          password  = c_password ).

      IF verification-is_valid = abap_false
         OR verification-user_uuid <> account-user_uuid.

        error_text =
          |Tai khoan { worker_id } da co nhung credential khong khop |
          && 'mat khau test. Class khong reset mat khau da ton tai.'.
        RETURN.
      ENDIF.

      user_uuid = account-user_uuid.
      RETURN.
    ENDIF.

    DATA(new_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
    DATA(salt) = cl_system_uuid=>create_uuid_c36_static( ).

    DATA(password_hash) =
      zcl_mob_password_service=>calculate_hash(
        password   = c_password
        salt       = CONV string( salt )
        iterations = c_iterations ).

    IF password_hash IS INITIAL.
      error_text = |Khong hash duoc mat khau cho { worker_id }.|.
      RETURN.
    ENDIF.

    DATA(audit_user) =
      cl_abap_context_info=>get_user_technical_name( ).

    DATA(audit_at) = VALUE timestampl( ).
    GET TIME STAMP FIELD audit_at.

    DATA(new_account) = VALUE ztb_mob_user(
      user_uuid               = new_uuid
      username                = worker_id
      normalized_username     = normalized
      full_name               = workers[ 1 ]-WorkerName
      email                   = |{ normalized }@test.invalid|
      worker_id               = worker_id
      status                  = 'A'
      failed_login_count      = 0
      "Chi dung cho happy case tren tenant test.
      password_change_required = abap_false
      created_by              = audit_user
      created_at              = audit_at
      last_changed_by         = audit_user
      last_changed_at         = audit_at
      local_last_changed_at   = audit_at ).

    INSERT ztb_mob_user FROM @new_account.

    IF sy-subrc <> 0.
      error_text = |Khong insert duoc user { worker_id }.|.
      RETURN.
    ENDIF.

    DATA(credential) = VALUE ztb_mob_cred(
      user_uuid           = new_uuid
      password_hash       = password_hash
      password_salt       = salt
      hash_algorithm      = 'SHA256-ITER'
      hash_iterations     = c_iterations
      password_changed_at = utclong_current( )
      credential_status   = 'A' ).

    INSERT ztb_mob_cred FROM @credential.

    IF sy-subrc <> 0.
      error_text = |Khong insert duoc credential cho { worker_id }.|.
      RETURN.
    ENDIF.

    user_uuid = new_uuid.

  ENDMETHOD.


  METHOD ensure_role.

    SELECT SINGLE FROM ztb_mob_role
      FIELDS status
      WHERE role_id = @role_id
      INTO @DATA(status).

    IF sy-subrc = 0.
      success = xsdbool( status = 'A' ).

      IF success = abap_false.
        error_text = |Role { role_id } da co nhung khong active.|.
      ENDIF.

      RETURN.
    ENDIF.

    DATA(audit_user) =
      cl_abap_context_info=>get_user_technical_name( ).

    DATA(audit_at) = VALUE timestampl( ).
    GET TIME STAMP FIELD audit_at.

    DATA(role) = VALUE ztb_mob_role(
      role_id               = role_id
      role_name             = role_name
      status                = 'A'
      created_by            = audit_user
      created_at            = audit_at
      last_changed_by       = audit_user
      last_changed_at       = audit_at
      local_last_changed_at = audit_at ).

    INSERT ztb_mob_role FROM @role.

    success = xsdbool( sy-subrc = 0 ).

    IF success = abap_false.
      error_text = |Khong tao duoc role { role_id }.|.
    ENDIF.

  ENDMETHOD.


  METHOD ensure_work.

    SELECT SINGLE FROM ztb_mob_work
      FIELDS plant, workcenter, is_active
      WHERE work_id = @c_work_id
      INTO @DATA(existing).

    IF sy-subrc = 0.
      success = xsdbool(
        existing-plant = c_plant
        AND existing-workcenter = c_work_center
        AND existing-is_active = 'A' ).

      IF success = abap_false.
        error_text = |Work ID { c_work_id } da co nhung cau hinh khac.|.
      ENDIF.

      RETURN.
    ENDIF.

    DATA(audit_at) = VALUE timestampl( ).
    GET TIME STAMP FIELD audit_at.

    DATA(work) = VALUE ztb_mob_work(
      work_id               = c_work_id
      work_name             = 'Tổ May 1 - Máy KQ-3'
      plant                 = c_plant
      workcenter            = c_work_center
      bo_phan               = 'Tổ May 1'
      location              = 'MAY1 / KQ-3'
      is_active             = 'A'
      last_changed_at       = audit_at
      local_last_changed_at = audit_at ).

    INSERT ztb_mob_work FROM @work.

    success = xsdbool( sy-subrc = 0 ).

    IF success = abap_false.
      error_text = |Khong tao duoc Work ID { c_work_id }.|.
    ENDIF.

  ENDMETHOD.


  METHOD ensure_access.

    IF ensure_role(
     role_id   = c_manager_role
     role_name = 'Quản lý Nhà máy 6711' ) = abap_false.
      RETURN.
    ENDIF.

    IF ensure_role(
         role_id   = c_operator_role
         role_name = 'Nhân viên Nhà máy 6711' ) = abap_false.
      RETURN.
    ENDIF.

    IF ensure_work( ) = abap_false.
      RETURN.
    ENDIF.

    DATA(functions) =
      VALUE zcl_mob_token_validator=>permissions(
        ( func_id = 'PP_INITIAL_ASSIGN'
          func_name = 'Giao sản lượng'
          app_module = 'PP' )
        ( func_id = 'PP_TRANSFER'
          func_name = 'Điều chuyển sản lượng'
          app_module = 'PP' )
        ( func_id = 'PP_RECALL'
          func_name = 'Thu hồi sản lượng'
          app_module = 'PP' )
        ( func_id = 'PP_REVERSE'
          func_name = 'Đảo xác nhận sản lượng'
          app_module = 'PP' )
        ( func_id = 'PP_HIST_TEAM'
          func_name = 'Xem lịch sử tổ'
          app_module = 'PP' )
        ( func_id = 'PP_CONFIRM'
          func_name = 'Xác nhận sản lượng'
          app_module = 'PP' )
        ( func_id = 'PP_HIST_SELF'
          func_name = 'Xem lịch sử cá nhân'
          app_module = 'PP' ) ).

    DATA function_rows
      TYPE STANDARD TABLE OF ztb_mob_func WITH EMPTY KEY.

    DATA(audit_at) = VALUE timestampl( ).
    GET TIME STAMP FIELD audit_at.

    LOOP AT functions INTO DATA(function).
      APPEND VALUE #(
        func_id               = function-func_id
        func_name             = function-func_name
        app_module            = function-app_module
        last_changed_at       = audit_at
        local_last_changed_at = audit_at
      ) TO function_rows.
    ENDLOOP.

    INSERT ztb_mob_func
      FROM TABLE @function_rows ACCEPTING DUPLICATE KEYS.

    DATA role_functions
      TYPE STANDARD TABLE OF ztb_mob_rol_fnc WITH EMPTY KEY.

    role_functions = VALUE #(
      ( role_id = c_manager_role  func_id = 'PP_INITIAL_ASSIGN' )
      ( role_id = c_manager_role  func_id = 'PP_TRANSFER' )
      ( role_id = c_manager_role  func_id = 'PP_RECALL' )
      ( role_id = c_manager_role  func_id = 'PP_REVERSE' )
      ( role_id = c_manager_role  func_id = 'PP_HIST_TEAM' )
      ( role_id = c_manager_role  func_id = 'PP_HIST_SELF' )
      ( role_id = c_operator_role func_id = 'PP_CONFIRM' )
      ( role_id = c_operator_role func_id = 'PP_HIST_SELF' ) ).

    INSERT ztb_mob_rol_fnc
      FROM TABLE @role_functions ACCEPTING DUPLICATE KEYS.

    DATA role_works
      TYPE STANDARD TABLE OF ztb_mob_rol_wrk WITH EMPTY KEY.

    role_works = VALUE #(
      ( role_id = c_manager_role  work_id = c_work_id )
      ( role_id = c_operator_role work_id = c_work_id ) ).

    INSERT ztb_mob_rol_wrk
      FROM TABLE @role_works ACCEPTING DUPLICATE KEYS.

    DATA user_roles
      TYPE STANDARD TABLE OF ztb_mob_usr_rol WITH EMPTY KEY.

    user_roles = VALUE #(
      ( user_uuid = manager_uuid  role_id = c_manager_role )
      ( user_uuid = operator_uuid role_id = c_operator_role ) ).

    INSERT ztb_mob_usr_rol
      FROM TABLE @user_roles ACCEPTING DUPLICATE KEYS.

    success = abap_true.

  ENDMETHOD.


  METHOD seed_workers.

    DATA workers
      TYPE STANDARD TABLE OF ztb_kb_nhancong WITH EMPTY KEY.

    workers = VALUE #(
      (
        work_center = c_work_center
        plant       = c_plant
        worker_id   = c_manager
        worker_name = 'Đoàn Văn Bách'
        bo_phan     = 'Tổ May 1'
        from_date   = '20260901'
        to_date     = '20821201'
      )
      (
        work_center = c_work_center
        plant       = c_plant
        worker_id   = c_operator
        worker_name = 'Nguyễn Đức Khiêm'
        bo_phan     = 'Tổ May 1'
        from_date   = '20260901'
        to_date     = '20260930'
      )
    ).

    DATA(audit_user) =
      cl_abap_context_info=>get_user_technical_name( ).

    DATA audit_at TYPE timestampl.
    GET TIME STAMP FIELD audit_at.

    LOOP AT workers ASSIGNING FIELD-SYMBOL(<worker>).

      "Kiem tra phan cong cung nhan cong/work center bi giao hieu luc.
      SELECT FROM ztb_kb_nhancong
        FIELDS uuid_nhancong, from_date, to_date
        WHERE worker_id = @<worker>-worker_id
          AND plant = @<worker>-plant
          AND work_center = @<worker>-work_center
          AND from_date <= @<worker>-to_date
          AND ( to_date >= @<worker>-from_date
                OR to_date = '00000000' )
        INTO TABLE @DATA(existing).

      IF existing IS NOT INITIAL.

        IF lines( existing ) = 1.
          DATA(existing_worker) = existing[ 1 ].

          "Chay lai: giu nguyen dong da co cung khoang hieu luc.
          IF existing_worker-from_date = <worker>-from_date
             AND existing_worker-to_date = <worker>-to_date.
            CONTINUE.
          ENDIF.
        ENDIF.

        error_text =
          |Nhan cong { <worker>-worker_id } da co phan cong |
          && |giao khoang hieu luc tai |
          && |{ <worker>-plant }/{ <worker>-work_center }.|.

        RETURN.
      ENDIF.

      <worker>-uuid_nhancong =
        cl_system_uuid=>create_uuid_x16_static( ).

      <worker>-createdbyuser = audit_user.
      <worker>-createddate   = audit_at.
      <worker>-changedbyuser = audit_user.
      <worker>-changeddate   = audit_at.

      INSERT ztb_kb_nhancong FROM @<worker>.

      IF sy-subrc <> 0.
        error_text =
          |Khong insert duoc nhan cong { <worker>-worker_id }.|.
        RETURN.
      ENDIF.

    ENDLOOP.

    success = abap_true.

  ENDMETHOD.


  METHOD seed_shifts.

    CONSTANTS factory_time_zone
      TYPE ztb_pp_shift-time_zone VALUE 'UTC+7'.

    DATA shifts
      TYPE STANDARD TABLE OF ztb_pp_shift WITH EMPTY KEY.

    shifts = VALUE #(
      (
        plant          = c_plant
        shift_id       = '1'
        shift_name     = 'Ca ngày'
        start_time     = '080000'
        end_time       = '170000'
        end_day_offset = 0
        time_zone      = factory_time_zone
        valid_from     = '20260901'
        valid_to       = '99991231'
        is_active      = 'A'
      )
      (
        plant          = c_plant
        shift_id       = '2'
        shift_name     = 'Ca đêm'
        start_time     = '200000'
        end_time       = '050000'
        end_day_offset = 1
        time_zone      = factory_time_zone
        valid_from     = '20260901'
        valid_to       = '99991231'
        is_active      = 'A'
      )
    ).

    DATA(audit_user) =
      cl_abap_context_info=>get_user_technical_name( ).

    DATA audit_at TYPE timestampl.
    GET TIME STAMP FIELD audit_at.

    LOOP AT shifts ASSIGNING FIELD-SYMBOL(<shift>).

      DATA start_at TYPE utclong.

      TRY.
          CONVERT DATE <shift>-valid_from
            TIME <shift>-start_time
            TIME ZONE <shift>-time_zone
            INTO UTCLONG start_at.

        CATCH cx_parameter_invalid_range cx_sy_conversion_error.
          error_text =
            |Mui gio SAP { factory_time_zone } khong hop le tren tenant. |
            && 'Thay factory_time_zone bang ma SAP tuong ung UTC+07:00.'.
          RETURN.
      ENDTRY.

      DATA(check) = zcl_pp_shift_resolver=>calculate(
        config      = <shift>
        executed_at = start_at ).

      IF check-is_valid = abap_false.
        error_text =
          |Cau hinh ca { <shift>-shift_id } khong hop le: |
          && |{ check-error_code }|.
        RETURN.
      ENDIF.

      "Doc ca cung khoa hoac phien ban active giao khoang hieu luc.
      SELECT FROM ztb_pp_shift
        FIELDS *
        WHERE plant = @<shift>-plant
          AND shift_id = @<shift>-shift_id
          AND (
            valid_from = @<shift>-valid_from
            OR (
              is_active = 'A'
              AND valid_from <= @<shift>-valid_to
              AND valid_to >= @<shift>-valid_from
            )
          )
        INTO TABLE @DATA(existing).

      IF existing IS NOT INITIAL.

        IF lines( existing ) = 1.
          DATA(existing_shift) = existing[ 1 ].

          IF existing_shift-valid_from = <shift>-valid_from
             AND existing_shift-valid_to = <shift>-valid_to
             AND existing_shift-start_time = <shift>-start_time
             AND existing_shift-end_time = <shift>-end_time
             AND existing_shift-end_day_offset = <shift>-end_day_offset
             AND existing_shift-time_zone = <shift>-time_zone
             AND existing_shift-is_active = 'A'.

            "Chay lai voi cung cau hinh: khong them dong.
            CONTINUE.
          ENDIF.
        ENDIF.

        error_text =
          |Ca { <shift>-shift_id } tai Plant { <shift>-plant } |
          && 'da co cau hinh khac hoac trung khoang hieu luc. '
          && 'Kiem tra ban ghi hien co truoc khi thay doi.'.
        RETURN.
      ENDIF.

      <shift>-created_by            = audit_user.
      <shift>-created_at            = audit_at.
      <shift>-last_changed_by       = audit_user.
      <shift>-last_changed_at       = audit_at.
      <shift>-local_last_changed_at = audit_at.

      INSERT ztb_pp_shift FROM @<shift>.

      IF sy-subrc <> 0.
        error_text =
          |Khong insert duoc ca { <shift>-shift_id }.|.
        RETURN.
      ENDIF.

    ENDLOOP.

    success = abap_true.

  ENDMETHOD.
ENDCLASS.
