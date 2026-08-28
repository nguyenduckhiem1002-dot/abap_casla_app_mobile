CLASS lhc_congdoan DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR CongDoan RESULT result.
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
      result-%delete = if_abap_behv=>auth-unauthorized.
    ENDIF.
  ENDMETHOD.

  METHOD validateMaster.
    READ ENTITIES OF zi_md_congdoan IN LOCAL MODE
      ENTITY CongDoan ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(records).

    LOOP AT records ASSIGNING FIELD-SYMBOL(<record>).
      DATA(invalid) = abap_false.

      IF <record>-MaCongDoan IS INITIAL
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