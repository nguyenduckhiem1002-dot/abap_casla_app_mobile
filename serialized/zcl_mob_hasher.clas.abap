CLASS zcl_mob_hasher DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS constructor IMPORTING iv_secret_key TYPE string.
    METHODS calculate_hash
      IMPORTING iv_value TYPE string
      RETURNING VALUE(rv_hash) TYPE string
      RAISING cx_abap_message_digest.
    METHODS verify_hash
      IMPORTING iv_value TYPE string iv_expected_hash TYPE string
      RETURNING VALUE(rv_matches) TYPE abap_bool
      RAISING cx_abap_message_digest.
  PRIVATE SECTION.
    DATA secret_key TYPE string.
ENDCLASS.

CLASS zcl_mob_hasher IMPLEMENTATION.
  METHOD constructor.
    IF iv_secret_key IS INITIAL.
      RAISE EXCEPTION NEW zcx_mob_config( config_key = 'EMPTY_SECRET' ).
    ENDIF.
    secret_key = iv_secret_key.
  ENDMETHOD.
  METHOD calculate_hash.
    cl_abap_message_digest=>calculate_hash_for_char(
      EXPORTING if_algorithm = 'SHA256'
                if_data = secret_key && ':' && iv_value
      IMPORTING ef_hashstring = rv_hash ).
  ENDMETHOD.
  METHOD verify_hash.
    rv_matches = xsdbool( calculate_hash( iv_value ) = iv_expected_hash ).
  ENDMETHOD.
ENDCLASS.
