CLASS zcl_mob_sec_config DEFINITION
  PUBLIC FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    CLASS-METHODS get_password_secret RETURNING VALUE(result) TYPE string.
    CLASS-METHODS get_token_secret RETURNING VALUE(result) TYPE string.
  PRIVATE SECTION.
    CLASS-METHODS get_required_value
      IMPORTING config_key TYPE ztb_mob_config-config_key
      RETURNING VALUE(result) TYPE string.
ENDCLASS.

CLASS zcl_mob_sec_config IMPLEMENTATION.
  METHOD get_password_secret.
    result = get_required_value( 'PASSWORD_PEPPER' ).
  ENDMETHOD.
  METHOD get_token_secret.
    result = get_required_value( 'TOKEN_SECRET' ).
  ENDMETHOD.
  METHOD get_required_value.
    SELECT FROM ztb_mob_config FIELDS config_value
      WHERE config_key = @config_key AND is_active = @abap_true
      INTO TABLE @DATA(config_values)
      UP TO 1 ROWS.
    result = VALUE #( config_values[ 1 ]-config_value OPTIONAL ).
    IF result IS INITIAL.
      RAISE EXCEPTION NEW zcx_mob_config( config_key = CONV string( config_key ) ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
