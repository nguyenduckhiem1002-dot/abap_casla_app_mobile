CLASS lhc_congdoan DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR CongDoan RESULT result.
    METHODS uploadExcel FOR MODIFY
      IMPORTING keys FOR ACTION CongDoan~uploadExcel RESULT result.
    METHODS validateMaster FOR VALIDATE ON SAVE
      IMPORTING keys FOR CongDoan~validateMaster.
ENDCLASS.

CLASS lhc_congdoan IMPLEMENTATION.
  METHOD get_global_authorizations.
    "Service này là ranh giới quản trị Fiori/IAM. Không hard-delete phiên bản
    "đơn giá lịch sử; khi hết hiệu lực thì đóng khoảng validity bằng ValidTo.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-uploadExcel = if_abap_behv=>mk-on.
      result-%action-uploadExcel = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD uploadExcel.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.
    DATA(cid) = CONV string( keys[ 1 ]-%cid ).
    DATA(upload_errors) = VALUE string_table( ).
    IF lines( keys ) > 1.
      APPEND 'Mỗi yêu cầu chỉ được tải một file' TO upload_errors.
    ELSEIF keys[ 1 ]-%param-fileContent IS INITIAL.
      APPEND 'Nội dung file Excel là bắt buộc' TO upload_errors.
    ELSE.
      zcl_md_cd_upload=>parse( EXPORTING content = keys[ 1 ]-%param-fileContent
                               IMPORTING rows = DATA(rows) errors = upload_errors ).
    ENDIF.
    IF upload_errors IS NOT INITIAL.
      APPEND VALUE #( %cid = cid ) TO failed-congdoan.
      LOOP AT upload_errors INTO DATA(error_text).
        APPEND VALUE #( %cid = cid
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error text = error_text ) )
          TO reported-congdoan.
      ENDLOOP.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zi_md_congdoan IN LOCAL MODE
      ENTITY CongDoan
        CREATE FIELDS ( MaCongDoan ValidFrom BoPhan TenCongDoan DonGiaXM DonGiaGC ValidTo )
        WITH VALUE #( FOR row IN rows
          ( %cid = row-cid MaCongDoan = row-ma_congdoan ValidFrom = row-valid_from
            BoPhan = row-bo_phan TenCongDoan = row-ten_congdoan
            DonGiaXM = row-dongia_xm DonGiaGC = row-dongia_gc ValidTo = row-valid_to ) )
      FAILED DATA(failed_create) REPORTED DATA(reported_create).
    IF failed_create IS NOT INITIAL.
      failed = CORRESPONDING #( failed_create ).
      reported = CORRESPONDING #( reported_create ).
      RETURN.
    ENDIF.
    result = VALUE #( ( %cid = cid %param-CreatedCount = lines( rows ) ) ).
  ENDMETHOD.

  METHOD validateMaster.
    READ ENTITIES OF zi_md_congdoan IN LOCAL MODE
      ENTITY CongDoan ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(records).

    LOOP AT records ASSIGNING FIELD-SYMBOL(<record>).
      DATA(invalid) = abap_false.

      IF <record>-MaCongDoan IS INITIAL
         OR <record>-BoPhan IS INITIAL
         OR <record>-TenCongDoan IS INITIAL
         OR <record>-ValidFrom IS INITIAL
         OR <record>-ValidTo IS INITIAL
         OR <record>-ValidFrom > <record>-ValidTo
         OR <record>-DonGiaXM < 0
         OR <record>-DonGiaGC < 0.
        invalid = abap_true.
      ENDIF.

      IF invalid = abap_false.
        SELECT FROM ztb_md_congdoan
          FIELDS ma_congdoan
          WHERE ma_congdoan = @<record>-MaCongDoan
            AND bo_phan = @<record>-BoPhan
            AND valid_from <> @<record>-ValidFrom
            AND valid_from <= @<record>-ValidTo
            AND valid_to >= @<record>-ValidFrom
          INTO TABLE @DATA(overlaps)
          UP TO 1 ROWS.
        IF overlaps IS NOT INITIAL.
          invalid = abap_true.
        ENDIF.
      ENDIF.

      IF invalid = abap_false.
        LOOP AT records ASSIGNING FIELD-SYMBOL(<other>).
          IF <other>-MaCongDoan <> <record>-MaCongDoan
             OR <other>-BoPhan <> <record>-BoPhan
             OR <other>-ValidFrom = <record>-ValidFrom.
            CONTINUE.
          ENDIF.
          IF <other>-ValidFrom <= <record>-ValidTo
             AND <other>-ValidTo >= <record>-ValidFrom.
            invalid = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.
      ENDIF.

      IF invalid = abap_true.
        APPEND VALUE #( %tky = <record>-%tky ) TO failed-congdoan.
        APPEND VALUE #(
          %tky = <record>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Kiểm tra mã, tên, đơn giá và khoảng hiệu lực; validity không được chồng lấn' ) )
          TO reported-congdoan.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


