CLASS lhc_assignment DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      status_active   TYPE ztb_pp_pos_asgn-status VALUE 'A',
      status_inactive TYPE ztb_pp_pos_asgn-status VALUE 'I'.

    TYPES assignment_row TYPE STRUCTURE FOR READ RESULT zr_pp_posassign\\Assignment.
    TYPES assignment_rows TYPE TABLE FOR READ RESULT zr_pp_posassign\\Assignment.
    TYPES: BEGIN OF assignment_key,
             work_center TYPE ztb_pp_pos_asgn-work_center,
             position_id TYPE ztb_pp_pos_asgn-position_id,
             worker_id   TYPE ztb_pp_pos_asgn-worker_id,
           END OF assignment_key,
           assignment_keys TYPE STANDARD TABLE OF assignment_key WITH EMPTY KEY.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Assignment RESULT result.
    METHODS deactivateSuperseded FOR DETERMINE ON SAVE
      IMPORTING keys FOR Assignment~deactivateSuperseded.
    METHODS validateAssignment FOR VALIDATE ON SAVE
      IMPORTING keys FOR Assignment~validateAssignment.

    METHODS check_assignment
      IMPORTING assignment    TYPE assignment_row
      RETURNING VALUE(result) TYPE string.
    "Các phân công Active khác của cùng công nhân (ghế cũ) hoặc của cùng vị trí
    "(người đang ngồi) trên DB.
    METHODS superseded_by
      IMPORTING assignment    TYPE assignment_row
      RETURNING VALUE(result) TYPE assignment_keys.
    "Đọc lại ứng viên qua EML để thấy thay đổi chưa save trong cùng LUW, trả
    "về những dòng vẫn còn Active.
    METHODS still_active
      IMPORTING candidates    TYPE assignment_keys
      RETURNING VALUE(result) TYPE assignment_rows.
ENDCLASS.

CLASS lhc_assignment IMPLEMENTATION.
  METHOD get_global_authorizations.
    "Fiori quản trị có toàn quyền; quyền theo work center chỉ áp cho mobile.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD deactivateSuperseded.
    READ ENTITIES OF zr_pp_posassign IN LOCAL MODE
      ENTITY Assignment
        FIELDS ( Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(assignments).

    "Điều chuyển: phân công cũ của công nhân chuyển I. Người đang ngồi ở vị
    "trí đích cũng chuyển I và không tự được xếp chỗ khác.
    DATA superseded TYPE TABLE FOR UPDATE zr_pp_posassign\\Assignment.
    LOOP AT assignments ASSIGNING FIELD-SYMBOL(<assignment>)
      WHERE Status = status_active.
      DATA(old_assignments) = superseded_by( <assignment> ).
      superseded = VALUE #( BASE superseded FOR old_assignment IN old_assignments
        ( %is_draft = if_abap_behv=>mk-off
          WorkCenter = old_assignment-work_center
          PositionID = old_assignment-position_id
          WorkerID = old_assignment-worker_id
          Status = status_inactive ) ).
    ENDLOOP.
    IF superseded IS INITIAL.
      RETURN.
    ENDIF.
    SORT superseded BY WorkCenter PositionID WorkerID.
    DELETE ADJACENT DUPLICATES FROM superseded COMPARING WorkCenter PositionID WorkerID.

    MODIFY ENTITIES OF zr_pp_posassign IN LOCAL MODE
      ENTITY Assignment
        UPDATE FIELDS ( Status )
        WITH superseded.
  ENDMETHOD.

  METHOD validateAssignment.
    READ ENTITIES OF zr_pp_posassign IN LOCAL MODE
      ENTITY Assignment
        FIELDS ( WorkCenter PositionID WorkerID Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(assignments).

    LOOP AT assignments ASSIGNING FIELD-SYMBOL(<assignment>).
      DATA(error_text) = check_assignment( <assignment> ).
      IF error_text IS INITIAL.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( %tky = <assignment>-%tky ) TO failed-assignment.
      APPEND VALUE #(
        %tky = <assignment>-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = error_text ) ) TO reported-assignment.
    ENDLOOP.
  ENDMETHOD.

  METHOD check_assignment.
    IF assignment-WorkCenter IS INITIAL
       OR assignment-PositionID IS INITIAL
       OR assignment-WorkerID IS INITIAL.
      result = 'Work center, vị trí và mã công nhân là bắt buộc'.
      RETURN.
    ENDIF.
    IF assignment-Status <> status_active AND assignment-Status <> status_inactive.
      result = 'Trạng thái chỉ nhận A (Active) hoặc I (Inactive)'.
      RETURN.
    ENDIF.
    IF assignment-Status <> status_active.
      RETURN.
    ENDIF.

    SELECT FROM ztb_pp_position
      FIELDS position_id
      WHERE work_center = @assignment-WorkCenter
        AND position_id = @assignment-PositionID
        AND status = 'A'
      INTO TABLE @DATA(active_positions)
      UP TO 1 ROWS.
    IF active_positions IS INITIAL.
      result = |Vị trí { assignment-WorkCenter }/{ assignment-PositionID } | &&
               |chưa có hoặc đang ngừng dùng|.
      RETURN.
    ENDIF.

    "Master nhân công chỉ dùng để kiểm tra công nhân thuộc work center của vị
    "trí tại ngày hiện tại; chuyển khác work center phải đổi master trước.
    DATA(today) = cl_abap_context_info=>get_system_date( ).
    SELECT FROM zi_pp_workerref
      FIELDS workerid
      WHERE workerid = @assignment-WorkerID
        AND workcenter = @assignment-WorkCenter
        AND validfrom <= @today
        AND validto >= @today
      INTO TABLE @DATA(workers)
      UP TO 1 ROWS.
    IF workers IS INITIAL.
      result = |Công nhân { assignment-WorkerID } không thuộc work center { assignment-WorkCenter }|.
      RETURN.
    ENDIF.

    "Lưới an toàn cho determination: nếu phân công cũ không chuyển được I
    "(ví dụ đang có người mở bản nháp) thì không cho lưu hai phân công Active.
    DATA(conflicts) = still_active( superseded_by( assignment ) ).
    IF conflicts IS NOT INITIAL.
      result = |Còn phân công Active { conflicts[ 1 ]-WorkerID } tại | &&
               |{ conflicts[ 1 ]-WorkCenter }/{ conflicts[ 1 ]-PositionID }; hãy thử lưu lại|.
    ENDIF.
  ENDMETHOD.

  METHOD superseded_by.
    SELECT FROM ztb_pp_pos_asgn
      FIELDS work_center, position_id, worker_id
      WHERE status = @status_active
        AND ( worker_id = @assignment-WorkerID
              OR ( work_center = @assignment-WorkCenter
                   AND position_id = @assignment-PositionID ) )
        AND NOT ( work_center = @assignment-WorkCenter
                  AND position_id = @assignment-PositionID
                  AND worker_id = @assignment-WorkerID )
      INTO TABLE @result.
  ENDMETHOD.

  METHOD still_active.
    IF candidates IS INITIAL.
      RETURN.
    ENDIF.
    READ ENTITIES OF zr_pp_posassign IN LOCAL MODE
      ENTITY Assignment
        FIELDS ( Status )
        WITH VALUE #( FOR candidate IN candidates
          ( %is_draft = if_abap_behv=>mk-off
            WorkCenter = candidate-work_center
            PositionID = candidate-position_id
            WorkerID = candidate-worker_id ) )
      RESULT DATA(rows).
    result = VALUE #( FOR row IN rows WHERE ( Status = status_active ) ( row ) ).
  ENDMETHOD.
ENDCLASS.
