CLASS zcl_pp_shift_resolver DEFINITION PUBLIC FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    TYPES: BEGIN OF context,
             is_valid         TYPE abap_bool,
             error_code       TYPE c LENGTH 40,
             shift_id         TYPE ztb_pp_shift-shift_id,
             work_date        TYPE d,
             executed_at      TYPE utclong,
             shift_start_at   TYPE utclong,
             shift_end_at     TYPE utclong,
             shift_time_zone  TYPE ztb_pp_shift-time_zone,
             shift_valid_from TYPE d,
           END OF context.
    CLASS-METHODS resolve
      IMPORTING plant          TYPE ztb_pp_shift-plant
                shift_id       TYPE ztb_pp_shift-shift_id
                executed_at    TYPE utclong
                execution_date TYPE d
                sync_item_uuid TYPE sysuuid_x16 OPTIONAL
      RETURNING VALUE(result)  TYPE context.
    "Strict [start, end) window; the work date is derived from executed_at.
    CLASS-METHODS calculate
      IMPORTING config        TYPE ztb_pp_shift
                executed_at   TYPE utclong
      RETURNING VALUE(result) TYPE context.
    "Window of one given work date: open from the shift start until the end
    "of the calendar day the shift ends on, so work can be entered late after
    "the shift is over. shift_end_at still reports the real end of the shift.
    CLASS-METHODS calculate_for_work_date
      IMPORTING config        TYPE ztb_pp_shift
                executed_at   TYPE utclong
                work_date     TYPE d
      RETURNING VALUE(result) TYPE context.
  PRIVATE SECTION.
    CLASS-METHODS is_config_consistent
      IMPORTING config        TYPE ztb_pp_shift
      RETURNING VALUE(result) TYPE abap_bool.
ENDCLASS.

