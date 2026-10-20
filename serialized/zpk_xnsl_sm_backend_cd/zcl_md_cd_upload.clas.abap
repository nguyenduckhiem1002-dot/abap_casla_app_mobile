CLASS zcl_md_cd_upload DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES BEGIN OF ty_row.
    TYPES cid TYPE string.
    TYPES excel_row TYPE i.
    TYPES ma_congdoan TYPE ztb_md_congdoan-ma_congdoan.
    TYPES ten_congdoan TYPE ztb_md_congdoan-ten_congdoan.
    TYPES bo_phan TYPE ztb_md_congdoan-bo_phan.
    TYPES dongia_xm TYPE ztb_md_congdoan-dongia_xm.
    TYPES dongia_gc TYPE ztb_md_congdoan-dongia_gc.
    TYPES valid_from TYPE d.
    TYPES valid_to TYPE d.
    TYPES END OF ty_row.
    TYPES tt_row TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.
    CLASS-METHODS parse
      IMPORTING content TYPE xstring
      EXPORTING rows    TYPE tt_row
                errors  TYPE string_table.

  PRIVATE SECTION.
    CONSTANTS c_header_rows TYPE i VALUE 1.
    CONSTANTS c_max_rows TYPE i VALUE 500.
    CONSTANTS c_max_errors TYPE i VALUE 20.
    CONSTANTS c_epoch TYPE d VALUE '18991230'.
    TYPES BEGIN OF ty_input.
    TYPES ma_congdoan TYPE string.
    TYPES ten_congdoan TYPE string.
    TYPES bo_phan TYPE string.
    TYPES dongia_xm TYPE string.
    TYPES dongia_gc TYPE string.
    TYPES valid_from TYPE string.
    TYPES valid_to TYPE string.
    TYPES END OF ty_input.
    TYPES tt_input TYPE STANDARD TABLE OF ty_input WITH EMPTY KEY.

    CLASS-METHODS add_error
      IMPORTING text   TYPE string
      CHANGING  errors TYPE string_table.
    CLASS-METHODS read_sheet
      IMPORTING content TYPE xstring
      EXPORTING inputs  TYPE tt_input
                error   TYPE string.
    CLASS-METHODS build_row
      IMPORTING input     TYPE ty_input
                excel_row TYPE i
      EXPORTING row       TYPE ty_row
                error     TYPE string.
    CLASS-METHODS parse_amount
      IMPORTING value  TYPE string
      EXPORTING amount TYPE ztb_md_congdoan-dongia_xm
                ok     TYPE abap_bool.
    CLASS-METHODS parse_date
      IMPORTING value       TYPE string
      RETURNING VALUE(date) TYPE d.
    CLASS-METHODS make_date
      IMPORTING year        TYPE i
                month       TYPE i
                day         TYPE i
      RETURNING VALUE(date) TYPE d.
    CLASS-METHODS check_overlaps
      IMPORTING rows   TYPE tt_row
      CHANGING  errors TYPE string_table.
ENDCLASS.



