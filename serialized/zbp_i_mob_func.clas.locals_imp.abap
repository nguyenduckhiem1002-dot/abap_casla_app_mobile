CLASS lhc_mobilefunc DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR MobileFunc RESULT result.
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
ENDCLASS.
