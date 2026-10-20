CLASS lhc_mobilerole DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR MobileRole RESULT result.
    METHODS validateRole FOR VALIDATE ON SAVE
      IMPORTING keys FOR MobileRole~validateRole.
    METHODS uploadExcel FOR MODIFY
      IMPORTING keys FOR ACTION MobileRole~uploadExcel RESULT result.
ENDCLASS.

CLASS lhc_mobilerole IMPLEMENTATION.
  METHOD get_global_authorizations.
    "Được bảo vệ bằng IAM app/business catalog của service quản trị.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.
    "Hãy vô hiệu hóa chức danh qua Status thay vì hard-delete. Hard-delete có thể
    "làm mất liên kết lịch sử phân quyền và các tham chiếu phục vụ audit.
    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = if_abap_behv=>auth-unauthorized.
    ENDIF.
    IF requested_authorizations-%action-uploadExcel = if_abap_behv=>mk-on.
      result-%action-uploadExcel = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD uploadExcel.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.
    DATA(cid) = CONV string( keys[ 1 ]-%cid ).
    DATA(parsed) = VALUE zcl_mob_role_upload=>ty_result( ).
    IF lines( keys ) > 1.
      APPEND 'Mỗi yêu cầu chỉ được tải một file' TO parsed-errors.
    ELSEIF keys[ 1 ]-%param-fileContent IS INITIAL.
      APPEND 'Nội dung file Excel là bắt buộc' TO parsed-errors.
    ELSE.
      parsed = zcl_mob_role_upload=>parse( keys[ 1 ]-%param-fileContent ).
    ENDIF.
    IF parsed-errors IS NOT INITIAL.
      APPEND VALUE #( %cid = cid ) TO failed-mobilerole.
      LOOP AT parsed-errors INTO DATA(error_text).
        APPEND VALUE #( %cid = cid
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error text = error_text ) )
          TO reported-mobilerole.
      ENDLOOP.
      RETURN.
    ENDIF.

    "Chức danh đã có thì chỉ cập nhật tên/trạng thái; RoleID không đổi được.
    DATA role_creates TYPE TABLE FOR CREATE zi_mob_role.
    DATA role_updates TYPE TABLE FOR UPDATE zi_mob_role.
    LOOP AT parsed-roles ASSIGNING FIELD-SYMBOL(<role>).
      IF <role>-is_existing = abap_true.
        APPEND VALUE #( RoleID = <role>-role_id RoleName = <role>-role_name
          Status = <role>-status ) TO role_updates.
      ELSE.
        APPEND VALUE #( %cid = <role>-cid RoleID = <role>-role_id RoleName = <role>-role_name
          Status = <role>-status ) TO role_creates.
      ENDIF.
    ENDLOOP.

    "Chức danh mới tham chiếu bằng %cid_ref, chức danh đã có tham chiếu bằng RoleID.
    MODIFY ENTITIES OF zi_mob_role IN LOCAL MODE
      ENTITY MobileRole
        CREATE FIELDS ( RoleID RoleName Status )
        WITH role_creates
      ENTITY MobileRole
        UPDATE FIELDS ( RoleName Status )
        WITH role_updates
      ENTITY MobileRole
        CREATE BY \_Functions FIELDS ( FuncID )
        WITH VALUE #( FOR func IN parsed-functions
          ( %cid_ref = COND #( WHEN func-role_is_new = abap_true THEN func-role_cid )
            RoleID = COND #( WHEN func-role_is_new = abap_false THEN func-role_id )
            %target = VALUE #( ( %cid = func-cid FuncID = func-item_id ) ) ) )
      ENTITY MobileRole
        CREATE BY \_WorkAssignments FIELDS ( WorkID )
        WITH VALUE #( FOR work IN parsed-works
          ( %cid_ref = COND #( WHEN work-role_is_new = abap_true THEN work-role_cid )
            RoleID = COND #( WHEN work-role_is_new = abap_false THEN work-role_id )
            %target = VALUE #( ( %cid = work-cid WorkID = work-item_id ) ) ) )
      FAILED DATA(failed_upload) REPORTED DATA(reported_upload).
    IF failed_upload IS NOT INITIAL.
      failed = CORRESPONDING #( failed_upload ).
      reported = CORRESPONDING #( reported_upload ).
      RETURN.
    ENDIF.
    result = VALUE #( ( %cid = cid %param = VALUE #(
      RoleCount = lines( parsed-roles )
      FunctionCount = lines( parsed-functions )
      WorkCount = lines( parsed-works ) ) ) ).
  ENDMETHOD.

  METHOD validateRole.
    READ ENTITIES OF zi_mob_role IN LOCAL MODE
      ENTITY MobileRole
      FIELDS ( RoleID RoleName Status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(roles).

    LOOP AT roles ASSIGNING FIELD-SYMBOL(<role>).
      IF <role>-RoleID IS INITIAL
         OR <role>-RoleName IS INITIAL
         OR ( <role>-Status <> 'A' AND <role>-Status <> 'I' ).
        APPEND VALUE #( %tky = <role>-%tky ) TO failed-mobilerole.
        APPEND VALUE #(
          %tky = <role>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Mã chức danh, tên và trạng thái A/I là bắt buộc' ) )
          TO reported-mobilerole.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS lhc_mobilerolefunc DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS validateFunctionAssignment FOR VALIDATE ON SAVE
      IMPORTING keys FOR MobileRoleFunc~validateFunctionAssignment.
ENDCLASS.

CLASS lhc_mobilerolefunc IMPLEMENTATION.
  METHOD validateFunctionAssignment.
    READ ENTITIES OF zi_mob_role IN LOCAL MODE
      ENTITY MobileRoleFunc
      FIELDS ( FuncID )
      WITH CORRESPONDING #( keys )
      RESULT DATA(assignments).

    DATA function_ids TYPE RANGE OF ztb_mob_func-func_id.
    LOOP AT assignments ASSIGNING FIELD-SYMBOL(<assignment_key>).
      IF NOT line_exists( function_ids[ low = <assignment_key>-FuncID ] ).
        INSERT VALUE #( sign = 'I' option = 'EQ'
                        low = <assignment_key>-FuncID )
          INTO TABLE function_ids.
      ENDIF.
    ENDLOOP.

    IF function_ids IS INITIAL.
      RETURN.
    ENDIF.

    DATA functions TYPE SORTED TABLE OF ztb_mob_func-func_id
      WITH UNIQUE KEY table_line.
    SELECT FROM ztb_mob_func
      FIELDS func_id
      WHERE func_id IN @function_ids
      INTO TABLE @functions.

    LOOP AT assignments ASSIGNING FIELD-SYMBOL(<assignment>).
      IF NOT line_exists( functions[ table_line = <assignment>-FuncID ] ).
        APPEND VALUE #( %tky = <assignment>-%tky )
          TO failed-mobilerolefunc.
        APPEND VALUE #(
          %tky = <assignment>-%tky
          %element-FuncID = if_abap_behv=>mk-on
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Chức năng không tồn tại' ) )
          TO reported-mobilerolefunc.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS lhc_mobilerolework DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS validateWorkAssignment FOR VALIDATE ON SAVE
      IMPORTING keys FOR MobileRoleWork~validateWorkAssignment.
