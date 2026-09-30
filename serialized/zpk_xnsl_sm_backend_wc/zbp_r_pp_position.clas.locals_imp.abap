"Giá trị sự kiện ghi trên vị trí và lý do kết thúc ghi vào lịch sử người ngồi.
INTERFACE lif_pos_event.
  CONSTANTS:
    transfer_in  TYPE ztb_pp_position-last_event_type VALUE 'TRANSFER_IN',
    transfer_out TYPE ztb_pp_position-last_event_type VALUE 'TRANSFER_OUT',
    release      TYPE ztb_pp_position-last_event_type VALUE 'RELEASE'.
  CONSTANTS:
    "Người đang ngồi bị người khác điều chuyển vào thay chỗ.
    reason_bumped      TYPE ztb_pp_pos_asgn-end_reason VALUE 'BUMPED',
    "Chính công nhân được điều chuyển sang vị trí khác.
    reason_transferred TYPE ztb_pp_pos_asgn-end_reason VALUE 'TRANSFERRED',
    "Công nhân rời vị trí mà không được xếp chỗ mới.
    reason_released    TYPE ztb_pp_pos_asgn-end_reason VALUE 'RELEASED'.
  CONSTANTS:
    status_active   TYPE ztb_pp_position-status VALUE 'A',
    status_inactive TYPE ztb_pp_position-status VALUE 'I'.
ENDINTERFACE.

CLASS lhc_position DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    TYPES position_row TYPE STRUCTURE FOR READ RESULT zr_pp_position\\Position.
    TYPES position_rows TYPE TABLE FOR READ RESULT zr_pp_position\\Position.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Position RESULT result.
    METHODS validatePosition FOR VALIDATE ON SAVE
      IMPORTING keys FOR Position~validatePosition.
    METHODS transferWorker FOR MODIFY
      IMPORTING keys FOR ACTION Position~transferWorker RESULT result.
    METHODS releasePosition FOR MODIFY
      IMPORTING keys FOR ACTION Position~releasePosition RESULT result.

    "Dùng chung cho action Fiori và (giai đoạn 2) facade mobile, để hai kênh
    "không thể áp hai bộ quy tắc điều chuyển khác nhau.
    METHODS perform_transfer
      IMPORTING work_center      TYPE ztb_pp_position-work_center
                position_id      TYPE ztb_pp_position-position_id
                worker_id        TYPE ztb_pp_position-current_worker_id
                reason_text      TYPE ztb_pp_position-last_reason_text
                actor_user_uuid  TYPE sysuuid_x16
                source_channel   TYPE ztb_pp_position-last_source_channel
      RETURNING VALUE(error_text) TYPE string.
    METHODS perform_release
      IMPORTING work_center      TYPE ztb_pp_position-work_center
                position_id      TYPE ztb_pp_position-position_id
                reason_text      TYPE ztb_pp_position-last_reason_text
                actor_user_uuid  TYPE sysuuid_x16
                source_channel   TYPE ztb_pp_position-last_source_channel
      RETURNING VALUE(error_text) TYPE string.
    METHODS read_active_position
      IMPORTING work_center   TYPE ztb_pp_position-work_center
                position_id   TYPE ztb_pp_position-position_id
      RETURNING VALUE(result) TYPE position_rows.
    "Các vị trí mà công nhân đang ngồi, trừ vị trí được chỉ định. Tìm ứng viên
    "trên DB rồi đọc lại qua EML để thấy thay đổi chưa save trong cùng LUW.
    METHODS read_seats_of_worker
      IMPORTING worker_id          TYPE ztb_pp_position-current_worker_id
                except_work_center TYPE ztb_pp_position-work_center
                except_position_id TYPE ztb_pp_position-position_id
      RETURNING VALUE(result)      TYPE position_rows.
    METHODS is_worker_of_work_center
      IMPORTING worker_id     TYPE ztb_pp_position-current_worker_id
                work_center   TYPE ztb_pp_position-work_center
      RETURNING VALUE(result) TYPE abap_bool.
    METHODS check_position
      IMPORTING position      TYPE position_row
      RETURNING VALUE(result) TYPE string.
