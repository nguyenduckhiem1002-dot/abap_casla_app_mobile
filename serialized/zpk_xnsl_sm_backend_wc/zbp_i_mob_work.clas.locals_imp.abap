CLASS lhc_mobilework DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    TYPES reported_response TYPE RESPONSE FOR REPORTED zi_mob_work.
    TYPES failed_response TYPE RESPONSE FOR FAILED zi_mob_work.
    TYPES ty_work_create TYPE TABLE FOR CREATE zi_mob_work.
    METHODS uploadexcel FOR MODIFY
      IMPORTING keys FOR ACTION MobileWork~uploadExcel RESULT result.
    METHODS prepare_upload_row
      IMPORTING row      TYPE zcl_mob_work_parser=>ty_row
      CHANGING  works    TYPE ty_work_create
                failed   TYPE failed_response
                reported TYPE reported_response
      RETURNING VALUE(result) TYPE abap_bool.
    METHODS report_error
      IMPORTING cid TYPE string text TYPE string
      CHANGING failed TYPE failed_response reported TYPE reported_response.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR MobileWork RESULT result.
    METHODS validateWork FOR VALIDATE ON SAVE
      IMPORTING keys FOR MobileWork~validateWork.
    METHODS setWorkDepartment FOR DETERMINE ON MODIFY
      IMPORTING keys FOR MobileWork~setWorkDepartment.
ENDCLASS.

