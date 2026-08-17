CLASS zcl_pp_sync_workflow_demo DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    TYPES quantity TYPE p LENGTH 8 DECIMALS 3.

    TYPES:
      BEGIN OF allocation,
        worker_id TYPE c LENGTH 8,
        assigned  TYPE quantity,
        completed TYPE quantity,
      END OF allocation,
      allocations TYPE STANDARD TABLE OF allocation WITH EMPTY KEY.

    CLASS-METHODS get_total_remaining
      IMPORTING rows TYPE allocations
      RETURNING VALUE(result) TYPE quantity.

    CLASS-METHODS can_assign
      IMPORTING
        operation_quantity TYPE quantity
        rows               TYPE allocations
        requested_quantity TYPE quantity
      RETURNING VALUE(result) TYPE abap_bool.

    CLASS-METHODS write_state
      IMPORTING
        title              TYPE string
        operation_quantity TYPE quantity
        rows               TYPE allocations
        out                TYPE REF TO if_oo_adt_classrun_out.
ENDCLASS.

CLASS zcl_pp_sync_workflow_demo IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    CONSTANTS operation_quantity TYPE quantity VALUE '15470'.

    DATA rows TYPE allocations.

    " Bước sync: kiểm tra payload và ghi inbox với trạng thái QUEUED.
    out->write( 'SYNC: mobile gửi batch, API validate định dạng/idempotency và trả QUEUED.' ).

    APPEND VALUE #( worker_id = 'CL00001'
                    assigned  = '15000'
                    completed = '0' ) TO rows.

    write_state( title              = 'Sau khi giao CL00001 = 15.000'
                 operation_quantity = operation_quantity
                 rows               = rows
                 out                = out ).

    DATA(is_valid) = can_assign(
      operation_quantity = operation_quantity
      rows               = rows
      requested_quantity = '3000' ).

    out->write( |Giao thêm CL00002 = 3.000 khi chưa hoàn thành: |
                && COND string( WHEN is_valid = abap_true
                                THEN 'HỢP LỆ'
                                ELSE 'KHÔNG HỢP LỆ (18.000 > 15.470)' ) ).

    rows[ 1 ]-completed = '10000'.

    write_state( title              = 'Sau khi CL00001 hoàn thành 10.000'
                 operation_quantity = operation_quantity
                 rows               = rows
                 out                = out ).

    is_valid = can_assign(
      operation_quantity = operation_quantity
      rows               = rows
      requested_quantity = '3000' ).

    IF is_valid = abap_true.
      APPEND VALUE #( worker_id = 'CL00002'
                      assigned  = '3000'
                      completed = '0' ) TO rows.
    ENDIF.

    out->write( |Giao CL00002 = 3.000 sau khi hoàn thành 10.000: |
                && COND string( WHEN is_valid = abap_true
                                THEN 'HỢP LỆ (3.000 <= 5.000)'
                                ELSE 'KHÔNG HỢP LỆ' ) ).

    write_state( title              = 'Trạng thái cuối'
                 operation_quantity = operation_quantity
                 rows               = rows
                 out                = out ).

    " Bước async: worker giữ lock công đoạn, validate nghiệp vụ lại,
    " cập nhật allocation + ledger trong cùng LUW rồi đổi inbox sang SUCCESS.
    out->write( 'ASYNC: worker lock, revalidate, cập nhật số dư/ledger và trạng thái sync.' ).
  ENDMETHOD.

  METHOD get_total_remaining.
    result = REDUCE quantity(
      INIT total TYPE quantity
      FOR row IN rows
      NEXT total = total + row-assigned - row-completed ).
  ENDMETHOD.

  METHOD can_assign.
    result = xsdbool(
      get_total_remaining( rows ) + requested_quantity <= operation_quantity ).
  ENDMETHOD.

  METHOD write_state.
    out->write( title ).
    out->write( |SL công đoạn: { operation_quantity NUMBER = USER }| ).
    out->write( |Tổng SL còn lại đã giao: {
                  get_total_remaining( rows ) NUMBER = USER }| ).

    LOOP AT rows INTO DATA(row).
      out->write( |{ row-worker_id }: giao={ row-assigned NUMBER = USER }, |
                  && |hoàn thành={ row-completed NUMBER = USER }, |
                  && |còn lại={ row-assigned - row-completed NUMBER = USER }| ).
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
