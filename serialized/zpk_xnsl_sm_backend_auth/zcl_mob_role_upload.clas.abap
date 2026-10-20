CLASS zcl_mob_role_upload DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES BEGIN OF ty_role.
    TYPES cid TYPE string.
    TYPES excel_row TYPE i.
    TYPES role_id TYPE ztb_mob_role-role_id.
    TYPES role_name TYPE ztb_mob_role-role_name.
    TYPES status TYPE ztb_mob_role-status.
    TYPES is_existing TYPE abap_bool.
    TYPES END OF ty_role.
    TYPES tt_role TYPE STANDARD TABLE OF ty_role WITH EMPTY KEY.
    TYPES BEGIN OF ty_link.
    TYPES cid TYPE string.
    TYPES excel_row TYPE i.
    TYPES role_id TYPE ztb_mob_role-role_id.
    TYPES role_cid TYPE string.
    TYPES role_is_new TYPE abap_bool.
    TYPES item_id TYPE ztb_mob_func-func_id.
    TYPES END OF ty_link.
    TYPES tt_link TYPE STANDARD TABLE OF ty_link WITH EMPTY KEY.
    TYPES BEGIN OF ty_result.
    TYPES roles TYPE tt_role.
    TYPES functions TYPE tt_link.
    TYPES works TYPE tt_link.
    TYPES errors TYPE string_table.
    TYPES END OF ty_result.

    CLASS-METHODS parse
      IMPORTING content       TYPE xstring
      RETURNING VALUE(result) TYPE ty_result.

  PRIVATE SECTION.
    CONSTANTS c_header_rows TYPE i VALUE 1.
    CONSTANTS c_max_roles TYPE i VALUE 200.
    CONSTANTS c_max_links TYPE i VALUE 2000.
    CONSTANTS c_max_errors TYPE i VALUE 20.
    CONSTANTS c_kind_function TYPE c LENGTH 1 VALUE 'F'.
    CONSTANTS c_kind_work TYPE c LENGTH 1 VALUE 'W'.
    TYPES BEGIN OF ty_role_input.
    TYPES role_id TYPE string.
    TYPES role_name TYPE string.
    TYPES status TYPE string.
    TYPES END OF ty_role_input.
    TYPES tt_role_input TYPE STANDARD TABLE OF ty_role_input WITH EMPTY KEY.
    TYPES BEGIN OF ty_link_input.
    TYPES role_id TYPE string.
    TYPES item_id TYPE string.
    TYPES END OF ty_link_input.
    TYPES tt_link_input TYPE STANDARD TABLE OF ty_link_input WITH EMPTY KEY.
    TYPES tt_keys TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    CLASS-METHODS add_error
      IMPORTING text   TYPE string
      CHANGING  errors TYPE string_table.
    CLASS-METHODS read_sheet
      IMPORTING content       TYPE xstring
                position      TYPE i
                target        TYPE REF TO data
      RETURNING VALUE(result) TYPE abap_bool.
    CLASS-METHODS build_roles
      IMPORTING inputs TYPE tt_role_input
      CHANGING  roles  TYPE tt_role
                errors TYPE string_table.
    CLASS-METHODS build_links
      IMPORTING inputs     TYPE tt_link_input
                kind       TYPE c
                sheet_name TYPE string
                roles      TYPE tt_role
      CHANGING  links      TYPE tt_link
                errors     TYPE string_table.
    CLASS-METHODS item_is_valid
      IMPORTING kind          TYPE c
                item_id       TYPE ztb_mob_func-func_id
      RETURNING VALUE(result) TYPE abap_bool.
    CLASS-METHODS link_exists
      IMPORTING kind          TYPE c
                role_id       TYPE ztb_mob_role-role_id
                item_id       TYPE ztb_mob_func-func_id
      RETURNING VALUE(result) TYPE abap_bool.
    CLASS-METHODS role_exists
      IMPORTING role_id       TYPE ztb_mob_role-role_id
      RETURNING VALUE(result) TYPE abap_bool.
ENDCLASS.