CLASS lhc_mobilework IMPLEMENTATION.
  METHOD get_global_authorizations.
    "Được bảo vệ bằng IAM app/business catalog của service quản trị tập trung.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-uploadExcel = if_abap_behv=>mk-on.
      result-%action-uploadExcel = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.
    "Work ID là hợp đồng phạm vi phân quyền; hãy vô hiệu hóa thay vì hard-delete.
    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = if_abap_behv=>auth-unauthorized.
    ENDIF.
  ENDMETHOD.

  METHOD report_error.
    APPEND VALUE #( %cid = cid ) TO failed-mobilework.
    APPEND VALUE #( %cid = cid
      %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-error text = text ) )
      TO reported-mobilework.
  ENDMETHOD.

  METHOD prepare_upload_row.
    result = abap_false.
    DATA(label) = |Dòng { row-excel_row }: |.
    DATA(work_id) = CONV ztb_mob_work-work_id( row-work_id ).
    DATA(work_center) = CONV zi_mob_workcenter_vh-WorkCenter( row-work_center ).
    SELECT FROM ztb_mob_work FIELDS work_id
      WHERE work_id = @work_id
      INTO TABLE @DATA(existing_works)
      UP TO 1 ROWS.
    IF existing_works IS NOT INITIAL.
      report_error( EXPORTING cid = row-cid text = label && 'Work ID đã tồn tại'
                    CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    SELECT FROM zi_mob_workcenter_vh FIELDS WorkCenter
      WHERE WorkCenter = @work_center
      INTO TABLE @DATA(valid_work_centers)
      UP TO 1 ROWS.
    IF row-is_active = 'A' AND valid_work_centers IS INITIAL.
      report_error( EXPORTING cid = row-cid
                              text = label && 'Trung tâm làm việc không tồn tại trong SAP'
                    CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    "BoPhan do determination setWorkDepartment gán theo Work ID.
    APPEND VALUE #( %cid = row-cid WorkID = work_id WorkName = row-work_name
      Plant = row-plant WorkCenter = work_center Location = row-location
      IsActive = row-is_active ) TO works.
    result = abap_true.
  ENDMETHOD.

  METHOD uploadexcel.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.
    DATA(cid) = CONV string( keys[ 1 ]-%cid ).
    IF lines( keys ) > 1.
      report_error( EXPORTING cid = cid text = 'Mỗi yêu cầu chỉ được tải một file'
                    CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    IF keys[ 1 ]-%param-fileContent IS INITIAL.
      report_error( EXPORTING cid = cid text = 'Nội dung file Excel là bắt buộc'
                    CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    zcl_mob_work_parser=>parse( EXPORTING content = keys[ 1 ]-%param-fileContent
                                IMPORTING rows = DATA(rows) error = DATA(parse_error) ).
    IF parse_error IS NOT INITIAL.
      report_error( EXPORTING cid = cid text = parse_error
                    CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.

    "Kiểm tra toàn bộ dòng trước khi ghi để báo hết lỗi một lần; có lỗi thì không tạo gì.
    DATA works TYPE ty_work_create.
    DATA(all_valid) = abap_true.
    LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).
      IF prepare_upload_row( EXPORTING row = <row>
           CHANGING works = works failed = failed reported = reported ) = abap_false.
        all_valid = abap_false.
      ENDIF.
    ENDLOOP.
    IF all_valid = abap_false.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zi_mob_work IN LOCAL MODE
      ENTITY MobileWork CREATE FIELDS
        ( WorkID WorkName Plant WorkCenter Location IsActive )
      WITH works
      FAILED DATA(failed_create) REPORTED DATA(reported_create).
    IF failed_create IS NOT INITIAL.
      failed = CORRESPONDING #( failed_create ).
      reported = CORRESPONDING #( reported_create ).
      RETURN.
    ENDIF.
    result = VALUE #( ( %cid = cid %param-CreatedCount = lines( works ) ) ).
  ENDMETHOD.

  METHOD validateWork.
    READ ENTITIES OF zi_mob_work IN LOCAL MODE
      ENTITY MobileWork
      FIELDS ( WorkID WorkName WorkCenter IsActive )
      WITH CORRESPONDING #( keys )
      RESULT DATA(works).

    DATA work_center_ids TYPE RANGE OF zi_mob_workcenter_vh-WorkCenter.
    LOOP AT works ASSIGNING FIELD-SYMBOL(<work_key>).
      IF <work_key>-WorkCenter IS NOT INITIAL
         AND NOT line_exists( work_center_ids[ low = <work_key>-WorkCenter ] ).
        INSERT VALUE #( sign = 'I' option = 'EQ' low = <work_key>-WorkCenter )
          INTO TABLE work_center_ids.
      ENDIF.
    ENDLOOP.

    DATA valid_work_centers TYPE SORTED TABLE OF zi_mob_workcenter_vh-WorkCenter
      WITH UNIQUE KEY table_line.
    IF work_center_ids IS NOT INITIAL.
      SELECT FROM zi_mob_workcenter_vh
        FIELDS DISTINCT WorkCenter
        WHERE WorkCenter IN @work_center_ids
        INTO TABLE @valid_work_centers.
    ENDIF.

    LOOP AT works ASSIGNING FIELD-SYMBOL(<work>).
      IF <work>-WorkID IS INITIAL
         OR <work>-WorkName IS INITIAL
         OR <work>-WorkCenter IS INITIAL
         OR ( <work>-IsActive <> 'A' AND <work>-IsActive <> 'I' ).
        APPEND VALUE #( %tky = <work>-%tky ) TO failed-mobilework.
        APPEND VALUE #(
          %tky = <work>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Work ID, tên, Work Center và trạng thái A/I là bắt buộc' ) )
          TO reported-mobilework.
      ELSEIF <work>-IsActive = 'A'
         AND NOT line_exists( valid_work_centers[ table_line = <work>-WorkCenter ] ).
        APPEND VALUE #( %tky = <work>-%tky ) TO failed-mobilework.
        APPEND VALUE #(
          %tky = <work>-%tky
          %element-WorkCenter = if_abap_behv=>mk-on
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Trung tâm làm việc không tồn tại trong SAP' ) )
          TO reported-mobilework.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD setWorkDepartment.

    READ ENTITIES OF zi_mob_work IN LOCAL MODE
      ENTITY MobileWork
      FIELDS ( WorkID )
      WITH CORRESPONDING #( keys )
      RESULT DATA(works).

    MODIFY ENTITIES OF zi_mob_work IN LOCAL MODE
     ENTITY MobileWork
     UPDATE FIELDS ( BoPhan )
     WITH VALUE #( FOR work IN works
       ( %tky = work-%tky
         BoPhan = work-WorkID
         %control-BoPhan = if_abap_behv=>mk-on ) )
     FAILED DATA(set_failed)
     REPORTED DATA(set_reported).

  ENDMETHOD.

ENDCLASS.

