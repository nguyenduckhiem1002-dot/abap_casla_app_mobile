CLASS lhc_operationallocation DEFINITION
  INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR OperationAllocation
      RESULT result.

    METHODS validateOperation FOR VALIDATE ON SAVE
      IMPORTING keys FOR OperationAllocation~validateOperation.

    METHODS initialAssign FOR MODIFY
      IMPORTING keys FOR ACTION OperationAllocation~initialAssign
      RESULT result.

    METHODS transfer FOR MODIFY
      IMPORTING keys FOR ACTION OperationAllocation~transfer
      RESULT result.

    METHODS confirm FOR MODIFY
      IMPORTING keys FOR ACTION OperationAllocation~confirm
      RESULT result.

    METHODS reverse FOR MODIFY
      IMPORTING keys FOR ACTION OperationAllocation~reverse
      RESULT result.
ENDCLASS.

CLASS lhc_employeeallocation DEFINITION
  INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS validateBalance FOR VALIDATE ON SAVE
      IMPORTING keys FOR EmployeeAllocation~validateBalance.
ENDCLASS.

CLASS lhc_employeeallocation IMPLEMENTATION.
  METHOD validateBalance.
    READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
      ENTITY EmployeeAllocation
      FIELDS ( InitialAssignedQuantity TransferredInQuantity
               TransferredOutQuantity CompletedQuantity RemainingQuantity )
      WITH CORRESPONDING #( keys )
      RESULT DATA(allocations).

    LOOP AT allocations ASSIGNING FIELD-SYMBOL(<allocation>).
      DATA(expected_remaining) =
        <allocation>-InitialAssignedQuantity
        + <allocation>-TransferredInQuantity
        - <allocation>-TransferredOutQuantity
        - <allocation>-CompletedQuantity.
      IF expected_remaining < 0
         OR <allocation>-RemainingQuantity <> expected_remaining.
        APPEND VALUE #( %tky = <allocation>-%tky )
          TO failed-employeeallocation.
        APPEND VALUE #(
          %tky = <allocation>-%tky
          %element-RemainingQuantity = if_abap_behv=>mk-on
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Số lượng còn lại không khớp với sổ phân bổ' ) )
          TO reported-employeeallocation.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS lhc_operationallocation IMPLEMENTATION.
  METHOD get_global_authorizations.
    "Domain mutations are internal until submitSync validates the mobile token.
    result-%create = if_abap_behv=>auth-unauthorized.
    result-%update = if_abap_behv=>auth-unauthorized.
    result-%action-initialAssign = if_abap_behv=>auth-unauthorized.
    result-%action-transfer = if_abap_behv=>auth-unauthorized.
    result-%action-confirm = if_abap_behv=>auth-unauthorized.
    result-%action-reverse = if_abap_behv=>auth-unauthorized.
  ENDMETHOD.

  METHOD validateOperation.
    READ ENTITIES OF zr_pp_opalloc IN LOCAL MODE
      ENTITY OperationAllocation
      FIELDS ( OperationQuantity UnitOfMeasure Plant WorkCenter )
      WITH CORRESPONDING #( keys )
      RESULT DATA(operations).

    LOOP AT operations ASSIGNING FIELD-SYMBOL(<operation>).
      IF <operation>-OperationQuantity <= 0.
        APPEND VALUE #( %tky = <operation>-%tky )
          TO failed-operationallocation.
        APPEND VALUE #(
          %tky = <operation>-%tky
          %element-OperationQuantity = if_abap_behv=>mk-on
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Operation quantity must be greater than zero' ) )
          TO reported-operationallocation.
      ENDIF.

      IF <operation>-UnitOfMeasure IS INITIAL
         OR <operation>-Plant IS INITIAL
         OR <operation>-WorkCenter IS INITIAL.
        APPEND VALUE #( %tky = <operation>-%tky )
          TO failed-operationallocation.
        APPEND VALUE #(
          %tky = <operation>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Plant, work center and unit are mandatory' ) )
          TO reported-operationallocation.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD initialAssign.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      APPEND VALUE #( %tky = <key>-%tky )
        TO failed-operationallocation.
      APPEND VALUE #(
        %tky = <key>-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'INITIAL_ASSIGNMENT implementation is not activated yet' ) )
        TO reported-operationallocation.
    ENDLOOP.
  ENDMETHOD.

  METHOD transfer.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      APPEND VALUE #( %tky = <key>-%tky )
        TO failed-operationallocation.
      APPEND VALUE #(
        %tky = <key>-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'TRANSFER implementation is not activated yet' ) )
        TO reported-operationallocation.
    ENDLOOP.
  ENDMETHOD.

  METHOD confirm.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      APPEND VALUE #( %tky = <key>-%tky )
        TO failed-operationallocation.
      APPEND VALUE #(
        %tky = <key>-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'SAP production confirmation adapter is not configured' ) )
        TO reported-operationallocation.
    ENDLOOP.
  ENDMETHOD.

  METHOD reverse.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      APPEND VALUE #( %tky = <key>-%tky )
        TO failed-operationallocation.
      APPEND VALUE #(
        %tky = <key>-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'REVERSE implementation is not activated yet' ) )
        TO reported-operationallocation.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