CLASS zcl_pp_shift_resolver IMPLEMENTATION.
  METHOD resolve.
    "A retry uses the original snapshot, even after configuration is changed.
    IF sync_item_uuid IS NOT INITIAL.
      SELECT FROM ztb_pp_alloc_txn AS txn
        INNER JOIN ztb_pp_op_alloc AS op ON op~operation_uuid = txn~operation_uuid
        FIELDS txn~shift_id, txn~work_date, txn~execution_date, txn~executed_at,
               txn~shift_start_at, txn~shift_end_at, txn~shift_time_zone, txn~shift_valid_from
        WHERE txn~sync_item_uuid = @sync_item_uuid AND op~plant = @plant
        INTO TABLE @DATA(receipts) UP TO 2 ROWS.
      IF lines( receipts ) = 1.
        DATA(receipt) = receipts[ 1 ].
        result = CORRESPONDING #( receipt ).
        IF result-work_date IS INITIAL.
          result-work_date = receipt-execution_date.
        ENDIF.
        result-is_valid = xsdbool( shift_id = receipt-shift_id
          AND executed_at = receipt-executed_at
          AND ( execution_date IS INITIAL OR execution_date = result-work_date ) ).
        IF result-is_valid = abap_false.
          result-error_code = 'IDEMPOTENCY_KEY_REUSED'.
        ENDIF.
        RETURN.
      ENDIF.
    ENDIF.
    "Legacy requests retain their business date; never invent an occurrence time.
    IF shift_id IS INITIAL AND executed_at IS INITIAL.
      result-work_date = execution_date.
      result-is_valid = xsdbool( execution_date IS NOT INITIAL ).
      IF result-is_valid = abap_false.
        result-error_code = 'EXECUTION_DATE_REQUIRED'.
      ENDIF.
      RETURN.
    ENDIF.
    IF shift_id IS INITIAL OR executed_at IS INITIAL.
      result-error_code = 'SHIFT_AND_EXECUTED_AT_REQUIRED'.
      RETURN.
    ENDIF.

    CONSTANTS clock_skew_minutes TYPE i VALUE 3.
    IF executed_at > utclong_add( val     = utclong_current( )
                                  minutes = clock_skew_minutes ).
      result-error_code = 'EXECUTED_AT_IN_FUTURE'.
      RETURN.
    ENDIF.

    SELECT FROM ztb_pp_shift FIELDS *
      WHERE plant = @plant AND shift_id = @shift_id AND is_active = 'A'
      INTO TABLE @DATA(configs).

    "New clients send the shift's business date. Accept the transaction for
    "that work date from the shift start until the end of the day the shift
    "ends on (late entry after the shift).
    IF execution_date IS NOT INITIAL.
      DATA(dated_matches) = 0.
      LOOP AT configs INTO DATA(dated_config).
        DATA(dated) = calculate_for_work_date( config = dated_config
          executed_at = executed_at work_date = execution_date ).
        IF dated-is_valid = abap_true.
          dated_matches += 1.
          result = dated.
        ENDIF.
      ENDLOOP.
      IF dated_matches = 1.
        RETURN.
      ELSEIF dated_matches > 1.
        CLEAR result.
        result-error_code = 'SHIFT_CONFIG_AMBIGUOUS'.
        RETURN.
      ENDIF.
      CLEAR result.
      "Not inside the chosen date's window: fall through to the strict check
      "so a wrong business date still reports SHIFT_WORK_DATE_MISMATCH.
    ENDIF.

    DATA(matches) = 0.
    LOOP AT configs INTO DATA(config).
      DATA(candidate) = calculate( config = config executed_at = executed_at ).
      IF candidate-is_valid = abap_true.
        matches += 1.
        result = candidate.
      ENDIF.
    ENDLOOP.
    IF matches <> 1.
      CLEAR result.
      result-error_code = COND #( WHEN matches = 0 THEN 'SHIFT_NOT_APPLICABLE'
                                 ELSE 'SHIFT_CONFIG_AMBIGUOUS' ).
      RETURN.
    ENDIF.
    "ExecutionDate supplied by new clients is the shift's business date.
    IF execution_date IS NOT INITIAL AND execution_date <> result-work_date.
      result-is_valid = abap_false.
      result-error_code = 'SHIFT_WORK_DATE_MISMATCH'.
    ENDIF.
  ENDMETHOD.

  METHOD calculate.
    result-error_code = 'SHIFT_CONFIG_INVALID'.
    IF executed_at IS INITIAL OR is_config_consistent( config ) = abap_false.
      RETURN.
    ENDIF.
    DATA start_at TYPE utclong.
    DATA end_at TYPE utclong.
    DATA end_date TYPE d.
    TRY.
        CONVERT UTCLONG executed_at TIME ZONE config-time_zone
          INTO DATE DATA(local_date) TIME DATA(local_time).
        DATA(work_date) = local_date.
        IF config-end_day_offset = 1 AND local_time < config-end_time.
          work_date -= 1.
        ENDIF.
        IF work_date < config-valid_from OR work_date > config-valid_to.
          RETURN.
        ENDIF.
        end_date = work_date + config-end_day_offset.
        CONVERT DATE work_date TIME config-start_time TIME ZONE config-time_zone
          INTO UTCLONG start_at.
        CONVERT DATE end_date TIME config-end_time TIME ZONE config-time_zone
          INTO UTCLONG end_at.
      CATCH cx_parameter_invalid_range cx_sy_conversion_error.
        RETURN.
    ENDTRY.
    IF executed_at < start_at OR executed_at >= end_at.
      result-error_code = 'OUTSIDE_SHIFT'.
      RETURN.
    ENDIF.
    result = VALUE #( is_valid = abap_true shift_id = config-shift_id
      work_date = work_date executed_at = executed_at
      shift_start_at = start_at shift_end_at = end_at
      shift_time_zone = config-time_zone shift_valid_from = config-valid_from ).
  ENDMETHOD.

  METHOD calculate_for_work_date.
    result-error_code = 'SHIFT_CONFIG_INVALID'.
    IF executed_at IS INITIAL OR work_date IS INITIAL
       OR is_config_consistent( config ) = abap_false.
      RETURN.
    ENDIF.
    IF work_date < config-valid_from OR work_date > config-valid_to.
      result-error_code = 'SHIFT_NOT_APPLICABLE'.
      RETURN.
    ENDIF.
    DATA start_at TYPE utclong.
    DATA end_at TYPE utclong.
    DATA deadline_at TYPE utclong.
    DATA end_date TYPE d.
    DATA deadline_date TYPE d.
    DATA midnight TYPE t VALUE '000000'.
    end_date = work_date + config-end_day_offset.
    deadline_date = end_date + 1.
    TRY.
        CONVERT DATE work_date TIME config-start_time TIME ZONE config-time_zone
          INTO UTCLONG start_at.
        CONVERT DATE end_date TIME config-end_time TIME ZONE config-time_zone
          INTO UTCLONG end_at.
        "Midnight after the day the shift ends, in the shift's time zone.
        CONVERT DATE deadline_date TIME midnight TIME ZONE config-time_zone
          INTO UTCLONG deadline_at.
      CATCH cx_parameter_invalid_range cx_sy_conversion_error.
        RETURN.
    ENDTRY.
    IF executed_at < start_at OR executed_at >= deadline_at.
      result-error_code = 'OUTSIDE_SHIFT'.
      RETURN.
    ENDIF.
    result = VALUE #( is_valid = abap_true shift_id = config-shift_id
      work_date = work_date executed_at = executed_at
      shift_start_at = start_at shift_end_at = end_at
      shift_time_zone = config-time_zone shift_valid_from = config-valid_from ).
  ENDMETHOD.

  METHOD is_config_consistent.
    result = xsdbool( config-time_zone IS NOT INITIAL
      AND config-valid_from IS NOT INITIAL
      AND config-valid_to >= config-valid_from
      AND config-end_day_offset <= 1
      AND config-start_time <= '235959'
      AND config-end_time <= '235959'
      AND NOT ( config-end_day_offset = 0 AND config-end_time <= config-start_time )
      AND NOT ( config-end_day_offset = 1 AND config-end_time > config-start_time ) ).
  ENDMETHOD.
ENDCLASS.
