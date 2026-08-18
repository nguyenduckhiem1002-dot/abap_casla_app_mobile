CLASS lhc_mobileuser DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS c_iterations TYPE i VALUE 10000.
    TYPES reported_response TYPE RESPONSE FOR REPORTED zi_mob_user.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR MobileUser RESULT result.
    METHODS createuser FOR MODIFY
      IMPORTING keys FOR ACTION MobileUser~createUser RESULT result.
    METHODS login FOR MODIFY
      IMPORTING keys FOR ACTION MobileUser~login RESULT result.
    METHODS logout FOR MODIFY IMPORTING keys FOR ACTION MobileUser~logout.
    METHODS refresh FOR MODIFY
      IMPORTING keys FOR ACTION MobileUser~refresh RESULT result.
    METHODS changepassword FOR MODIFY
      IMPORTING keys FOR ACTION MobileUser~changePassword.
    METHODS hash_password
      IMPORTING password TYPE string salt TYPE string iterations TYPE i
      RETURNING VALUE(hash) TYPE ztb_mob_cred-password_hash
      RAISING cx_abap_message_digest.
    METHODS hash_token
      IMPORTING token TYPE string
      RETURNING VALUE(hash) TYPE ztb_mob_session-access_token_hash
      RAISING cx_abap_message_digest.
    METHODS report_error
      IMPORTING cid TYPE string text TYPE string
      CHANGING reported TYPE reported_response.
ENDCLASS.

