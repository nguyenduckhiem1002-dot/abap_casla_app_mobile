CLASS zcl_mob_work_parser DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES BEGIN OF ty_row.
    TYPES cid TYPE string.
    TYPES excel_row TYPE i.
    TYPES work_id TYPE string.
    TYPES work_name TYPE string.
    TYPES plant TYPE string.
    TYPES work_center TYPE string.
    TYPES location TYPE string.
    TYPES is_active TYPE string.
    TYPES END OF ty_row.
    TYPES tt_row TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.
    CLASS-METHODS parse
      IMPORTING content TYPE xstring
      EXPORTING rows    TYPE tt_row
                error   TYPE string.
  PRIVATE SECTION.
    CONSTANTS c_header_rows TYPE i VALUE 1.
    CONSTANTS c_max_rows TYPE i VALUE 500.
    TYPES BEGIN OF ty_input.
    TYPES work_id TYPE string.
    TYPES work_name TYPE string.
    TYPES work_center TYPE string.
    TYPES location TYPE string.
    TYPES is_active TYPE string.
    TYPES END OF ty_input.
    TYPES tt_input TYPE STANDARD TABLE OF ty_input WITH EMPTY KEY.
    CLASS-METHODS validate_row
      IMPORTING row          TYPE ty_row
      RETURNING VALUE(error) TYPE string.
ENDCLASS.



CLASS ZCL_MOB_WORK_PARSER IMPLEMENTATION.


  METHOD parse.
    DATA inputs TYPE tt_input.
    DATA work_ids TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    CLEAR: rows, error.
    TRY.
        DATA(xlsx) = xco_cp_xlsx=>document->for_file_content( iv_file_content = content )->read_access( ).
        DATA(sheet) = xlsx->get_workbook( )->worksheet->at_position( 1 ).
        DATA(pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).
        DATA(execute) = sheet->select( pattern )->row_stream( )->operation->write_to( REF #( inputs ) ).
        execute->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
          )->if_xco_xlsx_ra_operation~execute( ).
      CATCH cx_root INTO DATA(read_error).
        error = |Không đọc được file Excel: { read_error->get_text( ) }|.
        RETURN.
    ENDTRY.
    DELETE inputs FROM 1 TO c_header_rows.
    LOOP AT inputs INTO DATA(input).
      DATA(excel_row) = sy-tabix + c_header_rows.
      DATA(row) = VALUE ty_row( cid = |ROW_{ excel_row }| excel_row = excel_row
        work_id = condense( input-work_id ) work_name = condense( input-work_name )
        work_center = to_upper( condense( input-work_center ) )
        location = condense( input-location )
        is_active = COND #( WHEN input-is_active IS INITIAL THEN 'A'
                            ELSE to_upper( condense( input-is_active ) ) ) ).
      IF row-work_id IS INITIAL AND row-work_name IS INITIAL AND row-plant IS INITIAL
         AND row-work_center IS INITIAL AND row-location IS INITIAL.
        CONTINUE.
      ENDIF.
      error = validate_row( row ).
      IF error IS INITIAL.
        INSERT to_upper( row-work_id ) INTO TABLE work_ids.
        IF sy-subrc <> 0.
          error = |Dòng { excel_row }: Work ID { row-work_id } bị trùng trong file|.
        ENDIF.
      ENDIF.
      IF error IS NOT INITIAL.
        CLEAR rows.
        RETURN.
      ENDIF.
      APPEND row TO rows.
    ENDLOOP.
    IF rows IS INITIAL.
      error = 'File Excel không có dòng dữ liệu nào'.
    ELSEIF lines( rows ) > c_max_rows.
      error = |File Excel vượt quá { c_max_rows } vị trí mỗi lần tải|.
      CLEAR rows.
    ENDIF.
  ENDMETHOD.


  METHOD validate_row.
    IF row-work_id IS INITIAL OR row-work_name IS INITIAL OR row-work_center IS INITIAL.
      error = |Dòng { row-excel_row }: Work ID, tên và Work Center là bắt buộc|.
    ELSEIF strlen( row-work_id ) > 30 OR strlen( row-work_name ) > 100
        OR strlen( row-plant ) > 4 OR strlen( row-work_center ) > 8
        OR strlen( row-location ) > 100.
      error = |Dòng { row-excel_row }: Dữ liệu vượt độ dài cho phép|.
    ELSEIF row-is_active <> 'A' AND row-is_active <> 'I'.
      error = |Dòng { row-excel_row }: Trạng thái chỉ được là A hoặc I|.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
