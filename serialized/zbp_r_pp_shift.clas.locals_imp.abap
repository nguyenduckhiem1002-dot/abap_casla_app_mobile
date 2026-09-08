CLASS lhc_shift DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Shift RESULT result.
    METHODS validateShift FOR VALIDATE ON SAVE
      IMPORTING keys FOR Shift~validateShift.
ENDCLASS.

CLASS lhc_shift IMPLEMENTATION.
  METHOD get_global_authorizations.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD validateShift.
    READ ENTITIES OF zr_pp_shift IN LOCAL MODE
      ENTITY Shift
      FIELDS ( Plant ShiftID ValidFrom ShiftName StartTime EndTime EndDayOffset
               SAPTimeZone ValidTo IsActive )
      WITH CORRESPONDING #( keys )
      RESULT DATA(shifts).

    LOOP AT shifts ASSIGNING FIELD-SYMBOL(<shift>).
      IF <shift>-Plant IS INITIAL
         OR <shift>-ShiftID IS INITIAL
         OR <shift>-ValidFrom IS INITIAL
         OR <shift>-ShiftName IS INITIAL
         OR <shift>-StartTime IS INITIAL
         OR <shift>-EndTime IS INITIAL
         OR <shift>-SAPTimeZone IS INITIAL
         OR <shift>-ValidTo IS INITIAL
         OR ( <shift>-EndDayOffset <> 0 AND <shift>-EndDayOffset <> 1 )
         OR ( <shift>-IsActive <> 'A' AND <shift>-IsActive <> 'I' ).
        APPEND VALUE #( %tky = <shift>-%tky ) TO failed-shift.
        APPEND VALUE #(
          %tky = <shift>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Nhà máy, mã ca, thời gian, múi giờ, hiệu lực và trạng thái A/I là bắt buộc' ) )
          TO reported-shift.
        CONTINUE.
      ENDIF.

      IF <shift>-ValidTo < <shift>-ValidFrom.
        APPEND VALUE #( %tky = <shift>-%tky ) TO failed-shift.
        APPEND VALUE #(
          %tky = <shift>-%tky
          %element-ValidFrom = if_abap_behv=>mk-on
          %element-ValidTo = if_abap_behv=>mk-on
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Ngày hiệu lực đến phải lớn hơn hoặc bằng ngày hiệu lực từ' ) )
          TO reported-shift.
        CONTINUE.
      ENDIF.

      SELECT FROM ztb_pp_shift
        FIELDS plant
        WHERE plant = @<shift>-Plant
          AND shift_id = @<shift>-ShiftID
          AND valid_from <> @<shift>-ValidFrom
          AND is_active = 'A'
          AND valid_from <= @<shift>-ValidTo
          AND valid_to >= @<shift>-ValidFrom
        INTO TABLE @DATA(overlap_plants)
        UP TO 1 ROWS.
      IF overlap_plants IS NOT INITIAL.
        APPEND VALUE #( %tky = <shift>-%tky ) TO failed-shift.
        APPEND VALUE #(
          %tky = <shift>-%tky
          %element-ShiftID = if_abap_behv=>mk-on
          %element-ValidFrom = if_abap_behv=>mk-on
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Khoảng hiệu lực của ca đang bị trùng với phiên bản Active khác' ) )
          TO reported-shift.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
