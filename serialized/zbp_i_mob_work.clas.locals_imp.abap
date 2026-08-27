CLASS lhc_mobilework DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR MobileWork RESULT result.
    METHODS validateWork FOR VALIDATE ON SAVE
      IMPORTING keys FOR MobileWork~validateWork.
ENDCLASS.

CLASS lhc_mobilework IMPLEMENTATION.
  METHOD get_global_authorizations.
    "Được bảo vệ bằng IAM app/business catalog của service quản trị tập trung.
    result-%create = if_abap_behv=>auth-allowed.
    result-%update = if_abap_behv=>auth-allowed.
    "Work ID là hợp đồng phạm vi phân quyền; hãy vô hiệu hóa thay vì hard-delete.
    result-%delete = if_abap_behv=>auth-unauthorized.
  ENDMETHOD.

  METHOD validateWork.
    READ ENTITIES OF zi_mob_work IN LOCAL MODE
      ENTITY MobileWork
      FIELDS ( WorkID WorkName Plant WorkCenter IsActive )
      WITH CORRESPONDING #( keys )
      RESULT DATA(works).

    LOOP AT works ASSIGNING FIELD-SYMBOL(<work>).
      IF <work>-WorkID IS INITIAL
         OR <work>-WorkName IS INITIAL
         OR <work>-Plant IS INITIAL
         OR <work>-WorkCenter IS INITIAL
         OR ( <work>-IsActive <> 'A' AND <work>-IsActive <> 'I' ).
        APPEND VALUE #( %tky = <work>-%tky ) TO failed-mobilework.
        APPEND VALUE #(
          %tky = <work>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Work ID, tên, nhà máy, tổ và trạng thái A/I là bắt buộc' ) )
          TO reported-mobilework.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
