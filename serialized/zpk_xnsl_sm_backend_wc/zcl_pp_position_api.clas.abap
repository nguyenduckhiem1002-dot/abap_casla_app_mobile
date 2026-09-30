"API mobile cho vị trí làm việc của công nhân: sơ đồ ghế, điều chuyển và cho
"rời vị trí. Mọi thao tác xác thực access token đầy đủ (token, hạn, thiết bị,
"trạng thái tài khoản) và chỉ cho phép trên Work Center mà tài khoản được cấp
"function PP_POS_TRANSFER. Ghi dữ liệu đi qua BO ZR_PP_PosAssign, nên dùng đúng
"quy tắc của màn Fiori: phân công Active mới tự chuyển phân công cũ của công
"nhân và người đang ngồi ở vị trí đó sang I.
CLASS zcl_pp_position_api DEFINITION
  PUBLIC FINAL CREATE PRIVATE.

  PUBLIC SECTION.
    CONSTANTS func_position TYPE ztb_mob_func-func_id VALUE 'PP_POS_TRANSFER'.

    TYPES failure_code TYPE c LENGTH 40.
    TYPES: BEGIN OF seat,
             work_center   TYPE ztb_pp_position-work_center,
             position_id   TYPE ztb_pp_position-position_id,
             machine_id    TYPE ztb_pp_position-machine_id,
             position_name TYPE ztb_pp_position-position_name,
             worker_id     TYPE ztb_pp_pos_asgn-worker_id,
             worker_name   TYPE zi_pp_workerref-workername,
           END OF seat,
           seats TYPE STANDARD TABLE OF seat WITH EMPTY KEY.
    TYPES: BEGIN OF board,
             is_valid          TYPE abap_bool,
             error_code        TYPE failure_code,
             work_center_count TYPE i,
             seats             TYPE seats,
           END OF board.
    TYPES: BEGIN OF outcome,
             is_valid    TYPE abap_bool,
             error_code  TYPE failure_code,
             work_center TYPE ztb_pp_position-work_center,
             position_id TYPE ztb_pp_position-position_id,
             machine_id  TYPE ztb_pp_position-machine_id,
             worker_id   TYPE ztb_pp_pos_asgn-worker_id,
           END OF outcome.

    "Sơ đồ vị trí đang dùng và người đang ngồi. Không truyền Work Center thì
    "trả tất cả Work Center trong phạm vi quyền.
    CLASS-METHODS get_board
      IMPORTING access_token  TYPE string
                device_id     TYPE ztb_mob_session-device_id
                work_center   TYPE ztb_pp_position-work_center OPTIONAL
      RETURNING VALUE(result) TYPE board
      RAISING   cx_abap_message_digest zcx_mob_config.

    "Xếp công nhân vào vị trí. Gọi lại khi công nhân đã ngồi đúng vị trí đó vẫn
    "trả thành công, để mobile retry sau timeout không bị báo lỗi giả.
    CLASS-METHODS transfer
      IMPORTING access_token  TYPE string
                device_id     TYPE ztb_mob_session-device_id
                work_center   TYPE ztb_pp_position-work_center
                position_id   TYPE ztb_pp_position-position_id
                worker_id     TYPE ztb_pp_pos_asgn-worker_id
      RETURNING VALUE(result) TYPE outcome
      RAISING   cx_abap_message_digest zcx_mob_config.

    "Cho người đang ngồi rời vị trí mà không xếp chỗ mới.
    CLASS-METHODS release
      IMPORTING access_token  TYPE string
                device_id     TYPE ztb_mob_session-device_id
                work_center   TYPE ztb_pp_position-work_center
                position_id   TYPE ztb_pp_position-position_id
      RETURNING VALUE(result) TYPE outcome
      RAISING   cx_abap_message_digest zcx_mob_config.

  PRIVATE SECTION.
    "Xác thực token và trả về các Work Center được cấp function vị trí.
    CLASS-METHODS authorize
      IMPORTING access_token TYPE string
                device_id    TYPE ztb_mob_session-device_id
      EXPORTING work_centers TYPE zcl_mob_token_validator=>work_centers
                error_code   TYPE failure_code
      RAISING   cx_abap_message_digest zcx_mob_config.

    CLASS-METHODS active_machine
      IMPORTING work_center   TYPE ztb_pp_position-work_center
                position_id   TYPE ztb_pp_position-position_id
      RETURNING VALUE(result) TYPE ztb_pp_position-machine_id.

    CLASS-METHODS is_worker_of_work_center
      IMPORTING worker_id     TYPE ztb_pp_pos_asgn-worker_id
                work_center   TYPE ztb_pp_position-work_center
      RETURNING VALUE(result) TYPE abap_bool.

    CLASS-METHODS fill_worker_names
      CHANGING seats TYPE seats.

    CLASS-METHODS save_assignment
      IMPORTING work_center   TYPE ztb_pp_position-work_center
                position_id   TYPE ztb_pp_position-position_id
                worker_id     TYPE ztb_pp_pos_asgn-worker_id
                status        TYPE ztb_pp_pos_asgn-status
      RETURNING VALUE(result) TYPE failure_code.
