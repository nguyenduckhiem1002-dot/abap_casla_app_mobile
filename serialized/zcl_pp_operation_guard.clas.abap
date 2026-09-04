CLASS zcl_pp_operation_guard DEFINITION
  PUBLIC FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    TYPES: BEGIN OF result,
             is_valid         TYPE abap_bool,
             error_code       TYPE c LENGTH 40,
             production_order TYPE ztb_pp_op_alloc-production_order,
             operation_no     TYPE ztb_pp_op_alloc-operation_no,
             plant            TYPE ztb_pp_op_alloc-plant,
             work_center      TYPE ztb_pp_op_alloc-work_center,
             operation_qty    TYPE ztb_pp_op_alloc-operation_qty,
             uom              TYPE ztb_pp_op_alloc-uom,
             ma_congdoan      TYPE c LENGTH 7,
           END OF result.

    CLASS-METHODS resolve
      IMPORTING
        production_order TYPE ztb_pp_op_alloc-production_order
        operation_no     TYPE ztb_pp_op_alloc-operation_no
      RETURNING VALUE(value) TYPE result.
ENDCLASS.

CLASS zcl_pp_operation_guard IMPLEMENTATION.
  METHOD resolve.
    value-production_order = production_order.
    value-operation_no = operation_no.

    IF production_order IS INITIAL OR operation_no IS INITIAL.
      value-error_code = 'ORDER_OPERATION_REQUIRED'.
      RETURN.
    ENDIF.

    "Chỉ xét các system status SAP đang active. REL là bắt buộc; các trạng thái
    "kết thúc/xóa luôn có ưu tiên chặn kể cả khi REL vẫn còn active.
    SELECT FROM I_ManufacturingOrderStatus
      FIELDS StatusCode
      WHERE ManufacturingOrder = @production_order
        AND IsUserStatus = @abap_false
        AND StatusIsActive = @abap_true
      INTO TABLE @DATA(active_statuses).

    IF active_statuses IS INITIAL.
      value-error_code = 'MANUFACTURING_ORDER_NOT_FOUND'.
      RETURN.
    ENDIF.

    DATA(released) = xsdbool(
      line_exists( active_statuses[ StatusCode = 'I0002' ] ) ).
    DATA(blocked) = xsdbool(
         line_exists( active_statuses[ StatusCode = 'I0045' ] )
      OR line_exists( active_statuses[ StatusCode = 'I0046' ] )
      OR line_exists( active_statuses[ StatusCode = 'I0076' ] ) ).

    IF released = abap_false OR blocked = abap_true.
      value-error_code = 'MANUFACTURING_ORDER_NOT_RELEASED'.
      RETURN.
    ENDIF.

    SELECT FROM I_ManufacturingOrderOperation
      FIELDS ManufacturingOrder,
             ManufacturingOrderOperation_2,
             Plant,
             WorkCenterInternalID,
             OperationControlProfile,
             OperationIsToBeDeleted,
             OperationStandardTextCode,
             OperationUnit,
             OpPlannedTotalQuantity
      WHERE ManufacturingOrder = @production_order
        AND ManufacturingOrderOperation_2 = @operation_no
      INTO TABLE @DATA(operations)
      UP TO 2 ROWS.

    IF lines( operations ) <> 1.
      value-error_code = COND #(
        WHEN operations IS INITIAL THEN 'MANUFACTURING_OPERATION_NOT_FOUND'
        ELSE 'MANUFACTURING_OPERATION_AMBIGUOUS' ).
      RETURN.
    ENDIF.

    DATA(operation) = operations[ 1 ].
    IF operation-OperationControlProfile IS INITIAL.
      value-error_code = 'OPERATION_CONTROL_PROFILE_REQUIRED'.
      RETURN.
    ENDIF.

    "Tenant co the khoa control profile bang config. Neu chua cau hinh thi
    "chap nhan profile khong rong cua operation SAP thay vi hardcode YBP1.
    SELECT FROM ztb_mob_config
      FIELDS config_value
      WHERE config_key = 'PP_OPERATION_CONTROL_PROFILE'
        AND is_active = @abap_true
      INTO TABLE @DATA(profile_configs)
      UP TO 1 ROWS.
    DATA(required_profile) = VALUE #(
      profile_configs[ 1 ]-config_value OPTIONAL ).
    IF required_profile IS NOT INITIAL
       AND operation-OperationControlProfile <> required_profile.
      value-error_code = 'OPERATION_CONTROL_PROFILE_INVALID'.
      RETURN.
    ENDIF.
    IF operation-OperationIsToBeDeleted IS NOT INITIAL.
      value-error_code = 'OPERATION_MARKED_FOR_DELETION'.
      RETURN.
    ENDIF.
    IF operation-OperationStandardTextCode IS INITIAL.
      value-error_code = 'OPERATION_STANDARD_TEXT_REQUIRED'.
      RETURN.
    ENDIF.
    IF operation-OpPlannedTotalQuantity <= 0
       OR operation-OperationUnit IS INITIAL
       OR operation-Plant IS INITIAL
       OR operation-WorkCenterInternalID IS INITIAL.
      value-error_code = 'OPERATION_MASTER_DATA_INCOMPLETE'.
      RETURN.
    ENDIF.

    SELECT FROM I_WorkCenter
      FIELDS WorkCenter
      WHERE Plant = @operation-Plant
        AND WorkCenterInternalID = @operation-WorkCenterInternalID
      INTO TABLE @DATA(work_centers)
      UP TO 2 ROWS.

    IF lines( work_centers ) <> 1.
      value-error_code = COND #(
        WHEN work_centers IS INITIAL THEN 'WORK_CENTER_NOT_FOUND'
        ELSE 'WORK_CENTER_AMBIGUOUS' ).
      RETURN.
    ENDIF.

    value-plant = operation-Plant.
    value-work_center = work_centers[ 1 ]-WorkCenter.
    value-operation_qty = operation-OpPlannedTotalQuantity.
    value-uom = operation-OperationUnit.
    value-ma_congdoan = operation-OperationStandardTextCode.
    value-is_valid = abap_true.
  ENDMETHOD.
ENDCLASS.
