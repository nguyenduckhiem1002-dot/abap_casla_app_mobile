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

    LOOP AT assignments ASSIGNING FIELD-SYMBOL(<assignment>).
      SELECT FROM ztb_mob_func
        FIELDS func_id
        WHERE func_id = @<assignment>-FuncID
        INTO TABLE @DATA(functions)
        UP TO 1 ROWS.
      IF functions IS INITIAL.
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

    LOOP AT assignments ASSIGNING FIELD-SYMBOL(<assignment>).
      SELECT FROM ztb_mob_work
        FIELDS work_id
        WHERE work_id = @<assignment>-WorkID
          AND is_active = 'A'
        INTO TABLE @DATA(active_works)
        UP TO 1 ROWS.
      IF active_works IS INITIAL.
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