ENDCLASS.

CLASS lhc_position IMPLEMENTATION.
  METHOD get_global_authorizations.
    "Fiori quản trị có toàn quyền; cổng vào là IAM app của service admin.
    "Quyền theo work center chỉ áp cho kênh mobile (giai đoạn 2).
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-transferWorker = if_abap_behv=>mk-on.
      result-%action-transferWorker = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-releasePosition = if_abap_behv=>mk-on.
      result-%action-releasePosition = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD validatePosition.
    READ ENTITIES OF zr_pp_position IN LOCAL MODE
      ENTITY Position
        FIELDS ( WorkCenter PositionID MachineID Status CurrentWorkerID )
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
    IF position-WorkCenter IS INITIAL OR position-PositionID IS INITIAL.
      result = 'Work center và vị trí là bắt buộc'.
      RETURN.
    ENDIF.
    IF position-Status <> lif_pos_event=>status_active
       AND position-Status <> lif_pos_event=>status_inactive.
      result = 'Trạng thái chỉ nhận A (đang dùng) hoặc I (ngừng dùng)'.
      RETURN.
    ENDIF.
    IF position-Status = lif_pos_event=>status_inactive
       AND position-CurrentWorkerID IS NOT INITIAL.
      result = 'Vị trí đang có công nhân ngồi; hãy cho rời vị trí trước khi ngừng sử dụng'.
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

    IF position-MachineID IS NOT INITIAL
       AND position-Status = lif_pos_event=>status_active.
      SELECT FROM ztb_pp_position
        FIELDS work_center, position_id
        WHERE machine_id = @position-MachineID
          AND status = @lif_pos_event=>status_active
          AND NOT ( work_center = @position-WorkCenter
                    AND position_id = @position-PositionID )
        INTO TABLE @DATA(machine_owners)
        UP TO 1 ROWS.
      IF machine_owners IS NOT INITIAL.
        result = |Mã máy { position-MachineID } đang gắn với vị trí | &&
                 |{ machine_owners[ 1 ]-work_center }/{ machine_owners[ 1 ]-position_id }|.
        RETURN.
      ENDIF.
    ENDIF.

    IF position-CurrentWorkerID IS NOT INITIAL
       AND read_seats_of_worker(
             worker_id = position-CurrentWorkerID
             except_work_center = position-WorkCenter
             except_position_id = position-PositionID ) IS NOT INITIAL.
      result = |Công nhân { position-CurrentWorkerID } đang được xếp ở một vị trí khác|.
    ENDIF.
  ENDMETHOD.

  METHOD transferWorker.
    DATA error_text TYPE string.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      IF <key>-%is_draft = if_abap_behv=>mk-on.
        error_text = 'Hãy lưu hoặc hủy bản nháp của vị trí trước khi điều chuyển'.
      ELSE.
        error_text = perform_transfer(
          work_center = <key>-WorkCenter
          position_id = <key>-PositionID
          worker_id = <key>-%param-WorkerID
          reason_text = <key>-%param-ReasonText
          actor_user_uuid = VALUE #( )
          source_channel = CONV #( zcl_pp_txn_type=>source_fiori ) ).
      ENDIF.
      IF error_text IS NOT INITIAL.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-position.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = error_text ) ) TO reported-position.
      ENDIF.
    ENDLOOP.

    READ ENTITIES OF zr_pp_position IN LOCAL MODE
      ENTITY Position ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(positions).
    result = VALUE #( FOR position IN positions
      ( %tky = position-%tky %param = position ) ).
  ENDMETHOD.

  METHOD releasePosition.
    DATA error_text TYPE string.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      IF <key>-%is_draft = if_abap_behv=>mk-on.
        error_text = 'Hãy lưu hoặc hủy bản nháp của vị trí trước khi cho rời vị trí'.
      ELSE.
        error_text = perform_release(
          work_center = <key>-WorkCenter
          position_id = <key>-PositionID
          reason_text = <key>-%param-ReasonText
          actor_user_uuid = VALUE #( )
          source_channel = CONV #( zcl_pp_txn_type=>source_fiori ) ).
      ENDIF.
      IF error_text IS NOT INITIAL.
        APPEND VALUE #( %tky = <key>-%tky ) TO failed-position.
        APPEND VALUE #(
          %tky = <key>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = error_text ) ) TO reported-position.
      ENDIF.
    ENDLOOP.

    READ ENTITIES OF zr_pp_position IN LOCAL MODE
      ENTITY Position ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(positions).
    result = VALUE #( FOR position IN positions
      ( %tky = position-%tky %param = position ) ).
  ENDMETHOD.

  METHOD perform_transfer.
    IF worker_id IS INITIAL.
      error_text = 'Chưa chọn công nhân'.
      RETURN.
    ENDIF.
    DATA(targets) = read_active_position( work_center = work_center
                                          position_id = position_id ).
    IF targets IS INITIAL.
      error_text = 'Vị trí không tồn tại'.
      RETURN.
    ENDIF.
    DATA(target) = targets[ 1 ].
    IF target-Status <> lif_pos_event=>status_active.
      error_text = 'Vị trí đang ngừng sử dụng'.
      RETURN.
    ENDIF.
    IF target-CurrentWorkerID = worker_id.
      error_text = 'Công nhân đã ngồi ở vị trí này'.
      RETURN.
    ENDIF.
    IF is_worker_of_work_center( worker_id = worker_id
                                 work_center = work_center ) = abap_false.
      error_text = |Công nhân { worker_id } không thuộc work center { work_center }|.
      RETURN.
    ENDIF.

    DATA(old_seats) = read_seats_of_worker( worker_id = worker_id
                                            except_work_center = work_center
                                            except_position_id = position_id ).
    TRY.
        DATA(event_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(assign_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        error_text = 'Không tạo được mã sự kiện điều chuyển, hãy thử lại'.
        RETURN.
    ENDTRY.
    DATA(now) = utclong_current( ).

    "Vị trí đích: công nhân mới vào, người đang ngồi (nếu có) bị thay chỗ.
    "LastMoverPrevAssign giữ lượt ngồi cũ của công nhân để lịch sử nối thành
    "một chuỗi liền.
    DATA updates TYPE TABLE FOR UPDATE zr_pp_position\\Position.
    updates = VALUE #( (
      %is_draft = if_abap_behv=>mk-off
      WorkCenter = work_center
      PositionID = position_id
      CurrentWorkerID = worker_id
      CurrentAssignUUID = assign_uuid
      OccupiedSince = now
      LastEventUUID = event_uuid
      LastEventType = lif_pos_event=>transfer_in
      LastEventAt = now
      LastPrevWorkerID = target-CurrentWorkerID
      LastPrevAssignUUID = target-CurrentAssignUUID
      LastMoverPrevAssign = VALUE #( old_seats[ 1 ]-CurrentAssignUUID OPTIONAL )
      LastReasonText = reason_text
      LastActorUserUUID = actor_user_uuid
      LastSourceChannel = source_channel ) ).

    "Ghế cũ của công nhân được giải phóng trong cùng LUW; update này cũng
    "khóa ghế cũ nên hai thao tác đồng thời không thể xếp một người vào hai chỗ.
    LOOP AT old_seats ASSIGNING FIELD-SYMBOL(<old_seat>).
      APPEND VALUE #(
        %is_draft = if_abap_behv=>mk-off
        WorkCenter = <old_seat>-WorkCenter
        PositionID = <old_seat>-PositionID
        LastEventUUID = event_uuid
        LastEventType = lif_pos_event=>transfer_out
        LastEventAt = now
        LastPrevWorkerID = worker_id
        LastPrevAssignUUID = <old_seat>-CurrentAssignUUID
        LastReasonText = reason_text
        LastActorUserUUID = actor_user_uuid
        LastSourceChannel = source_channel ) TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zr_pp_position IN LOCAL MODE
      ENTITY Position
        UPDATE FIELDS ( CurrentWorkerID CurrentAssignUUID OccupiedSince
                        LastEventUUID LastEventType LastEventAt
                        LastPrevWorkerID LastPrevAssignUUID LastMoverPrevAssign
                        LastReasonText LastActorUserUUID LastSourceChannel )
        WITH updates
      FAILED DATA(update_failed).
    IF update_failed IS NOT INITIAL.
      error_text = 'Vị trí đang được người khác thao tác hoặc chỉnh sửa, hãy thử lại'.
    ENDIF.
  ENDMETHOD.

  METHOD perform_release.
    DATA(targets) = read_active_position( work_center = work_center
                                          position_id = position_id ).
    IF targets IS INITIAL.
      error_text = 'Vị trí không tồn tại'.
      RETURN.
    ENDIF.
    DATA(target) = targets[ 1 ].
    IF target-CurrentWorkerID IS INITIAL.
      error_text = 'Vị trí đang trống'.
      RETURN.
    ENDIF.
    TRY.
        DATA(event_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        error_text = 'Không tạo được mã sự kiện, hãy thử lại'.
        RETURN.
    ENDTRY.
    DATA(now) = utclong_current( ).

    MODIFY ENTITIES OF zr_pp_position IN LOCAL MODE
      ENTITY Position
        UPDATE FIELDS ( CurrentWorkerID CurrentAssignUUID OccupiedSince
                        LastEventUUID LastEventType LastEventAt
                        LastPrevWorkerID LastPrevAssignUUID LastMoverPrevAssign
                        LastReasonText LastActorUserUUID LastSourceChannel )
        WITH VALUE #( (
          %is_draft = if_abap_behv=>mk-off
          WorkCenter = work_center
          PositionID = position_id
          LastEventUUID = event_uuid
          LastEventType = lif_pos_event=>release
          LastEventAt = now
          LastPrevWorkerID = target-CurrentWorkerID
          LastPrevAssignUUID = target-CurrentAssignUUID
          LastReasonText = reason_text
          LastActorUserUUID = actor_user_uuid
          LastSourceChannel = source_channel ) )
      FAILED DATA(update_failed).
    IF update_failed IS NOT INITIAL.
      error_text = 'Vị trí đang được người khác thao tác hoặc chỉnh sửa, hãy thử lại'.
    ENDIF.
  ENDMETHOD.

  METHOD read_active_position.
    READ ENTITIES OF zr_pp_position IN LOCAL MODE
      ENTITY Position
        FIELDS ( Status CurrentWorkerID CurrentAssignUUID )
        WITH VALUE #( ( %is_draft = if_abap_behv=>mk-off
                        WorkCenter = work_center
                        PositionID = position_id ) )
      RESULT result.
  ENDMETHOD.

  METHOD read_seats_of_worker.
    SELECT FROM ztb_pp_position
      FIELDS work_center, position_id
      WHERE current_worker_id = @worker_id
        AND NOT ( work_center = @except_work_center
                  AND position_id = @except_position_id )
      INTO TABLE @DATA(candidates).
    IF candidates IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zr_pp_position IN LOCAL MODE
      ENTITY Position
        FIELDS ( CurrentWorkerID CurrentAssignUUID )
        WITH VALUE #( FOR candidate IN candidates
          ( %is_draft = if_abap_behv=>mk-off
            WorkCenter = candidate-work_center
            PositionID = candidate-position_id ) )
      RESULT DATA(seats).
    result = VALUE #( FOR seat IN seats WHERE ( CurrentWorkerID = worker_id )
                      ( seat ) ).
  ENDMETHOD.

  METHOD is_worker_of_work_center.
    "Master nhân công chỉ dùng để kiểm tra công nhân thuộc work center của vị
    "trí tại ngày hiện tại; chuyển khác work center phải đổi master trước.
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
ENDCLASS.

