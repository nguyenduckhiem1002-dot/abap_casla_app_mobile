CLASS lhc_mobileuser DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS c_iterations TYPE i VALUE 10000.
    TYPES reported_response TYPE RESPONSE FOR REPORTED zi_mob_user.
    TYPES failed_response TYPE RESPONSE FOR FAILED zi_mob_user.
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
      CHANGING failed TYPE failed_response reported TYPE reported_response.
ENDCLASS.

CLASS lhc_mobileuser IMPLEMENTATION.
  METHOD get_global_authorizations.
    "The Fiori admin service is protected by its IAM app/business catalog.
    result-%action-createUser = if_abap_behv=>auth-allowed.
    result-%action-login = if_abap_behv=>auth-allowed.
    result-%action-refresh = if_abap_behv=>auth-allowed.
    result-%action-logout = if_abap_behv=>auth-allowed.
    result-%action-changePassword = if_abap_behv=>auth-allowed.
    result-%create = if_abap_behv=>auth-unauthorized.
    result-%delete = if_abap_behv=>auth-unauthorized.
    "MobileUserRole is a composition child declared "authorization dependent
    "by _User", so RAP delegates every operation on it - create by
    "association, update, delete - to this master's %update. Leaving %update
    "unauthorized would reject role assignment from the admin app at runtime.
    "The external write surface stays closed at the projection layer:
    "ZC_MOB_User_Adm exposes only createUser plus the _Roles composition, and
    "ZC_MOB_User only the auth actions - neither declares "use update".
    result-%update = if_abap_behv=>auth-allowed.
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
    "Delegates so token hashing has exactly one implementation, shared with
    "every other entry point that has to accept a mobile token.
    hash = zcl_mob_token_validator=>hash_token( token ).
  ENDMETHOD.

  METHOD report_error.
    APPEND VALUE #( %cid = cid ) TO failed-mobileuser.
    APPEND VALUE #( %cid = cid
      %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-error text = text ) )
      TO reported-mobileuser.
  ENDMETHOD.

  METHOD createuser.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.
    IF lines( keys ) > 1.
      LOOP AT keys ASSIGNING FIELD-SYMBOL(<create_key>).
        report_error(
          EXPORTING cid = CONV string( <create_key>-%cid )
                    text = 'Mỗi yêu cầu chỉ được tạo một tài khoản'
          CHANGING failed = failed reported = reported ).
      ENDLOOP.
      RETURN.
    ENDIF.
    DATA(input) = VALUE #( keys[ 1 ]-%param OPTIONAL ).
    DATA(cid) = CONV string( keys[ 1 ]-%cid ).
    DATA(normalized) = to_lower( condense( CONV string( input-Username ) ) ).
    IF normalized IS INITIAL OR input-Password IS INITIAL.
      report_error( EXPORTING cid = cid text = 'Tên đăng nhập và mật khẩu là bắt buộc'
                    CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    SELECT FROM ztb_mob_user FIELDS user_uuid
      WHERE normalized_username = @normalized
      INTO TABLE @DATA(existing_users)
      UP TO 1 ROWS.
    IF existing_users IS NOT INITIAL.
      report_error( EXPORTING cid = cid text = 'Tên đăng nhập đã tồn tại'
                    CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    TRY.
        DATA(salt) = cl_system_uuid=>create_uuid_c36_static( ).
        DATA(password_hash) = hash_password(
          password = CONV string( input-Password )
          salt = CONV string( salt ) iterations = c_iterations ).
      CATCH cx_uuid_error cx_abap_message_digest zcx_mob_config INTO DATA(error).
        report_error( EXPORTING cid = cid text = error->get_text( )
                      CHANGING failed = failed reported = reported ).
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
    "Static action: the result row only has %cid and %param (no %tky,
    "there is no bound instance). %param is the plain entity structure,
    "so strip the %-components from the read result via CORRESPONDING.
    result = VALUE #( FOR user IN users
      ( %cid = cid %param = CORRESPONDING #( user ) ) ).
  ENDMETHOD.

  METHOD login.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.
    IF lines( keys ) > 1.
      LOOP AT keys ASSIGNING FIELD-SYMBOL(<login_key>).
        report_error(
          EXPORTING cid = CONV string( <login_key>-%cid )
                    text = 'Mỗi yêu cầu chỉ được đăng nhập một tài khoản'
          CHANGING failed = failed reported = reported ).
      ENDLOOP.
      RETURN.
    ENDIF.
    DATA(input) = VALUE #( keys[ 1 ]-%param OPTIONAL ).
    DATA(cid) = CONV string( keys[ 1 ]-%cid ).
    DATA(now) = utclong_current( ).
    DATA(normalized) = to_lower( condense( CONV string( input-Username ) ) ).
    SELECT FROM ztb_mob_user
      FIELDS user_uuid, status, failed_login_count, locked_until,
             password_change_required
      WHERE normalized_username = @normalized
      INTO TABLE @DATA(matched_users)
      UP TO 2 ROWS.
    IF lines( matched_users ) <> 1.
      report_error( EXPORTING cid = cid text = 'Tên đăng nhập hoặc mật khẩu không hợp lệ'
                    CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    DATA(user) = matched_users[ 1 ].
    IF user-status <> 'A'
       OR ( user-locked_until IS NOT INITIAL AND user-locked_until > now ).
      report_error( EXPORTING cid = cid text = 'Tên đăng nhập hoặc mật khẩu không hợp lệ'
                    CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    SELECT FROM ztb_mob_cred
      FIELDS password_hash, password_salt, hash_iterations, credential_status
      WHERE user_uuid = @user-user_uuid
      INTO TABLE @DATA(login_credentials)
      UP TO 1 ROWS.
    IF login_credentials IS INITIAL.
      report_error( EXPORTING cid = cid text = 'Tên đăng nhập hoặc mật khẩu không hợp lệ'
                    CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    DATA(credential) = login_credentials[ 1 ].
    IF credential-credential_status <> 'A'.
      report_error( EXPORTING cid = cid text = 'Tên đăng nhập hoặc mật khẩu không hợp lệ'
                    CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    TRY.
        DATA(input_hash) = hash_password(
          password = CONV string( input-Password )
          salt = CONV string( credential-password_salt )
          iterations = credential-hash_iterations ).
      CATCH cx_abap_message_digest zcx_mob_config INTO DATA(hash_error).
        report_error( EXPORTING cid = cid text = hash_error->get_text( )
                      CHANGING failed = failed reported = reported ).
        RETURN.
    ENDTRY.
    IF zcl_mob_hasher=>equals_constant_time(
         value_1 = CONV string( input_hash )
         value_2 = CONV string( credential-password_hash ) ) = abap_false.
      "Business failure is returned in the result payload instead of FAILED:
      "setting FAILED would skip the save sequence and roll back the
      "FailedLoginCount/LockedUntil update, disabling the lockout protection.
      DATA(failed_count) = user-failed_login_count + 1.
      DATA(locked_until) = COND utclong(
        WHEN failed_count >= 5 THEN utclong_add( val = now minutes = 15 )
        ELSE VALUE utclong( ) ).
      MODIFY ENTITIES OF zi_mob_user IN LOCAL MODE ENTITY MobileUser
        UPDATE FIELDS ( FailedLoginCount LockedUntil )
        WITH VALUE #( ( UserUUID = user-user_uuid
          FailedLoginCount = failed_count LockedUntil = locked_until ) )
        FAILED DATA(failed_counter_update)
        REPORTED DATA(reported_counter_update).
      IF failed_counter_update IS NOT INITIAL.
        failed = CORRESPONDING #( failed_counter_update ).
        reported = CORRESPONDING #( reported_counter_update ).
        RETURN.
      ENDIF.
      result = VALUE #( ( %cid = cid %param-Status = 'F' ) ).
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
                      CHANGING failed = failed reported = reported ).
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
    DATA(session_id) = VALUE sysuuid_x16(
      mapped_session-mobilesession[ %cid = 'SES' ]-SessionID OPTIONAL ).
    MODIFY ENTITIES OF zi_mob_user IN LOCAL MODE ENTITY MobileUser
      UPDATE FIELDS ( FailedLoginCount LockedUntil LastLoginAt )
      WITH VALUE #( ( UserUUID = user-user_uuid FailedLoginCount = 0
        LockedUntil = VALUE utclong( ) LastLoginAt = now ) )
      FAILED DATA(failed_login_update)
      REPORTED DATA(reported_login_update).
    IF failed_login_update IS NOT INITIAL.
      "FAILED rejects the whole LUW, so the session created above is
      "discarded together with this update - no compensation needed.
      failed = CORRESPONDING #( failed_login_update ).
      reported = CORRESPONDING #( reported_login_update ).
      RETURN.
    ENDIF.
    "Handed to the device so it can render its menu without a second round
    "trip. Display only: every protected operation re-checks the function
    "server side through zcl_mob_token_validator, which never reads this.
    DATA(permissions) = zcl_mob_token_validator=>get_permissions(
      user-user_uuid ).
    result = VALUE #( ( %cid = cid %param = VALUE #(
      UserUUID = user-user_uuid
      SessionID = session_id
      AccessToken = access_token
      RefreshToken = refresh_token
      ExpiresAt = expires_at
      Status = COND #( WHEN user-password_change_required = abap_true
                       THEN 'P' ELSE 'A' )
      PasswordChangeRequired = user-password_change_required
      _Permissions = VALUE #( FOR permission IN permissions
        ( FuncID = permission-func_id
          FuncName = permission-func_name
          Module = permission-module ) ) ) ) ).
  ENDMETHOD.

  METHOD logout.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.
    IF lines( keys ) > 1.
      LOOP AT keys ASSIGNING FIELD-SYMBOL(<logout_key>).
        report_error(
          EXPORTING cid = CONV string( <logout_key>-%cid )
                    text = 'Mỗi yêu cầu chỉ được đăng xuất một phiên'
          CHANGING failed = failed reported = reported ).
      ENDLOOP.
      RETURN.
    ENDIF.
    DATA(input) = VALUE #( keys[ 1 ]-%param OPTIONAL ).
    DATA(cid) = CONV string( keys[ 1 ]-%cid ).
    TRY.
        DATA(token_hash) = hash_token( CONV string( input-AccessToken ) ).
      CATCH cx_abap_message_digest zcx_mob_config INTO DATA(error).
        report_error( EXPORTING cid = cid text = error->get_text( )
                      CHANGING failed = failed reported = reported ).
        RETURN.
    ENDTRY.
    SELECT FROM ztb_mob_session FIELDS session_id
      WHERE access_token_hash = @token_hash AND device_id = @input-DeviceID
        AND status = 'A'
      INTO TABLE @DATA(logout_sessions)
      UP TO 2 ROWS.
    IF lines( logout_sessions ) <> 1.
      report_error( EXPORTING cid = cid text = 'Token không hợp lệ'
                    CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    DATA(session_id) = logout_sessions[ 1 ]-session_id.
    MODIFY ENTITIES OF zi_mob_user IN LOCAL MODE ENTITY MobileSession
      UPDATE FIELDS ( Status LogoutAt RevokedReason )
      WITH VALUE #( ( SessionID = session_id Status = 'R'
        LogoutAt = utclong_current( ) RevokedReason = 'LOGOUT' ) )
      FAILED DATA(failed_update) REPORTED DATA(reported_update).
    failed = CORRESPONDING #( failed_update ).
    reported = CORRESPONDING #( reported_update ).
  ENDMETHOD.

  METHOD refresh.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.
    IF lines( keys ) > 1.
      LOOP AT keys ASSIGNING FIELD-SYMBOL(<refresh_key>).
        report_error(
          EXPORTING cid = CONV string( <refresh_key>-%cid )
                    text = 'Mỗi yêu cầu chỉ được làm mới một phiên'
          CHANGING failed = failed reported = reported ).
      ENDLOOP.
      RETURN.
    ENDIF.
    DATA(input) = VALUE #( keys[ 1 ]-%param OPTIONAL ).
    DATA(cid) = CONV string( keys[ 1 ]-%cid ).
    DATA(now) = utclong_current( ).
    TRY.
        DATA(old_hash) = hash_token( CONV string( input-RefreshToken ) ).
      CATCH cx_abap_message_digest zcx_mob_config INTO DATA(error).
        report_error( EXPORTING cid = cid text = error->get_text( )
                      CHANGING failed = failed reported = reported ).
        RETURN.
    ENDTRY.
    SELECT FROM ztb_mob_session
      FIELDS session_id, user_uuid, token_version
      WHERE refresh_token_hash = @old_hash AND device_id = @input-DeviceID
        AND status = 'A' AND refresh_expires_at > @now
      INTO TABLE @DATA(refresh_sessions)
      UP TO 2 ROWS.
    IF lines( refresh_sessions ) <> 1.
      report_error( EXPORTING cid = cid text = 'Refresh token không hợp lệ hoặc hết hạn'
                    CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    DATA(session) = refresh_sessions[ 1 ].
    TRY.
        DATA(access_token) = cl_system_uuid=>create_uuid_c36_static( )
                          && cl_system_uuid=>create_uuid_c36_static( ).
        DATA(refresh_token) = cl_system_uuid=>create_uuid_c36_static( )
                           && cl_system_uuid=>create_uuid_c36_static( ).
        DATA(access_hash) = hash_token( CONV string( access_token ) ).
        DATA(refresh_hash) = hash_token( CONV string( refresh_token ) ).
      CATCH cx_uuid_error cx_abap_message_digest zcx_mob_config INTO DATA(token_error).
        report_error( EXPORTING cid = cid text = token_error->get_text( )
                      CHANGING failed = failed reported = reported ).
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
    "Refreshing also refreshes the permission list, so an assignment made
    "while the session was open reaches the device at the next rotation.
    DATA(permissions) = zcl_mob_token_validator=>get_permissions(
      session-user_uuid ).
    result = VALUE #( ( %cid = cid %param = VALUE #(
      UserUUID = session-user_uuid
      SessionID = session-session_id
      AccessToken = access_token
      RefreshToken = refresh_token
      ExpiresAt = expires_at
      Status = 'A'
      _Permissions = VALUE #( FOR permission IN permissions
        ( FuncID = permission-func_id
          FuncName = permission-func_name
          Module = permission-module ) ) ) ) ).
  ENDMETHOD.

  METHOD changepassword.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.
    IF lines( keys ) > 1.
      LOOP AT keys ASSIGNING FIELD-SYMBOL(<password_key>).
        report_error(
          EXPORTING cid = CONV string( <password_key>-%cid )
                    text = 'Mỗi yêu cầu chỉ được đổi mật khẩu một tài khoản'
          CHANGING failed = failed reported = reported ).
      ENDLOOP.
      RETURN.
    ENDIF.
    DATA(input) = VALUE #( keys[ 1 ]-%param OPTIONAL ).
    DATA(cid) = CONV string( keys[ 1 ]-%cid ).
    TRY.
        DATA(auth) = zcl_mob_token_validator=>validate_token(
          token = CONV string( input-AccessToken )
          device_id = input-DeviceID
          allow_password_change = abap_true ).
      CATCH cx_abap_message_digest zcx_mob_config INTO DATA(error).
        report_error( EXPORTING cid = cid text = error->get_text( )
                      CHANGING failed = failed reported = reported ).
        RETURN.
    ENDTRY.
    IF auth-is_valid = abap_false.
      report_error( EXPORTING cid = cid text = |Token không hợp lệ: { auth-error_code }|
                    CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    SELECT FROM ztb_mob_cred
      FIELDS password_hash, password_salt, hash_iterations
      WHERE user_uuid = @auth-user_uuid
      INTO TABLE @DATA(password_credentials)
      UP TO 1 ROWS.
    IF password_credentials IS INITIAL.
      report_error( EXPORTING cid = cid text = 'Tên đăng nhập hoặc mật khẩu không hợp lệ'
                    CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    DATA(credential) = password_credentials[ 1 ].
    TRY.
        DATA(current_hash) = hash_password(
          password = CONV string( input-CurrentPassword )
          salt = CONV string( credential-password_salt )
          iterations = credential-hash_iterations ).
        IF zcl_mob_hasher=>equals_constant_time(
             value_1 = CONV string( current_hash )
             value_2 = CONV string( credential-password_hash ) ) = abap_false.
          report_error( EXPORTING cid = cid text = 'Mật khẩu hiện tại không đúng'
                        CHANGING failed = failed reported = reported ).
          RETURN.
        ENDIF.
        DATA(new_salt) = cl_system_uuid=>create_uuid_c36_static( ).
        DATA(new_hash) = hash_password(
          password = CONV string( input-NewPassword )
          salt = CONV string( new_salt ) iterations = c_iterations ).
      CATCH cx_uuid_error cx_abap_message_digest zcx_mob_config INTO DATA(sec_error).
        report_error( EXPORTING cid = cid text = sec_error->get_text( )
                      CHANGING failed = failed reported = reported ).
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
    IF failed_update IS NOT INITIAL.
      RETURN.
    ENDIF.

    "Revoke every other active session; the session that authorized this
    "password change stays valid so the device is not logged out mid-flow.
    SELECT FROM ztb_mob_session
      FIELDS session_id
      WHERE user_uuid = @auth-user_uuid
        AND status = 'A'
        AND session_id <> @auth-session_id
      INTO TABLE @DATA(active_sessions).
    IF active_sessions IS NOT INITIAL.
      MODIFY ENTITIES OF zi_mob_user IN LOCAL MODE
        ENTITY MobileSession UPDATE FIELDS
          ( Status LogoutAt RevokedReason )
        WITH VALUE #( FOR session IN active_sessions
          ( SessionID = session-session_id
            Status = 'R'
            LogoutAt = utclong_current( )
            RevokedReason = 'PWD_CHANGE' ) )
        FAILED DATA(failed_revoke)
        REPORTED DATA(reported_revoke).
      IF failed_revoke IS NOT INITIAL.
        failed = CORRESPONDING #( failed_revoke ).
        reported = CORRESPONDING #( reported_revoke ).
      ENDIF.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
