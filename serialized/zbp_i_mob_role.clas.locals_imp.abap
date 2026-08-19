CLASS lhc_mobilerole DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR MobileRole RESULT result.
ENDCLASS.

CLASS lhc_mobilerole IMPLEMENTATION.
  METHOD get_global_authorizations.
    "Protected by IAM app/business catalog of the admin service.
    result-%create = if_abap_behv=>auth-allowed.
    result-%update = if_abap_behv=>auth-allowed.
    result-%delete = if_abap_behv=>auth-allowed.
  ENDMETHOD.
ENDCLASS.
