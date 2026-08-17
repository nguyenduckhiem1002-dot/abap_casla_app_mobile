CLASS zcl_mob_token_validator DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES: BEGIN OF validation_result,
             is_valid  TYPE abap_bool,
             user_uuid TYPE sysuuid_x16,
             session_id TYPE sysuuid_x16,
             error_code TYPE c LENGTH 40,
           END OF validation_result.
    CLASS-METHODS validate_hash
      IMPORTING token_hash TYPE ztb_mob_session-access_token_hash
                device_id TYPE ztb_mob_session-device_id
      RETURNING VALUE(result) TYPE validation_result.
ENDCLASS.

CLASS zcl_mob_token_validator IMPLEMENTATION.
  METHOD validate_hash.
    DATA(now) = utclong_current( ).
    SELECT SINGLE FROM ztb_mob_session
      FIELDS session_id, user_uuid, device_id, status, expires_at
      WHERE access_token_hash = @token_hash
        AND status = 'A'
        AND expires_at > @now
      INTO @DATA(session).
    IF sy-subrc <> 0.
      result-error_code = 'TOKEN_INVALID_OR_EXPIRED'.
      RETURN.
    ENDIF.
    IF session-device_id <> device_id.
      result-error_code = 'DEVICE_MISMATCH'.
      RETURN.
    ENDIF.
    SELECT SINGLE FROM ztb_mob_user
      FIELDS @abap_true
      WHERE user_uuid = @session-user_uuid
        AND status = 'A'
      INTO @DATA(user_active).
    IF user_active <> abap_true.
      result-error_code = 'USER_INACTIVE'.
      RETURN.
    ENDIF.
    result = VALUE #( is_valid = abap_true
                      user_uuid = session-user_uuid
                      session_id = session-session_id ).
  ENDMETHOD.
ENDCLASS.
