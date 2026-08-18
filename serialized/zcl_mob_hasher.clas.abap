CLASS zcl_mob_hasher DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS constructor IMPORTING iv_secret_key TYPE string.
    METHODS calculate_hash
      IMPORTING iv_value TYPE string
      RETURNING VALUE(rv_hash) TYPE string
      RAISING cx_abap_message_digest.
    CLASS-METHODS equals_constant_time
      IMPORTING value_1 TYPE string
                value_2 TYPE string
      RETURNING VALUE(result) TYPE abap_bool.
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
  METHOD equals_constant_time.
    "Length is not secret here: both operands are fixed-length hex digests.
    DATA(length) = strlen( value_1 ).
    IF length <> strlen( value_2 ).
      result = abap_false.
      RETURN.
    ENDIF.
    DATA(mismatch) = abap_false.
    DATA(offset) = 0.
    WHILE offset < length.
      IF value_1+offset(1) <> value_2+offset(1).
        mismatch = abap_true.
      ENDIF.
      offset = offset + 1.
    ENDWHILE.
    result = xsdbool( mismatch = abap_false ).
  ENDMETHOD.
ENDCLASS.