CLASS ZCL_MD_CD_UPLOAD IMPLEMENTATION.


  METHOD add_error.
    IF lines( errors ) < c_max_errors.
      APPEND text TO errors.
    ENDIF.
  ENDMETHOD.


  METHOD parse.
    CLEAR: rows, errors.
    read_sheet( EXPORTING content = content IMPORTING inputs = DATA(inputs) error = DATA(read_error) ).
    IF read_error IS NOT INITIAL.
      APPEND read_error TO errors.
      RETURN.
    ENDIF.
    DELETE inputs FROM 1 TO c_header_rows.
    LOOP AT inputs INTO DATA(input).
      DATA(excel_row) = sy-tabix + c_header_rows.
      IF input-ma_congdoan IS INITIAL AND input-ten_congdoan IS INITIAL AND input-bo_phan IS INITIAL
         AND input-valid_from IS INITIAL AND input-valid_to IS INITIAL.
        CONTINUE.
      ENDIF.
      build_row( EXPORTING input = input excel_row = excel_row
                 IMPORTING row = DATA(row) error = DATA(row_error) ).
      IF row_error IS NOT INITIAL.
        add_error( EXPORTING text = row_error CHANGING errors = errors ).
        CONTINUE.
      ENDIF.
      APPEND row TO rows.
    ENDLOOP.
    IF errors IS NOT INITIAL.
      CLEAR rows.
      RETURN.
    ENDIF.
    IF rows IS INITIAL.
      APPEND 'File Excel không có dòng dữ liệu nào' TO errors.
    ELSEIF lines( rows ) > c_max_rows.
      APPEND |File Excel vượt quá { c_max_rows } dòng mỗi lần tải| TO errors.
    ELSE.
      check_overlaps( EXPORTING rows = rows CHANGING errors = errors ).
    ENDIF.
    IF errors IS NOT INITIAL.
      CLEAR rows.
    ENDIF.
  ENDMETHOD.


  METHOD read_sheet.
    CLEAR: inputs, error.
    TRY.
        DATA(xlsx) = xco_cp_xlsx=>document->for_file_content( iv_file_content = content )->read_access( ).
        DATA(sheet) = xlsx->get_workbook( )->worksheet->at_position( 1 ).
        DATA(pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).
        DATA(execute) = sheet->select( pattern )->row_stream( )->operation->write_to( REF #( inputs ) ).
        execute->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
          )->if_xco_xlsx_ra_operation~execute( ).
      CATCH cx_root INTO DATA(read_error).
        error = |Không đọc được file Excel: { read_error->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.


  METHOD build_row.
    CLEAR: row, error.
    DATA(label) = |Dòng { excel_row }: |.
    DATA(ma_congdoan) = to_upper( condense( input-ma_congdoan ) ).
    DATA(ten_congdoan) = condense( input-ten_congdoan ).
    DATA(bo_phan) = to_upper( condense( input-bo_phan ) ).
    IF ma_congdoan IS INITIAL OR ten_congdoan IS INITIAL OR bo_phan IS INITIAL.
      error = label && 'Mã công đoạn, tên công đoạn và bộ phận là bắt buộc'.
      RETURN.
    ENDIF.
    IF strlen( ma_congdoan ) > 7 OR strlen( ten_congdoan ) > 100 OR strlen( bo_phan ) > 50.
      error = label && 'Dữ liệu vượt độ dài cho phép'.
      RETURN.
    ENDIF.
    parse_amount( EXPORTING value = input-dongia_xm IMPORTING amount = DATA(dongia_xm) ok = DATA(xm_ok) ).
    parse_amount( EXPORTING value = input-dongia_gc IMPORTING amount = DATA(dongia_gc) ok = DATA(gc_ok) ).
    IF xm_ok = abap_false OR gc_ok = abap_false.
      error = label && 'Đơn giá phải là số không âm'.
      RETURN.
    ENDIF.
    DATA(valid_from) = parse_date( input-valid_from ).
    DATA(valid_to) = parse_date( input-valid_to ).
    IF valid_from IS INITIAL OR valid_to IS INITIAL.
      error = label && 'Hiệu lực từ/đến là bắt buộc và phải là ngày hợp lệ (dd.mm.yyyy)'.
      RETURN.
    ENDIF.
    IF valid_from > valid_to.
      error = label && 'Hiệu lực từ không được sau hiệu lực đến'.
      RETURN.
    ENDIF.
    row = VALUE #( cid = |ROW_{ excel_row }| excel_row = excel_row
      ma_congdoan = ma_congdoan ten_congdoan = ten_congdoan bo_phan = bo_phan
      dongia_xm = dongia_xm dongia_gc = dongia_gc valid_from = valid_from valid_to = valid_to ).
  ENDMETHOD.


  METHOD parse_amount.
    amount = 0.
    ok = abap_false.
    DATA(text) = condense( replace( val = value sub = ',' with = '.' occ = 0 ) ).
    IF text IS INITIAL.
      ok = abap_true.
      RETURN.
    ENDIF.
    IF matches( val = text regex = '\d{1,13}(\.\d+)?' ).
      amount = CONV decfloat34( text ).
      ok = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD make_date.
    DATA(max_day) = COND i(
      WHEN month = 2 AND ( ( year MOD 4 = 0 AND year MOD 100 <> 0 ) OR year MOD 400 = 0 ) THEN 29
      WHEN month = 2 THEN 28
      WHEN month = 4 OR month = 6 OR month = 9 OR month = 11 THEN 30
      ELSE 31 ).
    IF year BETWEEN 1900 AND 9999 AND month BETWEEN 1 AND 12 AND day BETWEEN 1 AND max_day.
      date = |{ year WIDTH = 4 ALIGN = RIGHT PAD = '0' }{ month WIDTH = 2 ALIGN = RIGHT PAD = '0' }| &&
             |{ day WIDTH = 2 ALIGN = RIGHT PAD = '0' }|.
    ENDIF.
  ENDMETHOD.


  METHOD parse_date.
    DATA(text) = condense( value ).
    IF text IS INITIAL.
      RETURN.
    ENDIF.
    "dd.mm.yyyy, dd/mm/yyyy, dd-mm-yyyy
    IF matches( val = text regex = '\d{1,2}[./-]\d{1,2}[./-]\d{4}' ).
      SPLIT text AT '.' INTO TABLE DATA(parts).
      IF lines( parts ) <> 3.
        SPLIT text AT '/' INTO TABLE parts.
      ENDIF.
      IF lines( parts ) <> 3.
        SPLIT text AT '-' INTO TABLE parts.
      ENDIF.
      date = make_date( year = CONV i( parts[ 3 ] ) month = CONV i( parts[ 2 ] ) day = CONV i( parts[ 1 ] ) ).
      RETURN.
    ENDIF.
    "yyyy-mm-dd
    IF matches( val = text regex = '\d{4}-\d{2}-\d{2}' ).
      date = make_date( year = CONV i( text+0(4) ) month = CONV i( text+5(2) ) day = CONV i( text+8(2) ) ).
      RETURN.
    ENDIF.
    "yyyymmdd
    IF matches( val = text regex = '\d{8}' ).
      date = make_date( year = CONV i( text+0(4) ) month = CONV i( text+4(2) ) day = CONV i( text+6(2) ) ).
      RETURN.
    ENDIF.
    "Số serial của Excel (có thể kèm phần thập phân nếu ô là datetime)
    DATA(serial_text) = text.
    IF serial_text CS '.'.
      SPLIT serial_text AT '.' INTO serial_text DATA(fraction).
    ENDIF.
    IF fraction IS INITIAL OR fraction CO '0123456789'.
      IF matches( val = serial_text regex = '\d{5,7}' ).
        DATA(serial) = CONV i( serial_text ).
        IF serial >= 61 AND serial <= 2958465.
          date = c_epoch + serial.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD check_overlaps.
    LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).
      DATA(row_index) = sy-tabix.
      SELECT FROM ztb_md_congdoan
        FIELDS valid_from, valid_to
        WHERE ma_congdoan = @<row>-ma_congdoan
          AND bo_phan = @<row>-bo_phan
          AND valid_from <= @<row>-valid_to
          AND valid_to >= @<row>-valid_from
        INTO TABLE @DATA(existing)
        UP TO 1 ROWS.
      IF existing IS NOT INITIAL.
        DATA(existing_from) = |{ existing[ 1 ]-valid_from DATE = ENVIRONMENT }|.
        add_error( EXPORTING text = |Dòng { <row>-excel_row }: { <row>-ma_congdoan }/{ <row>-bo_phan } | &&
                                    |đã có bản ghi hiệu lực chồng lấn (từ { existing_from })|
                   CHANGING errors = errors ).
        CONTINUE.
      ENDIF.
      LOOP AT rows ASSIGNING FIELD-SYMBOL(<other>) FROM row_index + 1
           WHERE ma_congdoan = <row>-ma_congdoan AND bo_phan = <row>-bo_phan
             AND valid_from <= <row>-valid_to AND valid_to >= <row>-valid_from.
        add_error( EXPORTING text = |Dòng { <other>-excel_row }: hiệu lực chồng lấn với dòng { <row>-excel_row } | &&
                                    |(cùng { <row>-ma_congdoan }/{ <row>-bo_phan })|
                   CHANGING errors = errors ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