CLASS ZCL_MOB_ROLE_UPLOAD IMPLEMENTATION.


  METHOD add_error.
    IF lines( errors ) < c_max_errors.
      APPEND text TO errors.
    ENDIF.
  ENDMETHOD.


  METHOD parse.
    DATA role_inputs TYPE tt_role_input.
    DATA function_inputs TYPE tt_link_input.
    DATA work_inputs TYPE tt_link_input.
    IF read_sheet( content = content position = 1 target = REF #( role_inputs ) ) = abap_false.
      APPEND 'Không đọc được file Excel hoặc sheet đầu tiên (ChucDanh)' TO result-errors.
      RETURN.
    ENDIF.
    "Sheet 2 và 3 không bắt buộc: thiếu sheet thì coi như không có dòng nào.
    IF read_sheet( content = content position = 2 target = REF #( function_inputs ) ) = abap_false.
      CLEAR function_inputs.
    ENDIF.
    IF read_sheet( content = content position = 3 target = REF #( work_inputs ) ) = abap_false.
      CLEAR work_inputs.
    ENDIF.
    DELETE role_inputs FROM 1 TO c_header_rows.
    DELETE function_inputs FROM 1 TO c_header_rows.
    DELETE work_inputs FROM 1 TO c_header_rows.

    build_roles( EXPORTING inputs = role_inputs CHANGING roles = result-roles errors = result-errors ).
    build_links( EXPORTING inputs = function_inputs kind = c_kind_function sheet_name = 'QuyenChucNang'
                           roles = result-roles
                 CHANGING links = result-functions errors = result-errors ).
    build_links( EXPORTING inputs = work_inputs kind = c_kind_work sheet_name = 'PhamViWorkID'
                           roles = result-roles
                 CHANGING links = result-works errors = result-errors ).

    IF result-errors IS INITIAL AND result-roles IS INITIAL AND result-functions IS INITIAL
       AND result-works IS INITIAL.
      APPEND 'File Excel không có dòng dữ liệu nào' TO result-errors.
    ENDIF.
    IF result-errors IS NOT INITIAL.
      CLEAR: result-roles, result-functions, result-works.
    ENDIF.
  ENDMETHOD.


  METHOD read_sheet.
    result = abap_false.
    TRY.
        DATA(xlsx) = xco_cp_xlsx=>document->for_file_content( iv_file_content = content )->read_access( ).
        DATA(sheet) = xlsx->get_workbook( )->worksheet->at_position( position ).
        DATA(pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).
        DATA(execute) = sheet->select( pattern )->row_stream( )->operation->write_to( target ).
        execute->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
          )->if_xco_xlsx_ra_operation~execute( ).
        result = abap_true.
      CATCH cx_root.
        result = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD role_exists.
    SELECT FROM ztb_mob_role
      FIELDS role_id
      WHERE role_id = @role_id
      INTO TABLE @DATA(found)
      UP TO 1 ROWS.
    result = xsdbool( found IS NOT INITIAL ).
  ENDMETHOD.


  METHOD build_roles.
    DATA seen TYPE tt_keys.
    LOOP AT inputs INTO DATA(input).
      DATA(excel_row) = sy-tabix + c_header_rows.
      DATA(role_id) = to_upper( condense( input-role_id ) ).
      DATA(role_name) = condense( input-role_name ).
      DATA(status) = COND string( WHEN  input-status IS INITIAL THEN 'A'
                                  ELSE to_upper( condense( input-status ) ) ).
      IF role_id IS INITIAL AND role_name IS INITIAL AND input-status IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(label) = |Sheet ChucDanh dòng { excel_row }: |.
      IF role_id IS INITIAL OR role_name IS INITIAL.
        add_error( EXPORTING text = label && 'Mã chức danh và tên chức danh là bắt buộc'
                   CHANGING errors = errors ).
        CONTINUE.
      ENDIF.
      IF strlen( role_id ) > 20 OR strlen( role_name ) > 120.
        add_error( EXPORTING text = label && 'Dữ liệu vượt độ dài cho phép' CHANGING errors = errors ).
        CONTINUE.
      ENDIF.
      IF status <> 'A' AND status <> 'I'.
        add_error( EXPORTING text = label && 'Trạng thái chỉ được là A hoặc I' CHANGING errors = errors ).
        CONTINUE.
      ENDIF.
      INSERT role_id INTO TABLE seen.
      IF sy-subrc <> 0.
        add_error( EXPORTING text = label && |Mã chức danh { role_id } bị trùng trong sheet|
                   CHANGING errors = errors ).
        CONTINUE.
      ENDIF.
      APPEND VALUE #( cid = |ROL_{ role_id }| excel_row = excel_row role_id = role_id
        role_name = role_name status = status
        is_existing = role_exists( CONV #( role_id ) ) ) TO roles.
    ENDLOOP.
    IF lines( roles ) > c_max_roles.
      add_error( EXPORTING text = |Sheet ChucDanh vượt quá { c_max_roles } chức danh|
                 CHANGING errors = errors ).
    ENDIF.
  ENDMETHOD.


  METHOD item_is_valid.
    IF kind = c_kind_function.
      SELECT FROM ztb_mob_func
        FIELDS func_id
        WHERE func_id = @item_id
        INTO TABLE @DATA(functions)
        UP TO 1 ROWS.
      result = xsdbool( functions IS NOT INITIAL ).
    ELSE.
      DATA(work_id) = CONV ztb_mob_work-work_id( item_id ).
      SELECT FROM ztb_mob_work
        FIELDS work_id
        WHERE work_id = @work_id
          AND is_active = 'A'
        INTO TABLE @DATA(works)
        UP TO 1 ROWS.
      result = xsdbool( works IS NOT INITIAL ).
    ENDIF.
  ENDMETHOD.


  METHOD link_exists.
    IF kind = c_kind_function.
      SELECT FROM ztb_mob_rol_fnc
        FIELDS role_id
        WHERE role_id = @role_id
          AND func_id = @item_id
        INTO TABLE @DATA(functions)
        UP TO 1 ROWS.
      result = xsdbool( functions IS NOT INITIAL ).
    ELSE.
      DATA(work_id) = CONV ztb_mob_rol_wrk-work_id( item_id ).
      SELECT FROM ztb_mob_rol_wrk
        FIELDS role_id
        WHERE role_id = @role_id
          AND work_id = @work_id
        INTO TABLE @DATA(works)
        UP TO 1 ROWS.
      result = xsdbool( works IS NOT INITIAL ).
    ENDIF.
  ENDMETHOD.


  METHOD build_links.
    DATA seen TYPE tt_keys.
    LOOP AT inputs INTO DATA(input).
      DATA(excel_row) = sy-tabix + c_header_rows.
      DATA(role_id) = to_upper( condense( input-role_id ) ).
      DATA(item_id) = condense( input-item_id ).
      IF role_id IS INITIAL AND item_id IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(label) = |Sheet { sheet_name } dòng { excel_row }: |.
      IF role_id IS INITIAL OR item_id IS INITIAL.
        add_error( EXPORTING text = label && 'Mã chức danh và mã chức năng/Work ID là bắt buộc'
                   CHANGING errors = errors ).
        CONTINUE.
      ENDIF.
      IF strlen( role_id ) > 20 OR strlen( item_id ) > 30.
        add_error( EXPORTING text = label && 'Dữ liệu vượt độ dài cho phép' CHANGING errors = errors ).
        CONTINUE.
      ENDIF.

      DATA(role_cid) = VALUE string( ).
      DATA(role_is_new) = abap_false.
      ASSIGN roles[ role_id = role_id ] TO FIELD-SYMBOL(<role>).
      IF sy-subrc = 0.
        role_cid = <role>-cid.
        role_is_new = xsdbool( <role>-is_existing = abap_false ).
      ELSEIF role_exists( CONV #( role_id ) ) = abap_false.
        add_error( EXPORTING text = label && |Chức danh { role_id } không có trong sheet ChucDanh và chưa tồn tại|
                   CHANGING errors = errors ).
        CONTINUE.
      ENDIF.

      IF item_is_valid( kind = kind item_id = CONV #( item_id ) ) = abap_false.
        add_error( EXPORTING text = label && COND string(
                     WHEN kind = c_kind_function THEN |Chức năng { item_id } không tồn tại|
                     ELSE |Work ID { item_id } không tồn tại hoặc đã ngừng hoạt động| )
                   CHANGING errors = errors ).
        CONTINUE.
      ENDIF.
      INSERT |{ role_id }/{ item_id }| INTO TABLE seen.
      IF sy-subrc <> 0.
        add_error( EXPORTING text = label && |{ role_id }/{ item_id } bị trùng trong sheet|
                   CHANGING errors = errors ).
        CONTINUE.
      ENDIF.
      IF link_exists( kind = kind role_id = CONV #( role_id ) item_id = CONV #( item_id ) ) = abap_true.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( cid = |{ kind }_{ excel_row }| excel_row = excel_row role_id = role_id
        role_cid = role_cid role_is_new = role_is_new item_id = item_id ) TO links.
    ENDLOOP.
    IF lines( links ) > c_max_links.
      add_error( EXPORTING text = |Sheet { sheet_name } vượt quá { c_max_links } dòng|
                 CHANGING errors = errors ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
