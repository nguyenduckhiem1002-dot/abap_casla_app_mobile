CLASS zcl_mob_config DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.

    CONSTANTS:
      c_password_pepper TYPE ztb_mob_config-config_key
        VALUE 'PASSWORD_PEPPER',
      c_token_secret    TYPE ztb_mob_config-config_key
        VALUE 'TOKEN_SECRET'.

    TYPES:
      BEGIN OF ty_config,
        config_key   TYPE ztb_mob_config-config_key,
        config_value TYPE ztb_mob_config-config_value,
        is_active    TYPE ztb_mob_config-is_active,
      END OF ty_config,

      tt_config TYPE SORTED TABLE OF ty_config
        WITH UNIQUE KEY config_key.

    METHODS upsert_configs
      IMPORTING
        it_config               TYPE tt_config
      RETURNING
        VALUE(rv_affected_rows) TYPE i
      RAISING
        cx_abap_context_info_error.

ENDCLASS.


CLASS zcl_mob_config IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    "Điền hai giá trị trong ADT trước khi chạy. Không commit secret lên Git.
    DATA(lt_config) = VALUE tt_config(
      (
        config_key   = c_password_pepper
        config_value = ``
        is_active    = abap_true
      )
      (
        config_key   = c_token_secret
        config_value = ``
        is_active    = abap_true
      )
    ).

    DATA(lv_filled_count) = 0.

    LOOP AT lt_config ASSIGNING FIELD-SYMBOL(<config>)
      WHERE config_value IS NOT INITIAL.

      lv_filled_count += 1.

      "Mỗi secret phải có tối thiểu 32 ký tự.
      IF strlen( CONV string( <config>-config_value ) ) < 32.
        out->write(
          |Key { <config>-config_key } phải có ít nhất 32 ký tự.| ).
        RETURN.
      ENDIF.

    ENDLOOP.

    IF lv_filled_count = 0.
      out->write(
        'Chưa điền value. Không có dữ liệu nào được thay đổi.' ).
      RETURN.
    ENDIF.

    TRY.

        DATA(lv_affected_rows) = upsert_configs( lt_config ).

        COMMIT WORK.

        out->write(
          |Đã thêm hoặc cập nhật { lv_affected_rows } key.| ).

        out->write(
          'Các key cũ khác vẫn được giữ nguyên.' ).

        out->write(
          'Không hiển thị secret value ra console.' ).

      CATCH cx_abap_context_info_error INTO DATA(lx_context).

        ROLLBACK WORK.
        out->write( lx_context->get_text( ) ).

      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).

        ROLLBACK WORK.
        out->write( lx_sql->get_text( ) ).

    ENDTRY.

  ENDMETHOD.


  METHOD upsert_configs.

    "Chỉ lấy các dòng đã được điền value.
    "Value trống không ghi đè dữ liệu đang có.
    DATA(lt_filled_config) = VALUE tt_config(
      FOR ls_config IN it_config
      WHERE ( config_value IS NOT INITIAL )
      ( ls_config )
    ).

    IF lt_filled_config IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_changed_by) =
      cl_abap_context_info=>get_user_technical_name( ).

    DATA lv_changed_at TYPE ztb_mob_config-changed_at.
    GET TIME STAMP FIELD lv_changed_at.

    DATA lt_database_config TYPE STANDARD TABLE OF ztb_mob_config
      WITH EMPTY KEY.

    lt_database_config = VALUE #(
      FOR ls_config IN lt_filled_config
      (
        client       = sy-mandt
        config_key   = ls_config-config_key
        config_value = ls_config-config_value
        is_active    = ls_config-is_active
        changed_by   = lv_changed_by
        changed_at   = lv_changed_at
      )
    ).

    "Bootstrap chỉ thêm key còn thiếu. Không ghi đè secret đã có trong tenant.
    SELECT FROM ztb_mob_config
      FIELDS config_key
      FOR ALL ENTRIES IN @lt_database_config
      WHERE config_key = @lt_database_config-config_key
      INTO TABLE @DATA(existing_keys).
    LOOP AT existing_keys ASSIGNING FIELD-SYMBOL(<existing_key>).
      DELETE lt_database_config WHERE config_key = <existing_key>-config_key.
    ENDLOOP.
    IF lt_database_config IS INITIAL.
      RETURN.
    ENDIF.
    INSERT ztb_mob_config FROM TABLE @lt_database_config.

    rv_affected_rows = sy-dbcnt.

  ENDMETHOD.

ENDCLASS.
