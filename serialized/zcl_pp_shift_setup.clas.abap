CLASS zcl_pp_shift_setup DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PRIVATE SECTION.
    "Fill these from the real plant and SAP time-zone configuration before F9.
    CONSTANTS plant TYPE ztb_pp_shift-plant VALUE ''.
    CONSTANTS time_zone TYPE ztb_pp_shift-time_zone VALUE ''.
    CONSTANTS valid_from TYPE d VALUE '20260907'.
ENDCLASS.
CLASS zcl_pp_shift_setup IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    IF plant IS INITIAL OR time_zone IS INITIAL.
      out->write( 'Dien PLANT va TIME_ZONE SAP that trong constants truoc khi chay.' ).
      RETURN.
    ENDIF.
    DATA configs TYPE STANDARD TABLE OF ztb_pp_shift WITH EMPTY KEY.
    configs = VALUE #(
      ( plant = plant shift_id = 'DAY' shift_name = 'Ca sang'
        valid_from = valid_from valid_to = '99991231' time_zone = time_zone
        start_time = '060000' end_time = '140000' end_day_offset = 0 is_active = 'A' )
      ( plant = plant shift_id = 'EVENING' shift_name = 'Ca chieu'
        valid_from = valid_from valid_to = '99991231' time_zone = time_zone
        start_time = '140000' end_time = '220000' end_day_offset = 0 is_active = 'A' )
      ( plant = plant shift_id = 'NIGHT' shift_name = 'Ca dem'
        valid_from = valid_from valid_to = '99991231' time_zone = time_zone
        start_time = '220000' end_time = '060000' end_day_offset = 1 is_active = 'A' ) ).
    "Validate all proposed rows before writing any configuration.
    LOOP AT configs INTO DATA(config).
      DATA(start_at) = VALUE utclong( ).
      TRY.
          CONVERT DATE config-valid_from TIME config-start_time TIME ZONE config-time_zone
            INTO UTCLONG start_at.
        CATCH cx_parameter_invalid_range cx_sy_conversion_error.
          out->write( 'TIME_ZONE hoac ngay/gio khong hop le; chua ghi du lieu.' ).
          RETURN.
      ENDTRY.
      DATA(check) = zcl_pp_shift_resolver=>calculate( config = config executed_at = start_at ).
      IF check-is_valid = abap_false.
        out->write( |Cau hinh { config-shift_id } khong hop le; chua ghi du lieu.| ).
        RETURN.
      ENDIF.
    ENDLOOP.
    LOOP AT configs INTO config.
      SELECT FROM ztb_pp_shift FIELDS shift_id
        WHERE plant = @config-plant AND shift_id = @config-shift_id AND valid_from = @config-valid_from
        INTO TABLE @DATA(existing) UP TO 1 ROWS.
      IF existing IS NOT INITIAL.
        out->write( |Bo qua { config-shift_id }: da co phien ban nay, khong ghi de.| ).
        CONTINUE.
      ENDIF.
      INSERT ztb_pp_shift FROM @config.
      IF sy-subrc = 0.
        out->write( |Da tao { config-plant }/{ config-shift_id } tu { config-valid_from }.| ).
      ELSE.
        out->write( |Khong tao duoc { config-shift_id }.| ).
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
