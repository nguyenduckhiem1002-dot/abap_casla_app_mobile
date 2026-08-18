CLASS zcl_pp_worker_validator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF worker_check,
        worker_id      TYPE zi_pp_workerref-WorkerID,
        plant          TYPE zi_pp_workerref-Plant,
        work_center    TYPE zi_pp_workerref-WorkCenter,
        execution_date TYPE zi_pp_workerref-ValidFrom,
        is_active      TYPE abap_bool,
      END OF worker_check,
      worker_checks TYPE STANDARD TABLE OF worker_check WITH EMPTY KEY.

    CLASS-METHODS check_workers
      CHANGING checks TYPE worker_checks.

    CLASS-METHODS is_worker_active
      IMPORTING
        worker_id      TYPE zi_pp_workerref-WorkerID
        plant          TYPE zi_pp_workerref-Plant
        work_center    TYPE zi_pp_workerref-WorkCenter
        execution_date TYPE zi_pp_workerref-ValidFrom
      RETURNING
        VALUE(result)  TYPE abap_bool.
ENDCLASS.

CLASS zcl_pp_worker_validator IMPLEMENTATION.
  METHOD check_workers.
    IF checks IS INITIAL.
      RETURN.
    ENDIF.

    DATA worker_range TYPE RANGE OF zi_pp_workerref-WorkerID.
    DATA plant_range TYPE RANGE OF zi_pp_workerref-Plant.

    LOOP AT checks ASSIGNING FIELD-SYMBOL(<check>).
      INSERT VALUE #( sign = 'I' option = 'EQ' low = <check>-worker_id )
        INTO TABLE worker_range.
      INSERT VALUE #( sign = 'I' option = 'EQ' low = <check>-plant )
        INTO TABLE plant_range.
    ENDLOOP.
    SORT worker_range BY low.
    DELETE ADJACENT DUPLICATES FROM worker_range COMPARING low.
    SORT plant_range BY low.
    DELETE ADJACENT DUPLICATES FROM plant_range COMPARING low.

    SELECT FROM zi_pp_workerref
      FIELDS WorkerID, Plant, WorkCenter, ValidFrom, ValidTo
      WHERE WorkerID IN @worker_range
        AND Plant IN @plant_range
      INTO TABLE @DATA(valid_workers).

    LOOP AT checks ASSIGNING <check>.
      CLEAR <check>-is_active.
      LOOP AT valid_workers TRANSPORTING NO FIELDS
        WHERE WorkerID = <check>-worker_id
          AND Plant = <check>-plant
          AND WorkCenter = <check>-work_center
          AND ValidFrom <= <check>-execution_date
          AND ValidTo >= <check>-execution_date.
        <check>-is_active = abap_true.
        EXIT.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD is_worker_active.
    DATA(checks) = VALUE worker_checks(
      ( worker_id = worker_id
        plant = plant
        work_center = work_center
        execution_date = execution_date ) ).
    check_workers( CHANGING checks = checks ).
    result = VALUE #( checks[ 1 ]-is_active OPTIONAL ).
  ENDMETHOD.
ENDCLASS.

