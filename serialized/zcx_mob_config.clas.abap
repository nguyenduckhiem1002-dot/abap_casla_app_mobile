CLASS zcx_mob_config DEFINITION
  PUBLIC INHERITING FROM cx_static_check FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS constructor IMPORTING config_key TYPE string.
    DATA config_key TYPE string READ-ONLY.
ENDCLASS.

CLASS zcx_mob_config IMPLEMENTATION.
  METHOD constructor.
    super->constructor( ).
    me->config_key = config_key.
  ENDMETHOD.
ENDCLASS.
