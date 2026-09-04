"Bootstrap mot tai khoan mobile quan ly bang RAP business logic hien co.
CLASS zcl_pp_mock_confirm_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    CONSTANTS:
      requested_worker TYPE zi_pp_workerref-workerid VALUE '',
      manager_role     TYPE ztb_mob_role-role_id VALUE 'PP_MANAGER',
      function_assign  TYPE ztb_mob_func-func_id VALUE 'PP_INITIAL_ASSIGN',
      function_team    TYPE ztb_mob_func-func_id VALUE 'PP_HIST_TEAM',
      function_self    TYPE ztb_mob_func-func_id VALUE 'PP_HIST_SELF'.

    TYPES:
      BEGIN OF worker_context,
        worker_id   TYPE zi_pp_workerref-workerid,
        worker_name TYPE zi_pp_workerref-workername,
        plant       TYPE zi_pp_workerref-plant,
        work_center TYPE zi_pp_workerref-workcenter,
      END OF worker_context,
      BEGIN OF creation_result,
        success            TYPE abap_bool,
        message            TYPE string,
        user_uuid          TYPE ztb_mob_user-user_uuid,
        username           TYPE ztb_mob_user-username,
        temporary_password TYPE string,
      END OF creation_result.

    CLASS-METHODS find_available_worker
      RETURNING VALUE(worker) TYPE worker_context.

    CLASS-METHODS ensure_functions
      RETURNING VALUE(success) TYPE abap_bool.

    CLASS-METHODS ensure_work_context
      IMPORTING worker TYPE worker_context
      RETURNING VALUE(work_id) TYPE ztb_mob_work-work_id.

    CLASS-METHODS ensure_manager_role
      IMPORTING work_id TYPE ztb_mob_work-work_id
      RETURNING VALUE(success) TYPE abap_bool.

    CLASS-METHODS create_manager_user
      IMPORTING worker TYPE worker_context
      RETURNING VALUE(result) TYPE creation_result.
ENDCLASS.

