CLASS ltcl_mob_token_validator DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS empty_token_is_rejected FOR TESTING.
    METHODS reject_low_kdf_iterations FOR TESTING.
    METHODS reject_high_kdf_iterations FOR TESTING.
    METHODS reject_empty_password_salt FOR TESTING.
ENDCLASS.

CLASS ltcl_mob_token_validator IMPLEMENTATION.
  METHOD empty_token_is_rejected.
    TRY.
        DATA(token_hash) = zcl_mob_token_validator=>hash_token( `` ) ##NEEDED.
        cl_abap_unit_assert=>fail( msg = 'Expected EMPTY_TOKEN configuration error' ).
      CATCH zcx_mob_config INTO DATA(config_error).
        cl_abap_unit_assert=>assert_equals(
          exp = 'EMPTY_TOKEN'
          act = config_error->config_key ).
      CATCH cx_abap_message_digest.
        cl_abap_unit_assert=>fail( msg = 'Empty token must fail before message digest processing' ).
    ENDTRY.
  ENDMETHOD.

  METHOD reject_low_kdf_iterations.
    TRY.
        DATA(password_hash) = zcl_mob_token_validator=>hash_password(
          password = 'secret'
          salt = 'salt'
          iterations = 9999 ) ##NEEDED.
        cl_abap_unit_assert=>fail( msg = 'Expected INVALID_PASSWORD_KDF for low iteration count' ).
      CATCH zcx_mob_config INTO DATA(config_error).
        cl_abap_unit_assert=>assert_equals(
          exp = 'INVALID_PASSWORD_KDF'
          act = config_error->config_key ).
      CATCH cx_abap_message_digest.
        cl_abap_unit_assert=>fail( msg = 'Invalid KDF must fail before message digest processing' ).
    ENDTRY.
  ENDMETHOD.

  METHOD reject_high_kdf_iterations.
    TRY.
        DATA(password_hash) = zcl_mob_token_validator=>hash_password(
          password = 'secret'
          salt = 'salt'
          iterations = 100001 ) ##NEEDED.
        cl_abap_unit_assert=>fail( msg = 'Expected INVALID_PASSWORD_KDF for high iteration count' ).
      CATCH zcx_mob_config INTO DATA(config_error).
        cl_abap_unit_assert=>assert_equals(
          exp = 'INVALID_PASSWORD_KDF'
          act = config_error->config_key ).
      CATCH cx_abap_message_digest.
        cl_abap_unit_assert=>fail( msg = 'Invalid KDF must fail before message digest processing' ).
    ENDTRY.
  ENDMETHOD.

  METHOD reject_empty_password_salt.
    TRY.
        DATA(password_hash) = zcl_mob_token_validator=>hash_password(
          password = 'secret'
          salt = ``
          iterations = 10000 ) ##NEEDED.
        cl_abap_unit_assert=>fail( msg = 'Expected INVALID_PASSWORD_KDF for empty salt' ).
      CATCH zcx_mob_config INTO DATA(config_error).
        cl_abap_unit_assert=>assert_equals(
          exp = 'INVALID_PASSWORD_KDF'
          act = config_error->config_key ).
      CATCH cx_abap_message_digest.
        cl_abap_unit_assert=>fail( msg = 'Invalid KDF must fail before message digest processing' ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
