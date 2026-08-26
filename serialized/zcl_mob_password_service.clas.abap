CLASS zcl_mob_password_service DEFINITION
  PUBLIC FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    TYPES: BEGIN OF verification,
             is_valid   TYPE abap_bool,
             error_code TYPE c LENGTH 40,
             user_uuid  TYPE sysuuid_x16,
           END OF verification.
    CLASS-METHODS calculate_hash
      IMPORTING password TYPE string
                salt TYPE string
                iterations TYPE i
      RETURNING VALUE(hash) TYPE ztb_mob_cred-password_hash
      RAISING cx_abap_message_digest.
    CLASS-METHODS verify_worker
      IMPORTING worker_id TYPE ztb_mob_user-worker_id
                password TYPE string
      RETURNING VALUE(result) TYPE verification
      RAISING cx_abap_message_digest.
ENDCLASS.

CLASS zcl_mob_password_service IMPLEMENTATION.
  METHOD calculate_hash.
    IF password IS INITIAL OR salt IS INITIAL OR iterations <= 0.
      RETURN.
    ENDIF.
    DATA(hasher) = NEW zcl_mob_hasher(
      iv_secret_key = zcl_mob_sec_config=>get_password_secret( ) ).
    DATA(hash_value) = salt && ':' && password.
    DO iterations TIMES.
      hash_value = hasher->calculate_hash( hash_value ).
    ENDDO.
    hash = hash_value.
  ENDMETHOD.

  METHOD verify_worker.
    IF worker_id IS INITIAL OR password IS INITIAL.
      result-error_code = 'WORKER_CREDENTIAL_REQUIRED'.
      RETURN.
    ENDIF.
    SELECT FROM ztb_mob_user AS account
      INNER JOIN ztb_mob_cred AS credential
        ON credential~user_uuid = account~user_uuid
      FIELDS account~user_uuid, account~status,
             credential~password_hash, credential~password_salt,
             credential~hash_iterations, credential~credential_status
      WHERE account~worker_id = @worker_id
      INTO TABLE @DATA(credentials)
      UP TO 2 ROWS.
    IF lines( credentials ) <> 1.
      result-error_code = COND #(
        WHEN credentials IS INITIAL THEN 'WORKER_ACCOUNT_NOT_FOUND'
        ELSE 'WORKER_MAPPING_NOT_UNIQUE' ).
      RETURN.
    ENDIF.
    DATA(credential) = credentials[ 1 ].
    IF credential-status <> 'A' OR credential-credential_status <> 'A'.
      result-error_code = 'WORKER_ACCOUNT_INACTIVE'.
      RETURN.
    ENDIF.
    DATA(input_hash) = calculate_hash(
      password = password
      salt = CONV string( credential-password_salt )
      iterations = credential-hash_iterations ).
    IF zcl_mob_hasher=>equals_constant_time(
         value_1 = CONV string( input_hash )
         value_2 = CONV string( credential-password_hash ) ) = abap_false.
      result-error_code = 'WORKER_PASSWORD_INVALID'.
      RETURN.
    ENDIF.
    result-user_uuid = credential-user_uuid.
    result-is_valid = abap_true.
  ENDMETHOD.
ENDCLASS.
