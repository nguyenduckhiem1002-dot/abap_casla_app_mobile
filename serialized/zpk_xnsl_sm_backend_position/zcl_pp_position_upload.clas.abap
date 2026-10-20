CLASS zcl_pp_position_upload DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS upload
      IMPORTING content          TYPE xstring
      EXPORTING errors           TYPE string_table
                position_count   TYPE i
                assignment_count TYPE i.

    CLASS-METHODS is_pending_position
      IMPORTING work_center   TYPE ztb_pp_position-work_center
                position_id   TYPE ztb_pp_position-position_id
      RETURNING VALUE(result) TYPE abap_bool.

  PRIVATE SECTION.
    CONSTANTS c_header_rows TYPE i VALUE 1.
    CONSTANTS c_max_rows TYPE i VALUE 300.
    CONSTANTS c_max_errors TYPE i VALUE 20.
    TYPES BEGIN OF ty_input.
    TYPES work_center TYPE string.
    TYPES position_id TYPE string.
    TYPES machine_id TYPE string.
    TYPES worker_id TYPE string.
    TYPES status TYPE string.
    TYPES END OF ty_input.
    TYPES tt_input TYPE STANDARD TABLE OF ty_input WITH EMPTY KEY.
    TYPES BEGIN OF ty_row.
    TYPES cid TYPE string.
    TYPES excel_row TYPE i.
    TYPES work_center TYPE string.
    TYPES position_id TYPE string.
    TYPES machine_id TYPE string.
    TYPES worker_id TYPE string.
    TYPES status TYPE string.
    TYPES END OF ty_row.
    TYPES tt_row TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.
    TYPES tt_keys TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    TYPES ty_position_create TYPE TABLE FOR CREATE zr_pp_position\\Position.
    TYPES ty_position_update TYPE TABLE FOR UPDATE zr_pp_position\\Position.
    TYPES ty_assign_create TYPE TABLE FOR CREATE zr_pp_posassign\\Assignment.
    TYPES ty_assign_update TYPE TABLE FOR UPDATE zr_pp_posassign\\Assignment.

    CLASS-DATA pending_positions TYPE tt_keys.

    CLASS-METHODS parse
      IMPORTING content TYPE xstring
      EXPORTING rows    TYPE tt_row
                errors  TYPE string_table.
    CLASS-METHODS add_error
      IMPORTING text   TYPE string
      CHANGING  errors TYPE string_table.
    CLASS-METHODS check_format
      IMPORTING row          TYPE ty_row
      RETURNING VALUE(error) TYPE string.
    CLASS-METHODS check_unique
      IMPORTING rows   TYPE tt_row
      CHANGING  errors TYPE string_table.
    CLASS-METHODS register_unique
      IMPORTING excel_row TYPE i
                label     TYPE string
                value     TYPE string
      CHANGING  seen      TYPE tt_keys
                errors    TYPE string_table.
    CLASS-METHODS check_database
      IMPORTING rows   TYPE tt_row
      CHANGING  errors TYPE string_table.
    CLASS-METHODS check_row_database
      IMPORTING row          TYPE ty_row
                released     TYPE tt_keys
      RETURNING VALUE(error) TYPE string.
    CLASS-METHODS write_positions
      IMPORTING rows         TYPE tt_row
      RETURNING VALUE(error) TYPE string.
    CLASS-METHODS write_assignments
      IMPORTING rows         TYPE tt_row
      RETURNING VALUE(error) TYPE string.
ENDCLASS.



