CLASS lhc_mobilefunc DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR MobileFunc RESULT result.
    METHODS validateFunction FOR VALIDATE ON SAVE
      IMPORTING keys FOR MobileFunc~validateFunction.
ENDCLASS.

CLASS lhc_mobilefunc IMPLEMENTATION.
  METHOD get_global_authorizations.
    "Protected by IAM app/business catalog of the admin service.
    result-%create = if_abap_behv=>auth-allowed.
    result-%update = if_abap_behv=>auth-allowed.
    "Function identifiers are stable authorization contracts. Removing one
    "would leave assignments and clients with an ambiguous permission state.
    result-%delete = if_abap_behv=>auth-unauthorized.
  ENDMETHOD.

  METHOD validateFunction.
    READ ENTITIES OF zi_mob_func IN LOCAL MODE
      ENTITY MobileFunc
      FIELDS ( FuncID FuncName )
      WITH CORRESPONDING #( keys )
      RESULT DATA(functions).

    LOOP AT functions ASSIGNING FIELD-SYMBOL(<function>).
      IF <function>-FuncID IS INITIAL OR <function>-FuncName IS INITIAL.
        APPEND VALUE #( %tky = <function>-%tky ) TO failed-mobilefunc.
        APPEND VALUE #(
          %tky = <function>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Mã chức năng và tên chức năng là bắt buộc' ) )
          TO reported-mobilefunc.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