ENDCLASS.

CLASS zcl_pp_position_api IMPLEMENTATION.
  METHOD authorize.
    CLEAR: work_centers, error_code.
    IF access_token IS INITIAL OR device_id IS INITIAL.
      error_code = 'AUTH_FAILED'.
      RETURN.
    ENDIF.
    "validate_token kiểm tra token hash, hạn, thiết bị, trạng thái tài khoản,
    "bắt buộc đổi mật khẩu và function được cấp.
    DATA(auth) = zcl_mob_token_validator=>validate_token(
      token = access_token
      device_id = device_id
      required_func = func_position ).
    IF auth-is_valid = abap_false.
      error_code = auth-error_code.
      RETURN.
    ENDIF.
    work_centers = zcl_mob_token_validator=>get_func_work_centers(
      user_uuid = auth-user_uuid
      func_id = func_position ).
    IF work_centers IS INITIAL.
      error_code = 'NO_WORK_CENTER_SCOPE'.
    ENDIF.
  ENDMETHOD.

  METHOD get_board.
    authorize( EXPORTING access_token = access_token device_id = device_id
               IMPORTING work_centers = DATA(work_centers)
                         error_code = result-error_code ).
    IF result-error_code IS NOT INITIAL.
      RETURN.
    ENDIF.

    DATA scope TYPE RANGE OF ztb_pp_position-work_center.
    IF work_center IS NOT INITIAL.
      IF NOT line_exists( work_centers[ table_line = work_center ] ).
        result-error_code = 'NO_WORK_CENTER_SCOPE'.
        RETURN.
      ENDIF.
      scope = VALUE #( ( sign = 'I' option = 'EQ' low = work_center ) ).
    ELSE.
      "Range không bao giờ rỗng ở đây (authorize đã chặn), nên không có nguy cơ
      "đọc toàn bộ vị trí của mọi Work Center.
      scope = VALUE #( FOR allowed IN work_centers
                       ( sign = 'I' option = 'EQ' low = allowed ) ).
    ENDIF.

    SELECT FROM ztb_pp_position AS position
      LEFT OUTER JOIN ztb_pp_pos_asgn AS assignment
        ON  assignment~work_center = position~work_center
        AND assignment~position_id = position~position_id
        AND assignment~status = 'A'
      FIELDS position~work_center, position~position_id, position~machine_id,
             position~position_name, assignment~worker_id
      WHERE position~status = 'A'
        AND position~work_center IN @scope
      ORDER BY position~work_center, position~position_id
      INTO CORRESPONDING FIELDS OF TABLE @result-seats.

    fill_worker_names( CHANGING seats = result-seats ).
    result-work_center_count = lines( scope ).
    result-is_valid = abap_true.
  ENDMETHOD.

  METHOD transfer.
    result = VALUE #( work_center = work_center position_id = position_id
                      worker_id = worker_id ).
    authorize( EXPORTING access_token = access_token device_id = device_id
               IMPORTING work_centers = DATA(work_centers)
                         error_code = result-error_code ).
    IF result-error_code IS NOT INITIAL.
      RETURN.
    ENDIF.
    IF work_center IS INITIAL OR position_id IS INITIAL OR worker_id IS INITIAL.
      result-error_code = 'INPUT_INVALID'.
      RETURN.
    ENDIF.
    IF NOT line_exists( work_centers[ table_line = work_center ] ).
      result-error_code = 'NO_WORK_CENTER_SCOPE'.
      RETURN.
    ENDIF.

    result-machine_id = active_machine( work_center = work_center
                                        position_id = position_id ).
    IF result-machine_id IS INITIAL.
      result-error_code = 'POSITION_NOT_ACTIVE'.
      RETURN.
    ENDIF.
    IF is_worker_of_work_center( worker_id = worker_id
                                 work_center = work_center ) = abap_false.
      result-error_code = 'WORKER_NOT_IN_WORK_CENTER'.
      RETURN.
    ENDIF.

    "Điều chuyển sẽ đóng ghế hiện tại của công nhân; nếu ghế đó thuộc Work
    "Center ngoài phạm vi quyền thì không được đụng tới.
    SELECT FROM ztb_pp_pos_asgn
      FIELDS work_center, position_id
      WHERE worker_id = @worker_id
        AND status = 'A'
      INTO TABLE @DATA(current_seats).
    LOOP AT current_seats ASSIGNING FIELD-SYMBOL(<current>).
      IF <current>-work_center = work_center AND <current>-position_id = position_id.
        "Đã ngồi đúng vị trí: không cần thay đổi.
        result-is_valid = abap_true.
        RETURN.
      ENDIF.
      IF NOT line_exists( work_centers[ table_line = <current>-work_center ] ).
        result-error_code = 'NO_WORK_CENTER_SCOPE'.
        RETURN.
      ENDIF.
    ENDLOOP.

    result-error_code = save_assignment( work_center = work_center
                                         position_id = position_id
                                         worker_id = worker_id
                                         status = 'A' ).
    result-is_valid = xsdbool( result-error_code IS INITIAL ).
  ENDMETHOD.

  METHOD release.
    result = VALUE #( work_center = work_center position_id = position_id ).
    authorize( EXPORTING access_token = access_token device_id = device_id
               IMPORTING work_centers = DATA(work_centers)
                         error_code = result-error_code ).
    IF result-error_code IS NOT INITIAL.
      RETURN.
    ENDIF.
    IF work_center IS INITIAL OR position_id IS INITIAL.
      result-error_code = 'INPUT_INVALID'.
      RETURN.
    ENDIF.
    IF NOT line_exists( work_centers[ table_line = work_center ] ).
      result-error_code = 'NO_WORK_CENTER_SCOPE'.
      RETURN.
    ENDIF.

    SELECT FROM ztb_pp_pos_asgn
      FIELDS worker_id
      WHERE work_center = @work_center
        AND position_id = @position_id
        AND status = 'A'
      INTO TABLE @DATA(occupants)
      UP TO 1 ROWS.
    IF occupants IS INITIAL.
      result-error_code = 'SEAT_EMPTY'.
      RETURN.
    ENDIF.
    result-worker_id = occupants[ 1 ]-worker_id.
    result-machine_id = active_machine( work_center = work_center
                                        position_id = position_id ).

    result-error_code = save_assignment( work_center = work_center
                                         position_id = position_id
                                         worker_id = result-worker_id
                                         status = 'I' ).
    result-is_valid = xsdbool( result-error_code IS INITIAL ).
  ENDMETHOD.

  METHOD save_assignment.
    "Key đã tồn tại (từng ngồi vị trí này) thì kích hoạt/khóa lại dòng cũ, chưa
    "có thì tạo mới. Determination của ZR_PP_PosAssign lo phần chuyển các phân
    "công bị thay thế sang I trong cùng LUW.
    SELECT FROM ztb_pp_pos_asgn
      FIELDS worker_id
      WHERE work_center = @work_center
        AND position_id = @position_id
        AND worker_id = @worker_id
      INTO TABLE @DATA(existing)
      UP TO 1 ROWS.

    IF existing IS INITIAL.
      MODIFY ENTITIES OF zr_pp_posassign
        ENTITY Assignment
          CREATE FIELDS ( WorkCenter PositionID WorkerID Status )
          WITH VALUE #( ( %cid = 'POSASSIGN'
                          %is_draft = if_abap_behv=>mk-off
                          WorkCenter = work_center
                          PositionID = position_id
                          WorkerID = worker_id
                          Status = status ) )
        FAILED DATA(create_failed).
      IF create_failed IS NOT INITIAL.
        result = 'POSITION_SAVE_FAILED'.
      ENDIF.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_pp_posassign
      ENTITY Assignment
        UPDATE FIELDS ( Status )
        WITH VALUE #( ( %is_draft = if_abap_behv=>mk-off
                        WorkCenter = work_center
                        PositionID = position_id
                        WorkerID = worker_id
                        Status = status ) )
      FAILED DATA(update_failed).
    IF update_failed IS NOT INITIAL.
      "Thường do dòng đang được mở bản nháp trên Fiori.
      result = 'POSITION_LOCKED'.
    ENDIF.
  ENDMETHOD.

  METHOD active_machine.
    SELECT FROM ztb_pp_position
      FIELDS machine_id
      WHERE work_center = @work_center
        AND position_id = @position_id
        AND status = 'A'
      INTO TABLE @DATA(machines)
      UP TO 1 ROWS.
    IF machines IS NOT INITIAL.
      result = machines[ 1 ]-machine_id.
    ENDIF.
  ENDMETHOD.

  METHOD is_worker_of_work_center.
    DATA(today) = cl_abap_context_info=>get_system_date( ).
    SELECT FROM zi_pp_workerref
      FIELDS workerid
      WHERE workerid = @worker_id
        AND workcenter = @work_center
        AND validfrom <= @today
        AND validto >= @today
      INTO TABLE @DATA(matches)
      UP TO 1 ROWS.
    result = xsdbool( matches IS NOT INITIAL ).
  ENDMETHOD.

  METHOD fill_worker_names.
    DATA wanted TYPE RANGE OF zi_pp_workerref-workerid.
    wanted = VALUE #( FOR seat IN seats WHERE ( worker_id IS NOT INITIAL )
                      ( sign = 'I' option = 'EQ' low = seat-worker_id ) ).
    IF wanted IS INITIAL.
      RETURN.
    ENDIF.
    DATA(today) = cl_abap_context_info=>get_system_date( ).
    SELECT FROM zi_pp_workerref
      FIELDS workerid, workcenter, workername
      WHERE workerid IN @wanted
        AND validfrom <= @today
        AND validto >= @today
      INTO TABLE @DATA(names).
    LOOP AT seats ASSIGNING FIELD-SYMBOL(<seat>) WHERE worker_id IS NOT INITIAL.
      <seat>-worker_name = VALUE #(
        names[ workerid = <seat>-worker_id workcenter = <seat>-work_center ]-workername
        OPTIONAL ).
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
