CLASS zcl_mob_token_validator DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES: BEGIN OF validation_result,
             is_valid  TYPE abap_bool,
             user_uuid TYPE sysuuid_x16,
             session_id TYPE sysuuid_x16,
             error_code TYPE c LENGTH 40,
           END OF validation_result.
    TYPES: BEGIN OF worker_verification_result,
             is_valid         TYPE abap_bool,
             worker_user_uuid TYPE sysuuid_x16,
             worker_id        TYPE ztb_mob_user-worker_id,
             error_code       TYPE c LENGTH 40,
           END OF worker_verification_result.
    TYPES: BEGIN OF permission,
             func_id   TYPE ztb_mob_func-func_id,
             func_name TYPE ztb_mob_func-func_name,
             module    TYPE ztb_mob_func-module,
           END OF permission,
           permissions TYPE SORTED TABLE OF permission WITH UNIQUE KEY func_id.
    TYPES: BEGIN OF work_context,
             work_id    TYPE ztb_mob_work-work_id,
             work_name  TYPE ztb_mob_work-work_name,
             plant      TYPE ztb_mob_work-plant,
             workcenter TYPE ztb_mob_work-workcenter,
             bo_phan    TYPE ztb_mob_work-bo_phan,
             location   TYPE ztb_mob_work-location,
           END OF work_context,
           work_contexts TYPE SORTED TABLE OF work_context WITH UNIQUE KEY work_id.
    "Single source of truth for token hashing. Every entry point that
    "accepts a mobile token must hash it here instead of inline, otherwise
    "the implementations drift and a change to the hashing silently
    "invalidates sessions in one path while the other keeps accepting them.
    CLASS-METHODS hash_token
      IMPORTING token TYPE string
      RETURNING VALUE(hash) TYPE ztb_mob_session-access_token_hash
      RAISING cx_abap_message_digest zcx_mob_config.
    "Preferred entry point for callers holding the plain token. Pass
    "required_func to reject a caller that lacks the function.
    CLASS-METHODS validate_token
      IMPORTING token TYPE string
                device_id TYPE ztb_mob_session-device_id
                allow_password_change TYPE abap_bool DEFAULT abap_false
                required_func TYPE ztb_mob_func-func_id OPTIONAL
      RETURNING VALUE(result) TYPE validation_result
      RAISING cx_abap_message_digest zcx_mob_config.
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
    CLASS-METHODS get_work_contexts
      IMPORTING user_uuid TYPE sysuuid_x16
      RETURNING VALUE(result) TYPE work_contexts.
    CLASS-METHODS has_work_scope
      IMPORTING user_uuid TYPE sysuuid_x16
                plant TYPE ztb_mob_work-plant
                work_center TYPE ztb_mob_work-workcenter
      RETURNING VALUE(result) TYPE abap_bool.
    CLASS-METHODS has_function
      IMPORTING user_uuid TYPE sysuuid_x16
                func_id TYPE ztb_mob_func-func_id
      RETURNING VALUE(result) TYPE abap_bool.
    "The password KDF, in one place. It used to live privately in
    "lhc_mobileuser and was copied into verify_worker_password; the copies
    "would drift on any change to salting or iterations, and a worker would
    "then authenticate on one path and be rejected on the other.
    CLASS-METHODS hash_password
      IMPORTING password   TYPE string
                salt       TYPE string
                iterations TYPE i
      RETURNING VALUE(hash) TYPE ztb_mob_cred-password_hash
      RAISING cx_abap_message_digest zcx_mob_config.
    CLASS-METHODS verify_worker_password
      IMPORTING worker_id TYPE ztb_mob_user-worker_id
                password  TYPE string
      RETURNING VALUE(result) TYPE worker_verification_result
      RAISING cx_abap_message_digest zcx_mob_config.
ENDCLASS.