CLASS lsc_zr_pp_position DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
ENDCLASS.

CLASS lsc_zr_pp_position IMPLEMENTATION.
  METHOD save_modified.
    "Chỉ xử lý sự kiện phát sinh trong LUW này: action luôn ghi toàn bộ trường
    "Last* cùng lúc, nên cờ control của LastEventUUID đánh dấu một sự kiện mới.
    "Draft activation có thể gửi lại giá trị cũ; hai lệnh ghi bên dưới đều
    "idempotent (chỉ đóng dòng còn mở, chỉ insert khi chưa có) nên không sinh
    "lịch sử trùng.
    DATA stamp TYPE timestampl.
    DATA closing TYPE ztb_pp_pos_asgn.
    GET TIME STAMP FIELD stamp.
    DATA(user) = cl_abap_context_info=>get_user_technical_name( ).

    LOOP AT update-position ASSIGNING FIELD-SYMBOL(<event>).
      IF <event>-%control-LastEventUUID <> if_abap_behv=>mk-on
         OR <event>-LastEventUUID IS INITIAL.
        CONTINUE.
      ENDIF.

      IF <event>-LastPrevAssignUUID IS NOT INITIAL.
        closing = VALUE #(
          end_reason = COND #(
            WHEN <event>-LastEventType = lif_pos_event=>transfer_in
              THEN lif_pos_event=>reason_bumped
            WHEN <event>-LastEventType = lif_pos_event=>transfer_out
              THEN lif_pos_event=>reason_transferred
            ELSE lif_pos_event=>reason_released ) ).
        UPDATE ztb_pp_pos_asgn
          SET status = @lif_pos_event=>status_inactive,
              valid_to_at = @<event>-LastEventAt,
              end_event_uuid = @<event>-LastEventUUID,
              end_reason = @closing-end_reason,
              end_reason_text = @<event>-LastReasonText,
              end_actor_user_uuid = @<event>-LastActorUserUUID,
              end_source_channel = @<event>-LastSourceChannel
          WHERE assign_uuid = @<event>-LastPrevAssignUUID
            AND status = @lif_pos_event=>status_active.
      ENDIF.

      IF <event>-LastEventType <> lif_pos_event=>transfer_in
         OR <event>-CurrentAssignUUID IS INITIAL.
        CONTINUE.
      ENDIF.
      "INTO TABLE ghi đè kết quả mỗi vòng lặp, nên không còn giá trị cũ sót lại.
      SELECT FROM ztb_pp_pos_asgn
        FIELDS assign_uuid
        WHERE assign_uuid = @<event>-CurrentAssignUUID
        INTO TABLE @DATA(written)
        UP TO 1 ROWS.
      IF written IS NOT INITIAL.
        CONTINUE.
      ENDIF.
      INSERT ztb_pp_pos_asgn FROM @( VALUE ztb_pp_pos_asgn(
        assign_uuid = <event>-CurrentAssignUUID
        work_center = <event>-WorkCenter
        position_id = <event>-PositionID
        worker_id = <event>-CurrentWorkerID
        status = lif_pos_event=>status_active
        valid_from_at = <event>-LastEventAt
        previous_assign_uuid = <event>-LastMoverPrevAssign
        start_event_uuid = <event>-LastEventUUID
        reason_text = <event>-LastReasonText
        actor_user_uuid = <event>-LastActorUserUUID
        source_channel = <event>-LastSourceChannel
        created_by = user
        created_at = stamp ) ).
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
