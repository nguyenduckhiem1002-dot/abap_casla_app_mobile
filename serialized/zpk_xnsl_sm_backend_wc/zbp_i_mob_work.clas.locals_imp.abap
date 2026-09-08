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
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.
    "Work ID là hợp đồng phạm vi phân quyền; hãy vô hiệu hóa thay vì hard-delete.
    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = if_abap_behv=>auth-unauthorized.
    ENDIF.
  ENDMETHOD.

  METHOD validateWork.
    READ ENTITIES OF zi_mob_work IN LOCAL MODE
      ENTITY MobileWork
      FIELDS ( WorkID WorkName Plant WorkCenter IsActive )
      WITH CORRESPONDING #( keys )
      RESULT DATA(works).

    DATA plant_ids TYPE RANGE OF zi_mob_workcenter_vh-Plant.
    DATA work_center_ids TYPE RANGE OF zi_mob_workcenter_vh-WorkCenter.
    LOOP AT works ASSIGNING FIELD-SYMBOL(<work_key>).
      IF <work_key>-Plant IS NOT INITIAL
         AND NOT line_exists( plant_ids[ low = <work_key>-Plant ] ).
        INSERT VALUE #( sign = 'I' option = 'EQ' low = <work_key>-Plant )
          INTO TABLE plant_ids.
      ENDIF.
      IF <work_key>-WorkCenter IS NOT INITIAL
         AND NOT line_exists( work_center_ids[ low = <work_key>-WorkCenter ] ).
        INSERT VALUE #( sign = 'I' option = 'EQ' low = <work_key>-WorkCenter )
          INTO TABLE work_center_ids.
      ENDIF.
    ENDLOOP.

    DATA valid_work_centers TYPE SORTED TABLE OF zi_mob_workcenter_vh
      WITH UNIQUE KEY Plant WorkCenter.
    IF plant_ids IS NOT INITIAL AND work_center_ids IS NOT INITIAL.
      SELECT FROM zi_mob_workcenter_vh
        FIELDS Plant, WorkCenter
        WHERE Plant IN @plant_ids
          AND WorkCenter IN @work_center_ids
        INTO TABLE @valid_work_centers.
    ENDIF.

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
      ELSEIF <work>-IsActive = 'A'
         AND NOT line_exists( valid_work_centers[
           Plant = <work>-Plant WorkCenter = <work>-WorkCenter ] ).
        APPEND VALUE #( %tky = <work>-%tky ) TO failed-mobilework.
        APPEND VALUE #(
          %tky = <work>-%tky
          %element-Plant = if_abap_behv=>mk-on
          %element-WorkCenter = if_abap_behv=>mk-on
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Trung tâm làm việc không thuộc nhà máy đã chọn' ) )
          TO reported-mobilework.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