CLASS zcl_mob_token_validator IMPLEMENTATION.
  METHOD hash_token.
    IF token IS INITIAL.
      RAISE EXCEPTION NEW zcx_mob_config( config_key = 'EMPTY_TOKEN' ).
    ENDIF.
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

  METHOD get_work_contexts.
    SELECT FROM ztb_mob_usr_rol AS assignment
      INNER JOIN ztb_mob_role AS role_hdr
        ON role_hdr~role_id = assignment~role_id
      INNER JOIN ztb_mob_rol_wrk AS role_work
        ON role_work~role_id = assignment~role_id
      INNER JOIN ztb_mob_work AS work
        ON work~work_id = role_work~work_id
      FIELDS DISTINCT work~work_id, work~work_name, work~plant,
                      work~workcenter, work~bo_phan, work~location
      WHERE assignment~user_uuid = @user_uuid
        AND role_hdr~status = 'A'
        AND work~is_active = 'A'
      ORDER BY work~work_id
      INTO CORRESPONDING FIELDS OF TABLE @result.
  ENDMETHOD.

  METHOD has_work_scope.
    SELECT FROM ztb_mob_usr_rol AS assignment
      INNER JOIN ztb_mob_role AS role_hdr
        ON role_hdr~role_id = assignment~role_id
      INNER JOIN ztb_mob_rol_wrk AS role_work
        ON role_work~role_id = assignment~role_id
      INNER JOIN ztb_mob_work AS work
        ON work~work_id = role_work~work_id
      FIELDS work~work_id
      WHERE assignment~user_uuid = @user_uuid
        AND role_hdr~status = 'A'
        AND work~is_active = 'A'
        AND work~plant = @plant
        AND work~workcenter = @work_center
      INTO TABLE @DATA(scopes)
      UP TO 1 ROWS.
    result = xsdbool( scopes IS NOT INITIAL ).
  ENDMETHOD.

  METHOD has_function.
    "Authorization checks ask the database for one grant only. Building the
    "complete menu on every protected call used four joins plus DISTINCT and
    "materialized rows the caller did not ask for.
    SELECT FROM ztb_mob_usr_rol AS assignment
      INNER JOIN ztb_mob_role AS role_hdr
        ON role_hdr~role_id = assignment~role_id
      INNER JOIN ztb_mob_rol_fnc AS role_func
        ON role_func~role_id = assignment~role_id
      INNER JOIN ztb_mob_func AS func
        ON func~func_id = role_func~func_id
      FIELDS func~func_id
      WHERE assignment~user_uuid = @user_uuid
        AND role_hdr~status = 'A'
        AND func~func_id = @func_id
      INTO TABLE @DATA(grants)
      UP TO 1 ROWS.
    result = xsdbool( grants IS NOT INITIAL ).
  ENDMETHOD.

  METHOD validate_hash.
    DATA(now) = utclong_current( ).
    "Session and account state are checked in one round trip. The inner join
    "also fails closed if referential data is damaged.
    SELECT FROM ztb_mob_session AS session
      INNER JOIN ztb_mob_user AS user
        ON user~user_uuid = session~user_uuid
      FIELDS session~session_id, session~user_uuid, session~device_id,
             user~status AS user_status,
             user~password_change_required
      WHERE session~access_token_hash = @token_hash
        AND session~status = 'A'
        AND session~expires_at > @now
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
    IF session-user_status <> 'A'.
      result-error_code = 'USER_INACTIVE'.
      RETURN.
    ENDIF.
    IF session-password_change_required = abap_true
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

  METHOD hash_password.
    IF iterations < 10000 OR iterations > 100000 OR salt IS INITIAL.
      "A corrupt iteration value must not turn password verification into a
      "zero-round bypass or an unbounded CPU denial of service.
      RAISE EXCEPTION NEW zcx_mob_config(
        config_key = 'INVALID_PASSWORD_KDF' ).
    ENDIF.
    DATA(hasher) = NEW zcl_mob_hasher(
      iv_secret_key = zcl_mob_sec_config=>get_password_secret( ) ).
    DATA(hash_value) = salt && ':' && password.
    DO iterations TIMES.
      hash_value = hasher->calculate_hash( hash_value ).
    ENDDO.
    hash = hash_value.
  ENDMETHOD.

  METHOD verify_worker_password.
    SELECT FROM ztb_mob_user
      FIELDS user_uuid, worker_id, status
      WHERE worker_id = @worker_id
      INTO TABLE @DATA(matched_users)
      UP TO 2 ROWS.
    IF lines( matched_users ) <> 1.
      result-error_code = 'WORKER_AUTH_FAILED'.
      RETURN.
    ENDIF.
    DATA(user) = matched_users[ 1 ].
    IF user-status <> 'A'.
      result-error_code = 'WORKER_AUTH_FAILED'.
      RETURN.
    ENDIF.

    SELECT FROM ztb_mob_cred
      FIELDS password_hash, password_salt, hash_iterations, credential_status
      WHERE user_uuid = @user-user_uuid
      INTO TABLE @DATA(credentials)
      UP TO 1 ROWS.
    IF credentials IS INITIAL.
      result-error_code = 'WORKER_AUTH_FAILED'.
      RETURN.
    ENDIF.
    DATA(credential) = credentials[ 1 ].
    IF credential-credential_status <> 'A'.
      result-error_code = 'WORKER_AUTH_FAILED'.
      RETURN.
    ENDIF.

    DATA(hash_value) = hash_password(
      password = password
      salt = CONV string( credential-password_salt )
      iterations = credential-hash_iterations ).
    IF zcl_mob_hasher=>equals_constant_time(
         value_1 = CONV string( hash_value )
         value_2 = CONV string( credential-password_hash ) ) = abap_false.
      result-error_code = 'WORKER_AUTH_FAILED'.
      RETURN.
    ENDIF.

    result = VALUE #( is_valid = abap_true
                      worker_user_uuid = user-user_uuid
                      worker_id = user-worker_id ).
  ENDMETHOD.
ENDCLASS.
