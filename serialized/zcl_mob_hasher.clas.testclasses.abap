CLASS ltcl_mob_hasher DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS equal_values_are_equal FOR TESTING.
    METHODS different_values_are_not_equal FOR TESTING.
    METHODS length_mismatch_is_not_equal FOR TESTING.
    METHODS empty_secret_is_rejected FOR TESTING.
ENDCLASS.

CLASS ltcl_mob_hasher IMPLEMENTATION.
  METHOD equal_values_are_equal.
    cl_abap_unit_assert=>assert_equals(
      exp = abap_true
      act = zcl_mob_hasher=>equals_constant_time(
        value_1 = 'ABC123'
        value_2 = 'ABC123' ) ).
  ENDMETHOD.

  METHOD different_values_are_not_equal.
    cl_abap_unit_assert=>assert_equals(
      exp = abap_false
      act = zcl_mob_hasher=>equals_constant_time(
        value_1 = 'ABC123'
        value_2 = 'ABC124' ) ).
  ENDMETHOD.

  METHOD length_mismatch_is_not_equal.
    cl_abap_unit_assert=>assert_equals(
      exp = abap_false
      act = zcl_mob_hasher=>equals_constant_time(
        value_1 = 'ABC123'
        value_2 = 'ABC1234' ) ).
  ENDMETHOD.

  METHOD empty_secret_is_rejected.
    TRY.
        DATA(hasher) = NEW zcl_mob_hasher( iv_secret_key = `` ) ##NEEDED.
        cl_abap_unit_assert=>fail( msg = 'Expected EMPTY_SECRET configuration error' ).
      CATCH zcx_mob_config INTO DATA(config_error).
        cl_abap_unit_assert=>assert_equals(
          exp = 'EMPTY_SECRET'
          act = config_error->config_key ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
