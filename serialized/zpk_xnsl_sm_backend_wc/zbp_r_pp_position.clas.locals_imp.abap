CLASS lhc_position DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      status_active   TYPE ztb_pp_position-status VALUE 'A',
      status_inactive TYPE ztb_pp_position-status VALUE 'I'.

    TYPES position_row TYPE STRUCTURE FOR READ RESULT zr_pp_position\\Position.
    TYPES position_rows TYPE TABLE FOR READ RESULT zr_pp_position\\Position.
    TYPES: BEGIN OF position_key,
             work_center TYPE ztb_pp_position-work_center,
             position_id TYPE ztb_pp_position-position_id,
             machine_id  TYPE ztb_pp_position-machine_id,
           END OF position_key,
           position_keys TYPE STANDARD TABLE OF position_key WITH EMPTY KEY.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Position RESULT result.
    "Facade mobile cho giám sát; logic và kiểm tra quyền nằm trong
    "ZCL_PP_POSITION_API.
    METHODS getPositionBoard FOR MODIFY
      IMPORTING keys   FOR ACTION Position~getPositionBoard
      RESULT    result.
    METHODS submitPositionCreate FOR MODIFY
      IMPORTING keys   FOR ACTION Position~submitPositionCreate
      RESULT    result.
    METHODS submitMachineChange FOR MODIFY
      IMPORTING keys   FOR ACTION Position~submitMachineChange
      RESULT    result.
    METHODS deactivateReplacedMachine FOR DETERMINE ON SAVE
      IMPORTING keys FOR Position~deactivateReplacedMachine.
    METHODS validatePosition FOR VALIDATE ON SAVE
      IMPORTING keys FOR Position~validatePosition.

    METHODS check_position
      IMPORTING position      TYPE position_row
      RETURNING VALUE(result) TYPE string.
    "Các dòng Active khác của cùng vị trí (máy cũ) trên DB.
    METHODS other_machines_of_position
      IMPORTING position      TYPE position_row
      RETURNING VALUE(result) TYPE position_keys.
    "Đọc lại ứng viên qua EML để thấy thay đổi chưa save trong cùng LUW, trả
    "về những dòng vẫn còn Active.
    METHODS still_active
      IMPORTING candidates    TYPE position_keys
      RETURNING VALUE(result) TYPE position_rows.

    TYPES failed_response TYPE RESPONSE FOR FAILED zr_pp_position.
    TYPES reported_response TYPE RESPONSE FOR REPORTED zr_pp_position.
    "Lỗi facade mobile: request bị từ chối, message là mã lỗi.
    METHODS report_failure
      IMPORTING cid TYPE string text TYPE string
      CHANGING failed TYPE failed_response reported TYPE reported_response.
ENDCLASS.