CLASS zcl_pp_mock_confirm_data IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DATA(worker) = find_available_worker( ).
    IF worker-worker_id IS INITIAL.
      out->write( 'Khong tim thay worker active chua co mobile user' ).
      out->write( 'Chay cac cau SELECT trong docs/MANAGER_BOOTSTRAP_QUERIES.md' ).
      RETURN.
    ENDIF.

    IF ensure_functions( ) = abap_false.
      out->write( 'Khong tao duoc function master cho role quan ly' ).
      RETURN.
    ENDIF.

    DATA(work_id) = ensure_work_context( worker ).
    IF work_id IS INITIAL.
      out->write( 'Khong tao duoc work context tu worker reference' ).
      RETURN.
    ENDIF.

    IF ensure_manager_role( work_id ) = abap_false.
      out->write( 'Khong tao duoc role PP_MANAGER hoac role assignments' ).
      RETURN.
    ENDIF.

    DATA(created) = create_manager_user( worker ).
    out->write( created-message ).
    IF created-success = abap_false.
      RETURN.
    ENDIF.
    out->write( |User UUID: { created-user_uuid }| ).
    out->write( |Username: { created-username }| ).
    out->write( |Temporary password: { created-temporary_password }| ).
    out->write( |Worker: { worker-worker_id } - { worker-worker_name }| ).
    out->write( |Role / Work context: { manager_role } / { work_id }| ).
    out->write( 'Dang nhap roi doi mat khau ngay; password tam chi hien thi mot lan.' ).
  ENDMETHOD.

  METHOD find_available_worker.
    DATA(today) = cl_abap_context_info=>get_system_date( ).
    SELECT FROM zi_pp_workerref
      FIELDS WorkerID, WorkerName, Plant, WorkCenter
      WHERE ValidFrom <= @today
        AND ValidTo >= @today
      ORDER BY WorkerID, Plant, WorkCenter
      INTO TABLE @DATA(workers)
      UP TO 500 ROWS.

    LOOP AT workers INTO DATA(candidate).
      IF requested_worker IS NOT INITIAL
         AND candidate-WorkerID <> requested_worker.
        CONTINUE.
      ENDIF.
      SELECT FROM ztb_mob_user
        FIELDS user_uuid
        WHERE worker_id = @candidate-WorkerID
        INTO TABLE @DATA(existing_accounts)
        UP TO 1 ROWS.
      IF existing_accounts IS INITIAL.
        worker = CORRESPONDING #( candidate MAPPING
          worker_id = WorkerID worker_name = WorkerName
          plant = Plant work_center = WorkCenter ).
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD ensure_functions.
    DATA create_functions TYPE TABLE FOR CREATE zi_mob_func.
    DATA(required_functions) = VALUE zcl_mob_token_validator=>permissions(
      ( func_id = function_assign func_name = 'Giao san luong ban dau' app_module = 'PP' )
      ( func_id = function_team func_name = 'Xem lich su cua doi' app_module = 'PP' )
      ( func_id = function_self func_name = 'Xem lich su ca nhan' app_module = 'PP' ) ).

    LOOP AT required_functions INTO DATA(required_function).
      SELECT FROM ztb_mob_func
        FIELDS func_id
        WHERE func_id = @required_function-func_id
        INTO TABLE @DATA(existing_functions)
        UP TO 1 ROWS.
      IF existing_functions IS INITIAL.
        APPEND VALUE #(
          %cid = |FUNC{ sy-tabix }|
          FuncID = required_function-func_id
          FuncName = required_function-func_name
          AppModule = required_function-app_module ) TO create_functions.
      ENDIF.
    ENDLOOP.

    IF create_functions IS INITIAL.
      success = abap_true.
      RETURN.
    ENDIF.
    MODIFY ENTITIES OF zi_mob_func
      ENTITY MobileFunc CREATE FIELDS ( FuncID FuncName AppModule )
      WITH create_functions
      FAILED DATA(failed_create).
    IF failed_create IS NOT INITIAL.
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.
    COMMIT ENTITIES RESPONSE OF zi_mob_func
      FAILED DATA(failed_commit).
    success = xsdbool( failed_commit IS INITIAL ).
  ENDMETHOD.

  METHOD ensure_work_context.
    work_id = CONV #( |MGR_{ worker-plant }_{ worker-work_center }| ).
    SELECT FROM ztb_mob_work
      FIELDS plant, workcenter, is_active
      WHERE work_id = @work_id
      INTO TABLE @DATA(existing_work)
      UP TO 1 ROWS.
    IF existing_work IS NOT INITIAL.
      IF existing_work[ 1 ]-plant = worker-plant
         AND existing_work[ 1 ]-workcenter = worker-work_center
         AND existing_work[ 1 ]-is_active = 'A'.
        RETURN.
      ENDIF.
      CLEAR work_id.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zi_mob_work
      ENTITY MobileWork CREATE FIELDS
        ( WorkID WorkName Plant WorkCenter BoPhan Location IsActive )
      WITH VALUE #( ( %cid = 'WORK'
        WorkID = work_id
        WorkName = |Quan ly { worker-plant }/{ worker-work_center }|
        Plant = worker-plant
        WorkCenter = worker-work_center
        BoPhan = 'PP'
        Location = |Plant { worker-plant }|
        IsActive = 'A' ) )
      FAILED DATA(failed_create).
    IF failed_create IS NOT INITIAL.
      ROLLBACK ENTITIES.
      CLEAR work_id.
      RETURN.
    ENDIF.
    COMMIT ENTITIES RESPONSE OF zi_mob_work
      FAILED DATA(failed_commit).
    IF failed_commit IS NOT INITIAL.
      CLEAR work_id.
    ENDIF.
  ENDMETHOD.

  METHOD ensure_manager_role.
    SELECT FROM ztb_mob_role
      FIELDS status
      WHERE role_id = @manager_role
      INTO TABLE @DATA(existing_roles)
      UP TO 1 ROWS.
    IF existing_roles IS INITIAL.
      MODIFY ENTITIES OF zi_mob_role
        ENTITY MobileRole CREATE FIELDS ( RoleID RoleName Status )
        WITH VALUE #( ( %cid = 'ROLE'
          RoleID = manager_role RoleName = 'Quan ly san xuat' Status = 'A' ) )
        FAILED DATA(failed_role).
      IF failed_role IS NOT INITIAL.
        ROLLBACK ENTITIES.
        RETURN.
      ENDIF.
      COMMIT ENTITIES RESPONSE OF zi_mob_role
        FAILED DATA(failed_role_commit).
      IF failed_role_commit IS NOT INITIAL.
        RETURN.
      ENDIF.
    ELSEIF existing_roles[ 1 ]-status <> 'A'.
      RETURN.
    ENDIF.

    DATA create_functions TYPE TABLE FOR CREATE zi_mob_role\_Functions.
    APPEND INITIAL LINE TO create_functions ASSIGNING FIELD-SYMBOL(<role_functions>).
    <role_functions>-RoleID = manager_role.
    DATA(function_ids) = VALUE zcl_mob_token_validator=>permissions(
      ( func_id = function_assign )
      ( func_id = function_team )
      ( func_id = function_self ) ).
    LOOP AT function_ids INTO DATA(function_id).
      SELECT FROM ztb_mob_rol_fnc
        FIELDS role_id
        WHERE role_id = @manager_role
          AND func_id = @function_id-func_id
        INTO TABLE @DATA(existing_grants)
        UP TO 1 ROWS.
      IF existing_grants IS INITIAL.
        APPEND VALUE #( %cid = |GRANT{ sy-tabix }|
          FuncID = function_id-func_id ) TO <role_functions>-%target.
      ENDIF.
    ENDLOOP.
    IF <role_functions>-%target IS INITIAL.
      CLEAR create_functions.
    ENDIF.

    SELECT FROM ztb_mob_rol_wrk
      FIELDS role_id
      WHERE role_id = @manager_role
        AND work_id = @work_id
      INTO TABLE @DATA(existing_scopes)
      UP TO 1 ROWS.
    DATA create_work TYPE TABLE FOR CREATE zi_mob_role\_WorkAssignments.
    IF existing_scopes IS INITIAL.
      create_work = VALUE #( ( RoleID = manager_role %target = VALUE #(
        ( %cid = 'SCOPE' WorkID = work_id ) ) ) ).
    ENDIF.

    MODIFY ENTITIES OF zi_mob_role
      ENTITY MobileRole CREATE BY \_Functions FIELDS ( FuncID )
        WITH create_functions
      ENTITY MobileRole CREATE BY \_WorkAssignments FIELDS ( WorkID )
        WITH create_work
      FAILED DATA(failed_assignments).
    IF failed_assignments IS NOT INITIAL.
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.
    COMMIT ENTITIES RESPONSE OF zi_mob_role
      FAILED DATA(failed_commit).
    success = xsdbool( failed_commit IS INITIAL ).
  ENDMETHOD.

  METHOD create_manager_user.
    DATA(worker_lower) = to_lower( CONV string( worker-worker_id ) ).
    result-username = CONV #( |manager_{ worker_lower }| ).
    SELECT FROM ztb_mob_user
      FIELDS user_uuid
      WHERE normalized_username = @result-username
         OR worker_id = @worker-worker_id
      INTO TABLE @DATA(existing_users)
      UP TO 1 ROWS.
    IF existing_users IS NOT INITIAL.
      result-message = 'Username hoac worker da duoc lien ket voi mobile user'.
      RETURN.
    ENDIF.

    TRY.
        DATA(password_seed) = cl_system_uuid=>create_uuid_c36_static( ).
      CATCH cx_uuid_error.
        result-message = 'Khong tao duoc temporary password'.
        RETURN.
    ENDTRY.
    result-temporary_password = |Aa1!{ password_seed+0(12) }|.
    DATA(email) = CONV ztb_mob_user-email(
      |manager.{ worker_lower }@local.invalid| ).

    MODIFY ENTITIES OF zi_mob_user
      ENTITY MobileUser EXECUTE createUser
      FROM VALUE #( ( %cid = 'CREATE_MANAGER' %param = VALUE #(
        Username = result-username
        Password = result-temporary_password
        FullName = |Quan ly - { worker-worker_name }|
        Email = email
        WorkerID = worker-worker_id
        RoleID = manager_role ) ) )
      RESULT DATA(created_users)
      FAILED DATA(failed_create).
    IF failed_create IS NOT INITIAL OR created_users IS INITIAL.
      ROLLBACK ENTITIES.
      result-message = 'RAP createUser that bai; kiem tra worker, role va security config'.
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF zi_mob_user
      FAILED DATA(failed_commit).
    IF failed_commit IS NOT INITIAL.
      result-message = 'Commit mobile user that bai'.
      RETURN.
    ENDIF.
    result-user_uuid = created_users[ 1 ]-%param-UserUUID.
    result-success = abap_true.
    result-message = 'Tao mobile manager user thanh cong'.
  ENDMETHOD.
ENDCLASS.
