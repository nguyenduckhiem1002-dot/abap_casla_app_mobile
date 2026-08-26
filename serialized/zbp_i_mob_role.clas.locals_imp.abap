CLASS lhc_mobilerole DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR MobileRole RESULT result.
ENDCLASS.

CLASS lhc_mobilerole IMPLEMENTATION.
  METHOD get_global_authorizations.
    "Protected by IAM app/business catalog of the admin service.
    result-%create = if_abap_behv=>auth-allowed.
    result-%update = if_abap_behv=>auth-allowed.
    "Disable the role through Status instead of deleting it. A hard delete
    "can orphan historical authorization assignments and audit references.
    result-%delete = if_abap_behv=>auth-unauthorized.
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