CLASS lhc_position IMPLEMENTATION.
  METHOD get_global_authorizations.
    "Fiori quản trị có toàn quyền; cổng vào là IAM app của service admin.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.
    "Facade mobile tự xác thực token, thiết bị và phạm vi Work Center. Gán
    "thẳng thay vì IF theo request: RAP chỉ đọc các thao tác được yêu cầu.
    result-%action-getPositionBoard = if_abap_behv=>auth-allowed.
    result-%action-submitPositionCreate = if_abap_behv=>auth-allowed.
    result-%action-submitMachineChange = if_abap_behv=>auth-allowed.
  ENDMETHOD.

  METHOD deactivateReplacedMachine.
    READ ENTITIES OF zr_pp_position IN LOCAL MODE
      ENTITY Position
        FIELDS ( Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(positions).

    "Một vị trí chỉ có một máy đang dùng: gán máy mới (dòng Active mới) thì
    "dòng chứa máy cũ của cùng vị trí chuyển I.
    DATA replaced TYPE TABLE FOR UPDATE zr_pp_position\\Position.
    LOOP AT positions ASSIGNING FIELD-SYMBOL(<position>)
      WHERE Status = status_active.
      DATA(old_machines) = other_machines_of_position( <position> ).
      replaced = VALUE #( BASE replaced FOR old_machine IN old_machines
        ( %is_draft = if_abap_behv=>mk-off
          WorkCenter = old_machine-work_center
          PositionID = old_machine-position_id
          MachineID = old_machine-machine_id
          Status = status_inactive ) ).
    ENDLOOP.
    IF replaced IS INITIAL.
      RETURN.
    ENDIF.
    SORT replaced BY WorkCenter PositionID MachineID.
    DELETE ADJACENT DUPLICATES FROM replaced COMPARING WorkCenter PositionID MachineID.

    MODIFY ENTITIES OF zr_pp_position IN LOCAL MODE
      ENTITY Position
        UPDATE FIELDS ( Status )
        WITH replaced.
  ENDMETHOD.

  METHOD validatePosition.
    READ ENTITIES OF zr_pp_position IN LOCAL MODE
      ENTITY Position
        FIELDS ( WorkCenter PositionID MachineID Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(positions).

    LOOP AT positions ASSIGNING FIELD-SYMBOL(<position>).
      DATA(error_text) = check_position( <position> ).
      IF error_text IS INITIAL.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( %tky = <position>-%tky ) TO failed-position.
      APPEND VALUE #(
        %tky = <position>-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = error_text ) ) TO reported-position.
    ENDLOOP.
  ENDMETHOD.

  METHOD check_position.
    IF position-WorkCenter IS INITIAL
       OR position-PositionID IS INITIAL
       OR position-MachineID IS INITIAL.
      result = 'Work center, vị trí và mã máy là bắt buộc'.
      RETURN.
    ENDIF.
    IF position-Status <> status_active AND position-Status <> status_inactive.
      result = 'Trạng thái chỉ nhận A (Active) hoặc I (Inactive)'.
      RETURN.
    ENDIF.

    SELECT FROM zi_mob_workcenter_vh
      FIELDS workcenter
      WHERE workcenter = @position-WorkCenter
      INTO TABLE @DATA(work_centers)
      UP TO 1 ROWS.
    IF work_centers IS INITIAL.
      result = |Work center { position-WorkCenter } không tồn tại|.
      RETURN.
    ENDIF.
    IF position-Status <> status_active.
      RETURN.
    ENDIF.

    "Lưới an toàn cho determination: nếu dòng máy cũ không chuyển được I
    "(ví dụ đang có người mở bản nháp) thì không cho lưu hai máy cùng lúc.
    DATA(same_position) = still_active( other_machines_of_position( position ) ).
    IF same_position IS NOT INITIAL.
      result = |Vị trí { position-WorkCenter }/{ position-PositionID } vẫn còn máy | &&
               |{ same_position[ 1 ]-MachineID } đang dùng; hãy thử lưu lại|.
      RETURN.
    ENDIF.

    DATA elsewhere TYPE position_keys.
    SELECT FROM ztb_pp_position
      FIELDS work_center, position_id, machine_id
      WHERE machine_id = @position-MachineID
        AND status = @status_active
        AND NOT ( work_center = @position-WorkCenter
                  AND position_id = @position-PositionID )
      INTO TABLE @elsewhere.
    DATA(machine_in_use) = still_active( elsewhere ).
    IF machine_in_use IS NOT INITIAL.
      result = |Máy { position-MachineID } đang dùng ở vị trí | &&
               |{ machine_in_use[ 1 ]-WorkCenter }/{ machine_in_use[ 1 ]-PositionID }; | &&
               |hãy ngừng dùng ở đó trước|.
    ENDIF.
  ENDMETHOD.

  METHOD other_machines_of_position.
    SELECT FROM ztb_pp_position
      FIELDS work_center, position_id, machine_id
      WHERE work_center = @position-WorkCenter
        AND position_id = @position-PositionID
        AND machine_id <> @position-MachineID
        AND status = @status_active
      INTO TABLE @result.
  ENDMETHOD.

  METHOD still_active.
    IF candidates IS INITIAL.
      RETURN.
    ENDIF.
    READ ENTITIES OF zr_pp_position IN LOCAL MODE
      ENTITY Position
        FIELDS ( Status )
        WITH VALUE #( FOR candidate IN candidates
          ( %is_draft = if_abap_behv=>mk-off
            WorkCenter = candidate-work_center
            PositionID = candidate-position_id
            MachineID = candidate-machine_id ) )
      RESULT DATA(rows).
    result = VALUE #( FOR row IN rows WHERE ( Status = status_active ) ( row ) ).
  ENDMETHOD.

  METHOD getPositionBoard.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.
    IF lines( keys ) > 1.
      LOOP AT keys ASSIGNING FIELD-SYMBOL(<board_key>).
        report_failure( EXPORTING cid = CONV string( <board_key>-%cid )
                          text = 'Mỗi yêu cầu chỉ được xem một sơ đồ vị trí'
                        CHANGING failed = failed reported = reported ).
      ENDLOOP.
      RETURN.
    ENDIF.
    DATA(input) = VALUE #( keys[ 1 ]-%param OPTIONAL ).
    DATA(cid) = CONV string( keys[ 1 ]-%cid ).
    TRY.
        DATA(board) = zcl_pp_position_api=>get_board(
          access_token = CONV string( input-AccessToken )
          device_id = input-DeviceID
          work_center = input-WorkCenter ).
      CATCH cx_abap_message_digest zcx_mob_config.
        report_failure( EXPORTING cid = cid text = 'AUTH_FAILED'
                        CHANGING failed = failed reported = reported ).
        RETURN.
    ENDTRY.
    IF board-is_valid = abap_false.
      report_failure( EXPORTING cid = cid text = CONV string( board-error_code )
                      CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    result = VALUE #( ( %cid = cid %param = VALUE #(
      WorkCenterCount = board-work_center_count
      PositionCount = lines( board-seats )
      _Positions = VALUE #( FOR seat IN board-seats
        ( WorkCenter = seat-work_center
          PositionID = seat-position_id
          MachineID = seat-machine_id
          PositionName = seat-position_name
          WorkerID = seat-worker_id
          WorkerName = seat-worker_name
          IsOccupied = xsdbool( seat-worker_id IS NOT INITIAL ) ) ) ) ) ).
  ENDMETHOD.

  METHOD submitPositionCreate.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.
    IF lines( keys ) > 1.
      LOOP AT keys ASSIGNING FIELD-SYMBOL(<create_key>).
        report_failure( EXPORTING cid = CONV string( <create_key>-%cid )
                          text = 'Mỗi yêu cầu chỉ được tạo một vị trí'
                        CHANGING failed = failed reported = reported ).
      ENDLOOP.
      RETURN.
    ENDIF.
    DATA(input) = VALUE #( keys[ 1 ]-%param OPTIONAL ).
    DATA(cid) = CONV string( keys[ 1 ]-%cid ).
    TRY.
        DATA(outcome) = zcl_pp_position_api=>create_position(
          access_token = CONV string( input-AccessToken )
          device_id = input-DeviceID
          work_center = input-WorkCenter
          position_id = input-PositionID
          machine_id = input-MachineID
          position_name = input-PositionName ).
      CATCH cx_abap_message_digest zcx_mob_config.
        report_failure( EXPORTING cid = cid text = 'AUTH_FAILED'
                        CHANGING failed = failed reported = reported ).
        RETURN.
    ENDTRY.
    IF outcome-is_valid = abap_false.
      report_failure( EXPORTING cid = cid text = CONV string( outcome-error_code )
                      CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    result = VALUE #( ( %cid = cid %param = VALUE #(
      Status = 'SUCCESS'
      WorkCenter = outcome-work_center
      PositionID = outcome-position_id
      MachineID = outcome-machine_id
      WorkerID = outcome-worker_id
      Message = 'Đã tạo vị trí' ) ) ).
  ENDMETHOD.

  METHOD submitMachineChange.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.
    IF lines( keys ) > 1.
      LOOP AT keys ASSIGNING FIELD-SYMBOL(<machine_key>).
        report_failure( EXPORTING cid = CONV string( <machine_key>-%cid )
                          text = 'Mỗi yêu cầu chỉ được đổi máy một vị trí'
                        CHANGING failed = failed reported = reported ).
      ENDLOOP.
      RETURN.
    ENDIF.
    DATA(input) = VALUE #( keys[ 1 ]-%param OPTIONAL ).
    DATA(cid) = CONV string( keys[ 1 ]-%cid ).
    TRY.
        DATA(outcome) = zcl_pp_position_api=>change_machine(
          access_token = CONV string( input-AccessToken )
          device_id = input-DeviceID
          work_center = input-WorkCenter
          position_id = input-PositionID
          machine_id = input-MachineID ).
      CATCH cx_abap_message_digest zcx_mob_config.
        report_failure( EXPORTING cid = cid text = 'AUTH_FAILED'
                        CHANGING failed = failed reported = reported ).
        RETURN.
    ENDTRY.
    IF outcome-is_valid = abap_false.
      report_failure( EXPORTING cid = cid text = CONV string( outcome-error_code )
                      CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    result = VALUE #( ( %cid = cid %param = VALUE #(
      Status = 'SUCCESS'
      WorkCenter = outcome-work_center
      PositionID = outcome-position_id
      MachineID = outcome-machine_id
      WorkerID = outcome-worker_id
      Message = 'Đã đổi máy của vị trí' ) ) ).
  ENDMETHOD.

  METHOD report_failure.
    APPEND VALUE #( %cid = cid ) TO failed-position.
    APPEND VALUE #( %cid = cid
      %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-error text = text ) )
      TO reported-position.
  ENDMETHOD.
ENDCLASS.