CLASS lhc_mobileuser IMPLEMENTATION.
  METHOD get_global_authorizations.
    AUTHORITY-CHECK OBJECT 'Z_MOB_USR'
      ID 'ACTVT' FIELD '01'.
    result-%action-createUser = COND #(
      WHEN sy-subrc = 0 THEN if_abap_behv=>auth-allowed
      ELSE if_abap_behv=>auth-unauthorized ).
    result-%create = if_abap_behv=>auth-unauthorized.
    result-%update = if_abap_behv=>auth-unauthorized.
    result-%delete = if_abap_behv=>auth-unauthorized.
  ENDMETHOD.

  METHOD hash_password.
    DATA(hasher) = NEW zcl_mob_hasher(
      iv_secret_key = zcl_mob_sec_config=>get_password_secret( ) ).
    DATA(hash_value) = salt && ':' && password.
    DO iterations TIMES.
      hash_value = hasher->calculate_hash( hash_value ).
    ENDDO.
    hash = hash_value.
  ENDMETHOD.

  METHOD hash_token.
    DATA(hasher) = NEW zcl_mob_hasher(
      iv_secret_key = zcl_mob_sec_config=>get_token_secret( ) ).
    hash = CONV ztb_mob_session-access_token_hash(
      hasher->calculate_hash( token ) ).
  ENDMETHOD.

  METHOD report_error.
    APPEND VALUE #( %cid = cid
      %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-error text = text ) )
      TO reported-mobileuser.
  ENDMETHOD.

  METHOD createuser.
    DATA(input) = VALUE #( keys[ 1 ]-%param OPTIONAL ).
    DATA(cid) = CONV string( keys[ 1 ]-%cid ).
    DATA(normalized) = to_lower( condense( CONV string( input-Username ) ) ).
    IF normalized IS INITIAL OR input-Password IS INITIAL.
      report_error( EXPORTING cid = cid text = 'Tên đăng nhập và mật khẩu là bắt buộc'
                    CHANGING reported = reported ).
      RETURN.
    ENDIF.
    SELECT SINGLE FROM ztb_mob_user FIELDS @abap_true
      WHERE normalized_username = @normalized INTO @DATA(user_exists).
    IF user_exists = abap_true.
      report_error( EXPORTING cid = cid text = 'Tên đăng nhập đã tồn tại'
                    CHANGING reported = reported ).
      RETURN.
    ENDIF.
    TRY.
        DATA(salt) = cl_system_uuid=>create_uuid_c36_static( ).
        DATA(password_hash) = hash_password(
          password = CONV string( input-Password )
          salt = CONV string( salt ) iterations = c_iterations ).
      CATCH cx_uuid_error cx_abap_message_digest zcx_mob_config INTO DATA(error).
        report_error( EXPORTING cid = cid text = error->get_text( )
                      CHANGING reported = reported ).
        RETURN.
    ENDTRY.
    DATA(now) = utclong_current( ).
    MODIFY ENTITIES OF zi_mob_user IN LOCAL MODE
      ENTITY MobileUser CREATE FIELDS
        ( Username NormalizedUsername FullName Email Status FailedLoginCount
          PasswordChangeRequired )
      WITH VALUE #( ( %cid = 'USR' Username = input-Username
        NormalizedUsername = normalized FullName = input-FullName
        Email = input-Email Status = 'A' FailedLoginCount = 0
        PasswordChangeRequired = abap_true ) )
      ENTITY MobileUser CREATE BY \_Credential FIELDS
        ( PasswordHash PasswordSalt HashAlgorithm HashIterations
          PasswordChangedAt CredentialStatus )
      WITH VALUE #( ( %cid_ref = 'USR'
        %target = VALUE #( ( %cid = 'CRD' PasswordHash = password_hash
          PasswordSalt = salt HashAlgorithm = 'SHA256-ITER'
          HashIterations = c_iterations PasswordChangedAt = now
          CredentialStatus = 'A' ) ) ) )
      MAPPED DATA(mapped_create) FAILED DATA(failed_create)
      REPORTED DATA(reported_create).
    IF failed_create IS NOT INITIAL.
      failed = CORRESPONDING #( failed_create ).
      reported = CORRESPONDING #( reported_create ).
      RETURN.
    ENDIF.
    DATA(user_uuid) = VALUE sysuuid_x16(
      mapped_create-mobileuser[ %cid = 'USR' ]-UserUUID OPTIONAL ).
    READ ENTITIES OF zi_mob_user IN LOCAL MODE ENTITY MobileUser
      ALL FIELDS WITH VALUE #( ( UserUUID = user_uuid ) ) RESULT DATA(users).
    result = VALUE #( FOR user IN users
      ( %cid = cid %tky = user-%tky %param = user ) ).
  ENDMETHOD.

  METHOD login.
    DATA(input) = VALUE #( keys[ 1 ]-%param OPTIONAL ).
    DATA(cid) = CONV string( keys[ 1 ]-%cid ).
    DATA(now) = utclong_current( ).
    DATA(normalized) = to_lower( condense( CONV string( input-Username ) ) ).
    SELECT SINGLE FROM ztb_mob_user
      FIELDS user_uuid, status, failed_login_count, locked_until,
             password_change_required
      WHERE normalized_username = @normalized INTO @DATA(user).
    IF sy-subrc <> 0 OR user-status <> 'A'
       OR ( user-locked_until IS NOT INITIAL AND user-locked_until > now ).
      report_error( EXPORTING cid = cid text = 'Tên đăng nhập hoặc mật khẩu không hợp lệ'
                    CHANGING reported = reported ).
      RETURN.
    ENDIF.
    SELECT SINGLE FROM ztb_mob_cred
      FIELDS password_hash, password_salt, hash_iterations, credential_status
      WHERE user_uuid = @user-user_uuid INTO @DATA(credential).
    IF sy-subrc <> 0 OR credential-credential_status <> 'A'.
      report_error( EXPORTING cid = cid text = 'Thông tin xác thực không hoạt động'
                    CHANGING reported = reported ).
      RETURN.
    ENDIF.
    TRY.
        DATA(input_hash) = hash_password(
          password = CONV string( input-Password )
          salt = CONV string( credential-password_salt )
          iterations = credential-hash_iterations ).
      CATCH cx_abap_message_digest zcx_mob_config INTO DATA(hash_error).
        report_error( EXPORTING cid = cid text = hash_error->get_text( )
                      CHANGING reported = reported ).
        RETURN.
    ENDTRY.
    IF input_hash <> credential-password_hash.
      DATA(failed_count) = user-failed_login_count + 1.
      DATA(locked_until) = COND utclong(
        WHEN failed_count >= 5 THEN utclong_add( val = now minutes = 15 )
        ELSE CONV utclong( '' ) ).
      MODIFY ENTITIES OF zi_mob_user IN LOCAL MODE ENTITY MobileUser
        UPDATE FIELDS ( FailedLoginCount LockedUntil )
        WITH VALUE #( ( UserUUID = user-user_uuid
          FailedLoginCount = failed_count LockedUntil = locked_until ) ).
      report_error( EXPORTING cid = cid text = 'Tên đăng nhập hoặc mật khẩu không hợp lệ'
                    CHANGING reported = reported ).
      RETURN.
    ENDIF.
    TRY.
        DATA(access_token) = cl_system_uuid=>create_uuid_c36_static( )
                          && cl_system_uuid=>create_uuid_c36_static( ).
        DATA(refresh_token) = cl_system_uuid=>create_uuid_c36_static( )
                           && cl_system_uuid=>create_uuid_c36_static( ).
        DATA(access_hash) = hash_token( CONV string( access_token ) ).
        DATA(refresh_hash) = hash_token( CONV string( refresh_token ) ).
      CATCH cx_uuid_error cx_abap_message_digest zcx_mob_config INTO DATA(token_error).
        report_error( EXPORTING cid = cid text = token_error->get_text( )
                      CHANGING reported = reported ).
        RETURN.
    ENDTRY.
    DATA(expires_at) = utclong_add( val = now minutes = 30 ).
    MODIFY ENTITIES OF zi_mob_user IN LOCAL MODE
      ENTITY MobileUser CREATE BY \_Sessions FIELDS
        ( AccessTokenHash RefreshTokenHash TokenVersion LoginAt LastActivityAt
          ExpiresAt RefreshExpiresAt Status DeviceID )
      WITH VALUE #( ( UserUUID = user-user_uuid
        %target = VALUE #( ( %cid = 'SES' AccessTokenHash = access_hash
          RefreshTokenHash = refresh_hash TokenVersion = 1 LoginAt = now
          LastActivityAt = now ExpiresAt = expires_at
          RefreshExpiresAt = utclong_add( val = now days = 30 )
          Status = 'A' DeviceID = input-DeviceID ) ) ) )
      MAPPED DATA(mapped_session) FAILED DATA(failed_session)
      REPORTED DATA(reported_session).
    IF failed_session IS NOT INITIAL.
      failed = CORRESPONDING #( failed_session ).
      reported = CORRESPONDING #( reported_session ).
      RETURN.
    ENDIF.
    MODIFY ENTITIES OF zi_mob_user IN LOCAL MODE ENTITY MobileUser
      UPDATE FIELDS ( FailedLoginCount LockedUntil LastLoginAt )
      WITH VALUE #( ( UserUUID = user-user_uuid FailedLoginCount = 0
        LockedUntil = CONV utclong( '' ) LastLoginAt = now ) ).
    DATA(session_id) = VALUE sysuuid_x16(
      mapped_session-mobilesession[ %cid = 'SES' ]-SessionID OPTIONAL ).
    result = VALUE #( ( %cid = cid %param-UserUUID = user-user_uuid
      %param-SessionID = session_id %param-AccessToken = access_token
      %param-RefreshToken = refresh_token %param-ExpiresAt = expires_at
      %param-Status = COND #( WHEN user-password_change_required = abap_true
                              THEN 'P' ELSE 'A' )
      %param-PasswordChangeRequired = user-password_change_required ) ).
  ENDMETHOD.

  METHOD logout.
    DATA(input) = VALUE #( keys[ 1 ]-%param OPTIONAL ).
    DATA(cid) = CONV string( keys[ 1 ]-%cid ).
    TRY.
        DATA(token_hash) = hash_token( CONV string( input-AccessToken ) ).
      CATCH cx_abap_message_digest zcx_mob_config INTO DATA(error).
        report_error( EXPORTING cid = cid text = error->get_text( )
                      CHANGING reported = reported ).
        RETURN.
    ENDTRY.
    SELECT SINGLE FROM ztb_mob_session FIELDS session_id
      WHERE access_token_hash = @token_hash AND device_id = @input-DeviceID
        AND status = 'A' INTO @DATA(session_id).
    IF sy-subrc <> 0.
      report_error( EXPORTING cid = cid text = 'Token không hợp lệ'
                    CHANGING reported = reported ).
      RETURN.
    ENDIF.
    MODIFY ENTITIES OF zi_mob_user IN LOCAL MODE ENTITY MobileSession
      UPDATE FIELDS ( Status LogoutAt RevokedReason )
      WITH VALUE #( ( SessionID = session_id Status = 'R'
        LogoutAt = utclong_current( ) RevokedReason = 'LOGOUT' ) )
      FAILED DATA(failed_update) REPORTED DATA(reported_update).
    failed = CORRESPONDING #( failed_update ).
    reported = CORRESPONDING #( reported_update ).
  ENDMETHOD.

  METHOD refresh.
    DATA(input) = VALUE #( keys[ 1 ]-%param OPTIONAL ).
    DATA(cid) = CONV string( keys[ 1 ]-%cid ).
    DATA(now) = utclong_current( ).
    TRY.
        DATA(old_hash) = hash_token( CONV string( input-RefreshToken ) ).
      CATCH cx_abap_message_digest zcx_mob_config INTO DATA(error).
        report_error( EXPORTING cid = cid text = error->get_text( )
                      CHANGING reported = reported ).
        RETURN.
    ENDTRY.
    SELECT SINGLE FROM ztb_mob_session
      FIELDS session_id, user_uuid, token_version
      WHERE refresh_token_hash = @old_hash AND device_id = @input-DeviceID
        AND status = 'A' AND refresh_expires_at > @now INTO @DATA(session).
    IF sy-subrc <> 0.
      report_error( EXPORTING cid = cid text = 'Refresh token không hợp lệ hoặc hết hạn'
                    CHANGING reported = reported ).
      RETURN.
    ENDIF.
    TRY.
        DATA(access_token) = cl_system_uuid=>create_uuid_c36_static( )
                          && cl_system_uuid=>create_uuid_c36_static( ).
        DATA(refresh_token) = cl_system_uuid=>create_uuid_c36_static( )
                           && cl_system_uuid=>create_uuid_c36_static( ).
        DATA(access_hash) = hash_token( CONV string( access_token ) ).
        DATA(refresh_hash) = hash_token( CONV string( refresh_token ) ).
      CATCH cx_uuid_error cx_abap_message_digest zcx_mob_config INTO DATA(token_error).
        report_error( EXPORTING cid = cid text = token_error->get_text( )
                      CHANGING reported = reported ).
        RETURN.
    ENDTRY.
    DATA(expires_at) = utclong_add( val = now minutes = 30 ).
    MODIFY ENTITIES OF zi_mob_user IN LOCAL MODE ENTITY MobileSession
      UPDATE FIELDS ( AccessTokenHash RefreshTokenHash TokenVersion
        LastActivityAt ExpiresAt RefreshExpiresAt )
      WITH VALUE #( ( SessionID = session-session_id
        AccessTokenHash = access_hash RefreshTokenHash = refresh_hash
        TokenVersion = session-token_version + 1 LastActivityAt = now
        ExpiresAt = expires_at
        RefreshExpiresAt = utclong_add( val = now days = 30 ) ) )
      FAILED DATA(failed_update) REPORTED DATA(reported_update).
    IF failed_update IS NOT INITIAL.
      failed = CORRESPONDING #( failed_update ).
      reported = CORRESPONDING #( reported_update ).
      RETURN.
    ENDIF.
    result = VALUE #( ( %cid = cid %param-UserUUID = session-user_uuid
      %param-SessionID = session-session_id %param-AccessToken = access_token
      %param-RefreshToken = refresh_token %param-ExpiresAt = expires_at
      %param-Status = 'A' ) ).
  ENDMETHOD.

  METHOD changepassword.
    DATA(input) = VALUE #( keys[ 1 ]-%param OPTIONAL ).
    DATA(cid) = CONV string( keys[ 1 ]-%cid ).
    TRY.
        DATA(token_hash) = hash_token( CONV string( input-AccessToken ) ).
      CATCH cx_abap_message_digest zcx_mob_config INTO DATA(error).
        report_error( EXPORTING cid = cid text = error->get_text( )
                      CHANGING reported = reported ).
        RETURN.
    ENDTRY.
    DATA(auth) = zcl_mob_token_validator=>validate_hash(
      token_hash = token_hash device_id = input-DeviceID
      allow_password_change = abap_true ).
    IF auth-is_valid = abap_false.
      report_error( EXPORTING cid = cid text = |Token không hợp lệ: { auth-error_code }|
                    CHANGING reported = reported ).
      RETURN.
    ENDIF.
    SELECT SINGLE FROM ztb_mob_cred
      FIELDS password_hash, password_salt, hash_iterations
      WHERE user_uuid = @auth-user_uuid INTO @DATA(credential).
    TRY.
        DATA(current_hash) = hash_password(
          password = CONV string( input-CurrentPassword )
          salt = CONV string( credential-password_salt )
          iterations = credential-hash_iterations ).
        IF current_hash <> credential-password_hash.
          report_error( EXPORTING cid = cid text = 'Mật khẩu hiện tại không đúng'
                        CHANGING reported = reported ).
          RETURN.
        ENDIF.
        DATA(new_salt) = cl_system_uuid=>create_uuid_c36_static( ).
        DATA(new_hash) = hash_password(
          password = CONV string( input-NewPassword )
          salt = CONV string( new_salt ) iterations = c_iterations ).
      CATCH cx_uuid_error cx_abap_message_digest zcx_mob_config INTO DATA(sec_error).
        report_error( EXPORTING cid = cid text = sec_error->get_text( )
                      CHANGING reported = reported ).
        RETURN.
    ENDTRY.
    MODIFY ENTITIES OF zi_mob_user IN LOCAL MODE
      ENTITY MobileCredential UPDATE FIELDS
        ( PasswordHash PasswordSalt HashAlgorithm HashIterations
          PasswordChangedAt CredentialStatus )
      WITH VALUE #( ( UserUUID = auth-user_uuid PasswordHash = new_hash
        PasswordSalt = new_salt HashAlgorithm = 'SHA256-ITER'
        HashIterations = c_iterations PasswordChangedAt = utclong_current( )
        CredentialStatus = 'A' ) )
      ENTITY MobileUser UPDATE FIELDS ( PasswordChangeRequired )
      WITH VALUE #( ( UserUUID = auth-user_uuid
        PasswordChangeRequired = abap_false ) )
      FAILED DATA(failed_update) REPORTED DATA(reported_update).
    failed = CORRESPONDING #( failed_update ).
    reported = CORRESPONDING #( reported_update ).
  ENDMETHOD.
ENDCLASS.
