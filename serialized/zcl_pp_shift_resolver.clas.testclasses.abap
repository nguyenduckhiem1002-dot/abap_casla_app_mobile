CLASS ltc_shift DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS night_config RETURNING VALUE(config) TYPE ztb_pp_shift.
    METHODS before_midnight FOR TESTING.
    METHODS after_midnight FOR TESTING.
    METHODS at_start FOR TESTING.
    METHODS at_end FOR TESTING.
    METHODS outside_shift FOR TESTING.
    METHODS last_valid_night FOR TESTING.
    METHODS daytime FOR TESTING.
    METHODS invalid_config FOR TESTING.
    METHODS legacy_date FOR TESTING.
    METHODS missing_timestamp FOR TESTING.
ENDCLASS.

CLASS ltc_shift IMPLEMENTATION.
  METHOD night_config.
    config = VALUE #( plant = '1000' shift_id = 'NIGHT' shift_name = 'Night'
      valid_from = '20260101' valid_to = '20261231'
      start_time = '220000' end_time = '060000' end_day_offset = 1
      time_zone = 'UTC' is_active = 'A' ).
  ENDMETHOD.
  METHOD before_midnight.
    DATA(actual) = zcl_pp_shift_resolver=>calculate(
      config = night_config( ) executed_at = CONV utclong( '2026-09-07 23:00:00' ) ).
    cl_abap_unit_assert=>assert_true( actual-is_valid ).
    cl_abap_unit_assert=>assert_equals( act = actual-work_date exp = '20260907' ).
  ENDMETHOD.
  METHOD after_midnight.
    DATA(actual) = zcl_pp_shift_resolver=>calculate(
      config = night_config( ) executed_at = CONV utclong( '2026-09-08 02:00:00' ) ).
    cl_abap_unit_assert=>assert_true( actual-is_valid ).
    cl_abap_unit_assert=>assert_equals( act = actual-work_date exp = '20260907' ).
    cl_abap_unit_assert=>assert_equals( act = actual-shift_start_at
      exp = CONV utclong( '2026-09-07 22:00:00' ) ).
    cl_abap_unit_assert=>assert_equals( act = actual-shift_end_at
      exp = CONV utclong( '2026-09-08 06:00:00' ) ).
  ENDMETHOD.
  METHOD at_start.
    DATA(actual) = zcl_pp_shift_resolver=>calculate(
      config = night_config( ) executed_at = CONV utclong( '2026-09-07 22:00:00' ) ).
    cl_abap_unit_assert=>assert_true( actual-is_valid ).
  ENDMETHOD.
  METHOD at_end.
    DATA(actual) = zcl_pp_shift_resolver=>calculate(
      config = night_config( ) executed_at = CONV utclong( '2026-09-08 06:00:00' ) ).
    cl_abap_unit_assert=>assert_false( actual-is_valid ).
  ENDMETHOD.
  METHOD outside_shift.
    DATA(actual) = zcl_pp_shift_resolver=>calculate(
      config = night_config( ) executed_at = CONV utclong( '2026-09-07 21:59:59' ) ).
    cl_abap_unit_assert=>assert_false( actual-is_valid ).
  ENDMETHOD.
  METHOD last_valid_night.
    DATA(config) = night_config( ).
    config-valid_to = '20260907'.
    DATA(actual) = zcl_pp_shift_resolver=>calculate(
      config = config executed_at = CONV utclong( '2026-09-08 05:30:00' ) ).
    cl_abap_unit_assert=>assert_true( actual-is_valid ).
    cl_abap_unit_assert=>assert_equals( act = actual-work_date exp = '20260907' ).
  ENDMETHOD.
  METHOD daytime.
    DATA(config) = night_config( ).
    config-start_time = '060000'.
    config-end_time = '140000'.
    config-end_day_offset = 0.
    DATA(actual) = zcl_pp_shift_resolver=>calculate(
      config = config executed_at = CONV utclong( '2026-09-08 06:00:00' ) ).
    cl_abap_unit_assert=>assert_true( actual-is_valid ).
    cl_abap_unit_assert=>assert_equals( act = actual-work_date exp = '20260908' ).
  ENDMETHOD.
  METHOD invalid_config.
    DATA(config) = night_config( ).
    config-end_day_offset = 0.
    DATA(actual) = zcl_pp_shift_resolver=>calculate(
      config = config executed_at = CONV utclong( '2026-09-08 02:00:00' ) ).
    cl_abap_unit_assert=>assert_false( actual-is_valid ).
  ENDMETHOD.
  METHOD legacy_date.
    DATA(actual) = zcl_pp_shift_resolver=>resolve(
      plant = '1000' shift_id = '' executed_at = VALUE utclong( ) execution_date = '20260907' ).
    cl_abap_unit_assert=>assert_true( actual-is_valid ).
    cl_abap_unit_assert=>assert_equals( act = actual-work_date exp = '20260907' ).
    cl_abap_unit_assert=>assert_initial( actual-shift_id ).
    cl_abap_unit_assert=>assert_initial( actual-executed_at ).
  ENDMETHOD.
  METHOD missing_timestamp.
    DATA(actual) = zcl_pp_shift_resolver=>resolve(
      plant = '1000' shift_id = 'NIGHT' executed_at = VALUE utclong( ) execution_date = '20260907' ).
    cl_abap_unit_assert=>assert_equals( act = actual-error_code exp = 'SHIFT_AND_EXECUTED_AT_REQUIRED' ).
  ENDMETHOD.
ENDCLASS.
