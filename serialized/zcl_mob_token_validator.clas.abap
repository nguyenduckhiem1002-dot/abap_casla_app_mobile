CLASS zcl_mob_token_validator DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES: BEGIN OF validation_result,
             is_valid  TYPE abap_bool,
             user_uuid TYPE sysuuid_x16,
             session_id TYPE sysuuid_x16,
             error_code TYPE c LENGTH 40,
           END OF validation_result.
    TYPES: BEGIN OF permission,
             func_id   TYPE ztb_mob_func-func_id,
             func_name TYPE ztb_mob_func-func_name,
             module    TYPE ztb_mob_func-module,
           END OF permission,
           permissions TYPE STANDARD TABLE OF permission WITH EMPTY KEY.
    "Single source of truth for token hashing. Every entry point that
    "accepts a mobile token must hash it here instead of inline, otherwise
    "the implementations drift and a change to the hashing silently
    "invalidates sessions in one path while the other keeps accepting them.
    CLASS-METHODS hash_token
      IMPORTING token TYPE string
      RETURNING VALUE(hash) TYPE ztb_mob_session-access_token_hash
      RAISING cx_abap_message_digest.
    "Preferred entry point for callers holding the plain token. Pass
    "required_func to reject a caller that lacks the function.
    CLASS-METHODS validate_token
      IMPORTING token TYPE string
                device_id TYPE ztb_mob_session-device_id
                allow_password_change TYPE abap_bool DEFAULT abap_false
                required_func TYPE ztb_mob_func-func_id OPTIONAL
      RETURNING VALUE(result) TYPE validation_result
      RAISING cx_abap_message_digest.
    "For callers that already hold the hash and must not hash twice.
    CLASS-METHODS validate_hash
      IMPORTING token_hash TYPE ztb_mob_session-access_token_hash
                device_id TYPE ztb_mob_session-device_id
                allow_password_change TYPE abap_bool DEFAULT abap_false
                required_func TYPE ztb_mob_func-func_id OPTIONAL
      RETURNING VALUE(result) TYPE validation_result.
    "Effective functions of a user: every function granted by an active
    "role assigned to that user. Also the list handed to the device at
    "login, so what the app renders and what the backend enforces are
    "derived from the same query.
    CLASS-METHODS get_permissions
      IMPORTING user_uuid TYPE sysuuid_x16
      RETURNING VALUE(result) TYPE permissions.
    CLASS-METHODS has_function
      IMPORTING user_uuid TYPE sysuuid_x16
                func_id TYPE ztb_mob_func-func_id
      RETURNING VALUE(result) TYPE abap_bool.
ENDCLASS.

CLASS zcl_mob_token_validator IMPLEMENTATION.
  METHOD hash_token.
    DATA(hasher) = NEW zcl_mob_hasher(
      iv_secret_key = zcl_mob_sec_config=>get_token_secret( ) ).
    hash = CONV ztb_mob_session-access_token_hash(
      hasher->calculate_hash( token ) ).
  ENDMETHOD.

  METHOD validate_token.
    result = validate_hash(
      token_hash = hash_token( token )
      device_id = device_id
      allow_password_change = allow_password_change
      required_func = required_func ).
  ENDMETHOD.

  METHOD get_permissions.
    "DISTINCT because two roles may grant the same function. Inactive roles
    "are excluded here rather than on assignment, so deactivating a role
    "revokes its functions at once without touching the assignment rows.
    SELECT FROM ztb_mob_usr_rol AS assignment
      INNER JOIN ztb_mob_role AS role_hdr
        ON role_hdr~role_id = assignment~role_id
      INNER JOIN ztb_mob_rol_fnc AS role_func
        ON role_func~role_id = assignment~role_id
      INNER JOIN ztb_mob_func AS func
        ON func~func_id = role_func~func_id
      FIELDS DISTINCT func~func_id, func~func_name, func~module
      WHERE assignment~user_uuid = @user_uuid
        AND role_hdr~status = 'A'
      ORDER BY func~func_id
      INTO CORRESPONDING FIELDS OF TABLE @result.
  ENDMETHOD.

  METHOD has_function.
    "Answered from the database on every call. The permission list returned
    "at login is for rendering the app menu only and is never an input to
    "this check - a device could send back anything.
    DATA(wanted) = func_id.
    DATA(granted) = get_permissions( user_uuid ).
    result = xsdbool( line_exists( granted[ func_id = wanted ] ) ).
  ENDMETHOD.

  METHOD validate_hash.
    DATA(now) = utclong_current( ).
    SELECT FROM ztb_mob_session
      FIELDS session_id, user_uuid, device_id, status, expires_at
      WHERE access_token_hash = @token_hash
        AND status = 'A'
        AND expires_at > @now
      INTO TABLE @DATA(matched_sessions)
      UP TO 2 ROWS.
    IF lines( matched_sessions ) <> 1.
      result-error_code = 'TOKEN_INVALID_OR_EXPIRED'.
      RETURN.
    ENDIF.
    DATA(session) = matched_sessions[ 1 ].
    IF session-device_id <> device_id.
      result-error_code = 'DEVICE_MISMATCH'.
      RETURN.
    ENDIF.
    SELECT FROM ztb_mob_user
      FIELDS status, password_change_required
      WHERE user_uuid = @session-user_uuid
      INTO TABLE @DATA(matched_users)
      UP TO 1 ROWS.
    IF matched_users IS INITIAL.
      result-error_code = 'USER_INACTIVE'.
      RETURN.
    ENDIF.
    DATA(user) = matched_users[ 1 ].
    IF user-status <> 'A'.
      result-error_code = 'USER_INACTIVE'.
      RETURN.
    ENDIF.
    IF user-password_change_required = abap_true
       AND allow_password_change = abap_false.
      result-error_code = 'PASSWORD_CHANGE_REQUIRED'.
      RETURN.
    ENDIF.
    IF required_func IS NOT INITIAL
       AND has_function( user_uuid = session-user_uuid
                         func_id = required_func ) = abap_false.
      result-error_code = 'MISSING_PERMISSION'.
      RETURN.
    ENDIF.
    result = VALUE #( is_valid = abap_true
                      user_uuid = session-user_uuid
                      session_id = session-session_id ).
  ENDMETHOD.
ENDCLASS.
