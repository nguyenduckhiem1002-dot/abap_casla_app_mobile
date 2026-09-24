CLASS zcl_pp_shift_mock_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: tt_tab TYPE STANDARD TABLE OF ztb_pp_shift WITH EMPTY KEY.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    CONSTANTS plant TYPE ztb_pp_shift-plant VALUE '6712'.
    CONSTANTS time_zone TYPE ztb_pp_shift-time_zone VALUE 'UTC'.

    METHODS build_shift_data
      RETURNING VALUE(shifts) TYPE tt_tab.
ENDCLASS.



CLASS ZCL_PP_SHIFT_MOCK_DATA IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

    DATA(shifts) = build_shift_data( ).
    DATA(current_user) = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD DATA(now).

    LOOP AT shifts ASSIGNING FIELD-SYMBOL(<shift>).

      <shift>-created_by = current_user.
      <shift>-created_at = now.
      <shift>-last_changed_by = current_user.
      <shift>-last_changed_at = now.
      <shift>-local_last_changed_at = now.

      SELECT FROM ztb_pp_shift
        FIELDS plant
        WHERE plant      = @<shift>-plant
          AND shift_id   = @<shift>-shift_id
          AND valid_from = @<shift>-valid_from
        INTO TABLE @DATA(existing)
        UP TO 1 ROWS.

      IF existing IS NOT INITIAL.
        out->write(
          |Bo qua { <shift>-plant }/{ <shift>-shift_id } - da ton tai| ).
        CONTINUE.
      ENDIF.

      INSERT ztb_pp_shift FROM @<shift>.

      IF sy-subrc <> 0.
        ROLLBACK WORK.

        out->write(
          |Khong tao duoc ca { <shift>-shift_id }| ).

        RETURN.
      ENDIF.

      out->write(
        |Da tao ca { <shift>-plant }/{ <shift>-shift_id }| ).

    ENDLOOP.

    COMMIT WORK.

    out->write( 'Da append xong du lieu ca lam viec mock.' ).

  ENDMETHOD.


  METHOD build_shift_data.

    DATA(valid_from) = cl_abap_context_info=>get_system_date( ).

    shifts = VALUE #(

      (
        plant          = plant
        shift_id       = 'DAY'
        valid_from     = valid_from
        shift_name     = 'Ca sang'
        start_time     = '060000'
        end_time       = '140000'
        end_day_offset = 0
        time_zone      = time_zone
        valid_to       = '99991231'
        is_active      = 'A'
      )

      (
        plant          = plant
        shift_id       = 'EVENING'
        valid_from     = valid_from
        shift_name     = 'Ca chieu'
        start_time     = '140000'
        end_time       = '220000'
        end_day_offset = 0
        time_zone      = time_zone
        valid_to       = '99991231'
        is_active      = 'A'
      )

      (
        plant          = plant
        shift_id       = 'NIGHT'
        valid_from     = valid_from
        shift_name     = 'Ca dem'
        start_time     = '220000'
        end_time       = '060000'
        end_day_offset = 1
        time_zone      = time_zone
        valid_to       = '99991231'
        is_active      = 'A'
      )

    ).

  ENDMETHOD.
ENDCLASS.