ENDCLASS.

CLASS lhc_mobilerolework IMPLEMENTATION.
  METHOD validateWorkAssignment.
    READ ENTITIES OF zi_mob_role IN LOCAL MODE
      ENTITY MobileRoleWork
      FIELDS ( WorkID )
      WITH CORRESPONDING #( keys )
      RESULT DATA(assignments).

    DATA work_ids TYPE RANGE OF ztb_mob_work-work_id.
    LOOP AT assignments ASSIGNING FIELD-SYMBOL(<assignment_key>).
      IF NOT line_exists( work_ids[ low = <assignment_key>-WorkID ] ).
        INSERT VALUE #( sign = 'I' option = 'EQ'
                        low = <assignment_key>-WorkID )
          INTO TABLE work_ids.
      ENDIF.
    ENDLOOP.

    IF work_ids IS INITIAL.
      RETURN.
    ENDIF.

    DATA active_works TYPE SORTED TABLE OF ztb_mob_work-work_id
      WITH UNIQUE KEY table_line.
    SELECT FROM ztb_mob_work
      FIELDS work_id
      WHERE work_id IN @work_ids
        AND is_active = 'A'
      INTO TABLE @active_works.

    LOOP AT assignments ASSIGNING FIELD-SYMBOL(<assignment>).
      IF NOT line_exists( active_works[ table_line = <assignment>-WorkID ] ).
        APPEND VALUE #( %tky = <assignment>-%tky )
          TO failed-mobilerolework.
        APPEND VALUE #(
          %tky = <assignment>-%tky
          %element-WorkID = if_abap_behv=>mk-on
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Vị trí làm việc không tồn tại hoặc đã ngừng hoạt động' ) )
          TO reported-mobilerolework.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