CLASS zcl_pp_position_upload IMPLEMENTATION.


    METHOD upload.
    CLEAR: errors, position_count, assignment_count, pending_positions.
    parse( EXPORTING content = content IMPORTING rows = DATA(rows) errors = errors ).
    IF errors IS INITIAL.
      check_unique( EXPORTING rows = rows CHANGING errors = errors ).
    ENDIF.
    IF errors IS INITIAL.
      check_database( EXPORTING rows = rows CHANGING errors = errors ).
    ENDIF.
    IF errors IS NOT INITIAL.
      RETURN.
    ENDIF.

    DATA(write_error) = write_positions( rows ).
    IF write_error IS INITIAL.
      write_error = write_assignments( rows ).
    ENDIF.
    IF write_error IS NOT INITIAL.
      CLEAR pending_positions.
      APPEND write_error TO errors.
      RETURN.
    ENDIF.
    position_count = lines( rows ).
    assignment_count = REDUCE i( INIT count = 0 FOR row IN rows
                                 WHERE ( worker_id IS NOT INITIAL ) NEXT count = count + 1 ).
  ENDMETHOD.

  METHOD is_pending_position.
    result = xsdbool( line_exists( pending_positions[ table_line = |{ work_center }/{ position_id }| ] ) ).
  ENDMETHOD.


  METHOD add_error.
    IF lines( errors ) < c_max_errors.
      APPEND text TO errors.
    ENDIF.
  ENDMETHOD.


  METHOD parse.
    DATA inputs TYPE tt_input.
    CLEAR: rows, errors.
    TRY.
        DATA(xlsx) = xco_cp_xlsx=>document->for_file_content( iv_file_content = content )->read_access( ).
        DATA(sheet) = xlsx->get_workbook( )->worksheet->at_position( 1 ).
        DATA(pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).
        DATA(execute) = sheet->select( pattern )->row_stream( )->operation->write_to( REF #( inputs ) ).
        execute->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
          )->if_xco_xlsx_ra_operation~execute( ).
      CATCH cx_root INTO DATA(read_error).
        APPEND |Không đọc được file Excel: { read_error->get_text( ) }| TO errors.
        RETURN.
    ENDTRY.
    DELETE inputs FROM 1 TO c_header_rows.
    LOOP AT inputs INTO DATA(input).
      DATA(excel_row) = sy-tabix + c_header_rows.
      DATA(row) = VALUE ty_row( cid = |ROW_{ excel_row }| excel_row = excel_row
        work_center = to_upper( condense( input-work_center ) )
        position_id = to_upper( condense( input-position_id ) )
        machine_id = to_upper( condense( input-machine_id ) )
        worker_id = to_upper( condense( input-worker_id ) )
        status = COND #( WHEN input-status IS INITIAL THEN 'A'
                         ELSE to_upper( condense( input-status ) ) ) ).
      IF row-work_center IS INITIAL AND row-position_id IS INITIAL
         AND row-machine_id IS INITIAL AND row-worker_id IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(row_error) = check_format( row ).
      IF row_error IS NOT INITIAL.
        add_error( EXPORTING text = row_error CHANGING errors = errors ).
        CONTINUE.
      ENDIF.
      APPEND row TO rows.
    ENDLOOP.
    IF rows IS INITIAL AND errors IS INITIAL.
      APPEND 'File Excel không có dòng dữ liệu nào' TO errors.
    ELSEIF lines( rows ) > c_max_rows.
      APPEND |File Excel vượt quá { c_max_rows } dòng mỗi lần tải| TO errors.
    ENDIF.
  ENDMETHOD.


  METHOD check_format.
    IF row-work_center IS INITIAL OR row-position_id IS INITIAL OR row-machine_id IS INITIAL.
      error = |Dòng { row-excel_row }: Work Center, vị trí và mã máy là bắt buộc|.
    ELSEIF strlen( row-work_center ) > 8 OR strlen( row-position_id ) > 10
        OR strlen( row-machine_id ) > 10 OR strlen( row-worker_id ) > 8.
      error = |Dòng { row-excel_row }: Dữ liệu vượt độ dài cho phép|.
    ELSEIF row-status <> 'A' AND row-status <> 'I'.
      error = |Dòng { row-excel_row }: Trạng thái chỉ được là A hoặc I|.
    ENDIF.
  ENDMETHOD.


  METHOD register_unique.
    INSERT value INTO TABLE seen.
    IF sy-subrc <> 0.
      add_error( EXPORTING text = |Dòng { excel_row }: { label } { value } bị trùng trong file|
                 CHANGING errors = errors ).
    ENDIF.
  ENDMETHOD.


  METHOD check_unique.
    DATA keys TYPE tt_keys.
    DATA positions TYPE tt_keys.
    DATA machines TYPE tt_keys.
    DATA workers TYPE tt_keys.
    LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).
      register_unique( EXPORTING excel_row = <row>-excel_row label = 'Dòng vị trí/máy'
        value = |{ <row>-work_center }/{ <row>-position_id }/{ <row>-machine_id }|
        CHANGING seen = keys errors = errors ).
      IF <row>-status <> 'A'.
        CONTINUE.
      ENDIF.
      register_unique( EXPORTING excel_row = <row>-excel_row label = 'Vị trí đang dùng'
        value = |{ <row>-work_center }/{ <row>-position_id }|
        CHANGING seen = positions errors = errors ).
      register_unique( EXPORTING excel_row = <row>-excel_row label = 'Máy đang dùng'
        value = <row>-machine_id CHANGING seen = machines errors = errors ).
      IF <row>-worker_id IS NOT INITIAL.
        register_unique( EXPORTING excel_row = <row>-excel_row label = 'Công nhân đang ngồi'
          value = <row>-worker_id CHANGING seen = workers errors = errors ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD check_database.
    DATA released TYPE tt_keys.
    LOOP AT rows ASSIGNING FIELD-SYMBOL(<released_row>) WHERE status = 'I'.
      INSERT |{ <released_row>-work_center }/{ <released_row>-position_id }/{ <released_row>-machine_id }|
        INTO TABLE released.
    ENDLOOP.
    LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).
      DATA(row_error) = check_row_database( row = <row> released = released ).
      IF row_error IS NOT INITIAL.
        add_error( EXPORTING text = row_error CHANGING errors = errors ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD check_row_database.
    DATA(label) = |Dòng { row-excel_row }: |.
    DATA(work_center) = CONV ztb_pp_position-work_center( row-work_center ).
    SELECT FROM zi_mob_workcenter_vh
      FIELDS workcenter
      WHERE workcenter = @work_center
      INTO TABLE @DATA(work_centers)
      UP TO 1 ROWS.
    IF work_centers IS INITIAL.
      error = label && |Work Center { row-work_center } không tồn tại|.
      RETURN.
    ENDIF.
    IF row-status <> 'A'.
      RETURN.
    ENDIF.

    DATA(position_id) = CONV ztb_pp_position-position_id( row-position_id ).
    DATA(machine_id) = CONV ztb_pp_position-machine_id( row-machine_id ).
    SELECT FROM ztb_pp_position
      FIELDS work_center, position_id
      WHERE machine_id = @machine_id
        AND status = 'A'
        AND NOT ( work_center = @work_center AND position_id = @position_id )
      INTO TABLE @DATA(elsewhere).
    LOOP AT elsewhere ASSIGNING FIELD-SYMBOL(<other>).
      IF NOT line_exists( released[ table_line =
           |{ <other>-work_center }/{ <other>-position_id }/{ row-machine_id }| ] ).
        error = label && |Máy { row-machine_id } đang dùng ở vị trí | &&
                |{ <other>-work_center }/{ <other>-position_id }; hãy ngừng dùng ở đó trước|.
        RETURN.
      ENDIF.
    ENDLOOP.

    IF row-worker_id IS INITIAL.
      RETURN.
    ENDIF.
    DATA(worker_id) = CONV ztb_pp_pos_asgn-worker_id( row-worker_id ).
    DATA(today) = cl_abap_context_info=>get_system_date( ).
    SELECT FROM zi_pp_workerref
      FIELDS workerid
      WHERE workerid = @worker_id
        AND workcenter = @work_center
        AND validfrom <= @today
        AND validto >= @today
      INTO TABLE @DATA(workers)
      UP TO 1 ROWS.
    IF workers IS INITIAL.
      error = label && |Công nhân { row-worker_id } không thuộc work center { row-work_center }|.
    ENDIF.
  ENDMETHOD.


    METHOD write_positions.
    DATA creates TYPE ty_position_create.
    DATA updates TYPE ty_position_update.
    LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).
      DATA(work_center) = CONV ztb_pp_position-work_center( <row>-work_center ).
      DATA(position_id) = CONV ztb_pp_position-position_id( <row>-position_id ).
      DATA(machine_id) = CONV ztb_pp_position-machine_id( <row>-machine_id ).
      SELECT FROM ztb_pp_position
        FIELDS machine_id
        WHERE work_center = @work_center
          AND position_id = @position_id
          AND machine_id = @machine_id
        INTO TABLE @DATA(existing)
        UP TO 1 ROWS.
      IF existing IS NOT INITIAL.
        APPEND VALUE #( %is_draft = if_abap_behv=>mk-off
          WorkCenter = work_center PositionID = position_id MachineID = machine_id
          PositionName = position_id Status = <row>-status ) TO updates.
      ELSEIF <row>-status = 'A'.
        APPEND VALUE #( %cid = <row>-cid %is_draft = if_abap_behv=>mk-off
          WorkCenter = work_center PositionID = position_id MachineID = machine_id
          PositionName = position_id Status = 'A' ) TO creates.
      ENDIF.
      IF <row>-status = 'A'.
        INSERT |{ <row>-work_center }/{ <row>-position_id }| INTO TABLE pending_positions.
      ENDIF.
    ENDLOOP.
    IF creates IS INITIAL AND updates IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_pp_position
      ENTITY Position
        CREATE FIELDS ( WorkCenter PositionID MachineID PositionName Status )
        WITH creates
      ENTITY Position
        UPDATE FIELDS ( PositionName Status )
        WITH updates
      FAILED DATA(failed).
    IF failed-position IS NOT INITIAL.
      error = |Không ghi được vị trí { failed-position[ 1 ]-WorkCenter }/| &&
              |{ failed-position[ 1 ]-PositionID }/{ failed-position[ 1 ]-MachineID }; | &&
              |có thể đang mở bản nháp trên Fiori|.
    ENDIF.
  ENDMETHOD.


  METHOD write_assignments.
    DATA creates TYPE ty_assign_create.
    DATA updates TYPE ty_assign_update.
    LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>) WHERE worker_id IS NOT INITIAL.
      DATA(work_center) = CONV ztb_pp_pos_asgn-work_center( <row>-work_center ).
      DATA(position_id) = CONV ztb_pp_pos_asgn-position_id( <row>-position_id ).
      DATA(worker_id) = CONV ztb_pp_pos_asgn-worker_id( <row>-worker_id ).
      SELECT FROM ztb_pp_pos_asgn
        FIELDS worker_id
        WHERE work_center = @work_center
          AND position_id = @position_id
          AND worker_id = @worker_id
        INTO TABLE @DATA(existing)
        UP TO 1 ROWS.
      IF existing IS NOT INITIAL.
        APPEND VALUE #( %is_draft = if_abap_behv=>mk-off
          WorkCenter = work_center PositionID = position_id WorkerID = worker_id
          Status = <row>-status ) TO updates.
      ELSEIF <row>-status = 'A'.
        APPEND VALUE #( %cid = <row>-cid %is_draft = if_abap_behv=>mk-off
          WorkCenter = work_center PositionID = position_id WorkerID = worker_id
          Status = 'A' ) TO creates.
      ENDIF.
    ENDLOOP.
    IF creates IS INITIAL AND updates IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_pp_posassign
      ENTITY Assignment
        CREATE FIELDS ( WorkCenter PositionID WorkerID Status )
        WITH creates
      ENTITY Assignment
        UPDATE FIELDS ( Status )
        WITH updates
      FAILED DATA(failed).
    IF failed-assignment IS NOT INITIAL.
      error = |Không ghi được phân công { failed-assignment[ 1 ]-WorkerID } tại | &&
              |{ failed-assignment[ 1 ]-WorkCenter }/{ failed-assignment[ 1 ]-PositionID }; | &&
              |có thể đang mở bản nháp trên Fiori|.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
