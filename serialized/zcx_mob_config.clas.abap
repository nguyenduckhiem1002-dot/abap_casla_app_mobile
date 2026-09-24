CLASS zcx_mob_config DEFINITION
  PUBLIC INHERITING FROM cx_static_check FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS constructor IMPORTING config_key TYPE string.
    DATA config_key TYPE string READ-ONLY.
protected section.
private section.
ENDCLASS.



CLASS ZCX_MOB_CONFIG IMPLEMENTATION.


  METHOD constructor.
    super->constructor( ).
    me->config_key = config_key.
  ENDMETHOD.
ENDCLASS.
