CLASS lhc_mobilerole DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR MobileRole RESULT result.
    METHODS validateRole FOR VALIDATE ON SAVE
      IMPORTING keys FOR MobileRole~validateRole.
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
