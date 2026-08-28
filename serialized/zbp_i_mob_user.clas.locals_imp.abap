CLASS lhc_mobileuser DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS c_iterations TYPE i VALUE 10000.
    CONSTANTS c_min_password_length TYPE i VALUE 6.
    CONSTANTS c_max_active_sessions TYPE i VALUE 5.
    CONSTANTS c_max_failed_logins TYPE i VALUE 5.
    CONSTANTS c_failure_window_minutes TYPE i VALUE 1.
    CONSTANTS c_lock_minutes TYPE i VALUE 10.
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
    METHODS changePasswordAdmin FOR MODIFY
      IMPORTING keys FOR ACTION MobileUser~changePasswordAdmin.
    METHODS unlockUser FOR MODIFY
      IMPORTING keys   FOR ACTION MobileUser~unlockUser
      RESULT    result.
    METHODS hash_password
      IMPORTING password TYPE string salt TYPE string iterations TYPE i
      RETURNING VALUE(hash) TYPE ztb_mob_cred-password_hash
      RAISING cx_abap_message_digest zcx_mob_config.
    METHODS hash_token
      IMPORTING token       TYPE string
      RETURNING VALUE(hash) TYPE ztb_mob_session-access_token_hash
      RAISING   cx_abap_message_digest zcx_mob_config.
    METHODS report_error
      IMPORTING cid TYPE string text TYPE string
      CHANGING failed TYPE failed_response reported TYPE reported_response.
    METHODS password_is_acceptable
      IMPORTING password TYPE string username TYPE string OPTIONAL
      RETURNING VALUE(result) TYPE abap_bool.
    METHODS consume_dummy_password_hash
      IMPORTING password TYPE string
      RAISING   cx_abap_message_digest zcx_mob_config.
    METHODS role_is_active
      IMPORTING role_id       TYPE ztb_mob_role-role_id
      RETURNING VALUE(result) TYPE abap_bool.
    METHODS revoke_login_sessions
      IMPORTING user_uuid TYPE ztb_mob_user-user_uuid
                device_id TYPE ztb_mob_session-device_id
                now       TYPE utclong
      CHANGING success  TYPE abap_bool
               failed   TYPE failed_response
               reported TYPE reported_response.
ENDCLASS.

CLASS lhc_mobileuser IMPLEMENTATION.
  METHOD get_global_authorizations.
    "Service quản trị Fiori được bảo vệ bằng IAM app/business catalog.
    result-%action-createUser = if_abap_behv=>auth-allowed.
    result-%action-login = if_abap_behv=>auth-allowed.
    result-%action-refresh = if_abap_behv=>auth-allowed.
    result-%action-logout = if_abap_behv=>auth-allowed.
    result-%action-changePassword = if_abap_behv=>auth-allowed.
    result-%create = if_abap_behv=>auth-unauthorized.
    result-%delete = if_abap_behv=>auth-unauthorized.
    "MobileUserRole là composition child khai báo authorization dependent by _User,
    "vì vậy RAP dùng quyền %update của master cho create-by-association và delete.
    "Nếu %update bị unauthorized thì thao tác gán chức danh từ app quản trị sẽ
    "bị chặn ở runtime. Bề mặt ghi bên ngoài vẫn được đóng ở projection layer:
    "ZC_MOB_User_Adm chỉ expose createUser và composition _Roles, còn
    "ZC_MOB_User chỉ expose các action xác thực; cả hai đều không expose update.
    result-%update = if_abap_behv=>auth-allowed.

    result-%action-changePasswordAdmin  = if_abap_behv=>auth-allowed.
    result-%action-unlockUser           = if_abap_behv=>auth-allowed.
  ENDMETHOD.

  METHOD hash_password.
    "Ủy quyền cho implementation KDF dùng chung để việc hash mật khẩu chỉ có một
    "nguồn logic, đồng thời được dùng cho xác thực mật khẩu nhân công ở PP action.
    hash = zcl_mob_token_validator=>hash_password(
      password = password
      salt = salt
      iterations = iterations ).
  ENDMETHOD.

  METHOD hash_token.
    "Ủy quyền cho implementation hash token dùng chung để mọi entry point nhận
    "mobile token đều sử dụng cùng một thuật toán và cấu hình.
    hash = zcl_mob_token_validator=>hash_token( token ).
  ENDMETHOD.

  METHOD report_error.
    APPEND VALUE #( %cid = cid ) TO failed-mobileuser.
    APPEND VALUE #( %cid = cid
      %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-error text = text ) )
      TO reported-mobileuser.
  ENDMETHOD.

  METHOD password_is_acceptable.
    DATA(password_lower) = to_lower( password ).
    DATA(username_lower) = to_lower( condense( username ) ).
    result = xsdbool(
      strlen( password ) >= c_min_password_length
      AND ( username_lower IS INITIAL
         OR password_lower NS username_lower ) ).
  ENDMETHOD.

  METHOD consume_dummy_password_hash.
    DATA(ignored_hash) = hash_password(
      password = password
      salt = '00000000-0000-0000-0000-000000000000'
      iterations = c_iterations ) ##NEEDED.
  ENDMETHOD.

  METHOD role_is_active.
    SELECT FROM ztb_mob_role
      FIELDS role_id
      WHERE role_id = @role_id
        AND status = 'A'
      INTO TABLE @DATA(active_roles)
      UP TO 1 ROWS.
    result = xsdbool( active_roles IS NOT INITIAL ).
  ENDMETHOD.

  METHOD revoke_login_sessions.
    success = abap_true.
    SELECT FROM ztb_mob_session
      FIELDS session_id, device_id
      WHERE user_uuid = @user_uuid
        AND status = 'A'
      ORDER BY login_at DESCENDING
      INTO TABLE @DATA(login_sessions).
    DATA sessions_to_revoke TYPE SORTED TABLE OF sysuuid_x16
                            WITH UNIQUE KEY table_line.
    LOOP AT login_sessions ASSIGNING FIELD-SYMBOL(<login_session>).
      IF <login_session>-device_id = device_id
         OR sy-tabix >= c_max_active_sessions.
        INSERT <login_session>-session_id INTO TABLE sessions_to_revoke.
      ENDIF.
    ENDLOOP.
    IF sessions_to_revoke IS NOT INITIAL.
      MODIFY ENTITIES OF zi_mob_user IN LOCAL MODE
        ENTITY MobileSession UPDATE FIELDS
          ( Status LogoutAt RevokedReason )
        WITH VALUE #( FOR revoked_session IN sessions_to_revoke
          ( SessionID = revoked_session
            Status = 'R'
            LogoutAt = now
            RevokedReason = 'NEW_LOGIN' ) )
        FAILED DATA(failed_session_revoke)
        REPORTED DATA(reported_session_revoke).
      IF failed_session_revoke IS NOT INITIAL.
        failed = CORRESPONDING #( failed_session_revoke ).
        reported = CORRESPONDING #( reported_session_revoke ).
        success = abap_false.
      ENDIF.
    ENDIF.
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
      report_error( EXPORTING cid = cid
                              text = 'Tên đăng nhập và mật khẩu là bắt buộc'
                    CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    IF password_is_acceptable(
         password = CONV string( input-Password )
         username = normalized ) = abap_false.
      report_error(
        EXPORTING cid = cid
                  text = |Mật khẩu phải có ít nhất { c_min_password_length } ký tự|
                      && ' và không chứa tên đăng nhập'
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
    DATA(role_id) = CONV ztb_mob_role-role_id( input-RoleID ).
    IF role_id IS NOT INITIAL
       AND role_is_active( role_id ) = abap_false.
      report_error( EXPORTING cid = cid
                              text = 'Chức danh không tồn tại hoặc không còn hiệu lực'
                    CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    DATA(worker_id) = to_upper( condense( CONV string( input-WorkerID ) ) ).
    IF worker_id IS NOT INITIAL.
      DATA(worker_ref_id) = CONV zi_pp_workerref-workerid( worker_id ).
      IF CONV string( worker_ref_id ) <> worker_id.
        report_error( EXPORTING cid = cid text = 'Mã nhân công không đúng định dạng'
                      CHANGING failed = failed reported = reported ).
        RETURN.
      ENDIF.
      DATA(today) = cl_abap_context_info=>get_system_date( ).
      SELECT FROM zi_pp_workerref
        FIELDS WorkerUUID
        WHERE WorkerID = @worker_ref_id
          AND ValidFrom <= @today
          AND ValidTo >= @today
        INTO TABLE @DATA(active_workers)
        UP TO 1 ROWS.
      IF active_workers IS INITIAL.
        report_error( EXPORTING cid = cid
                                text = 'Nhân công không tồn tại hoặc không còn hiệu lực'
                      CHANGING failed = failed reported = reported ).
        RETURN.
      ENDIF.
      SELECT FROM ztb_mob_user
        FIELDS user_uuid
        WHERE worker_id = @worker_id
        INTO TABLE @DATA(worker_accounts)
        UP TO 1 ROWS.
      IF worker_accounts IS NOT INITIAL.
        report_error( EXPORTING cid = cid text = 'Nhân công đã được liên kết với tài khoản khác'
                      CHANGING failed = failed reported = reported ).
        RETURN.
      ENDIF.
    ENDIF.
    TRY.
        DATA(salt) = cl_system_uuid=>create_uuid_c36_static( ).
        DATA(password_hash) = hash_password(
          password = CONV string( input-Password )
          salt = CONV string( salt ) iterations = c_iterations ).
      CATCH cx_uuid_error cx_abap_message_digest zcx_mob_config.
        report_error( EXPORTING cid = cid text = 'Không thể xử lý mật khẩu'
                      CHANGING failed = failed reported = reported ).
        RETURN.
    ENDTRY.
    DATA(now) = utclong_current( ).
    DATA role_assignments TYPE TABLE FOR CREATE zi_mob_user\_Roles.
    IF role_id IS NOT INITIAL.
      role_assignments = VALUE #( ( %cid_ref = 'USR'
        %target = VALUE #( ( %cid = 'ROL' RoleID = role_id ) ) ) ).
    ENDIF.

    MODIFY ENTITIES OF zi_mob_user IN LOCAL MODE
      ENTITY MobileUser CREATE FIELDS
        ( Username NormalizedUsername FullName Email WorkerID
          Status FailedLoginCount PasswordChangeRequired )
      WITH VALUE #( ( %cid = 'USR' Username = input-Username
        NormalizedUsername = normalized FullName = input-FullName
        Email = input-Email WorkerID = worker_id
        Status = 'A' FailedLoginCount = 0
        PasswordChangeRequired = abap_true ) )
      ENTITY MobileUser CREATE BY \_Credential FIELDS
        ( PasswordHash PasswordSalt HashAlgorithm HashIterations
          PasswordChangedAt CredentialStatus )
      WITH VALUE #( ( %cid_ref = 'USR'
        %target = VALUE #( ( %cid = 'CRD' PasswordHash = password_hash
          PasswordSalt = salt HashAlgorithm = 'SHA256-ITER'
          HashIterations = c_iterations PasswordChangedAt = now
          CredentialStatus = 'A' ) ) ) )
      ENTITY MobileUser CREATE BY \_Roles FIELDS ( RoleID )
      WITH role_assignments
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
    "Với static action, result row chỉ có %cid và %param, không có %tky vì
    "không có bound instance. %param là cấu trúc entity thuần nên dùng
    "CORRESPONDING để loại các %-component khỏi kết quả READ.
    result = VALUE #( FOR user IN users
      ( %cid = cid %param = CORRESPONDING #( user ) ) ).
  ENDMETHOD.

  METHOD login.
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
    IF normalized IS INITIAL OR input-Password IS INITIAL OR input-DeviceID IS INITIAL.
      result = VALUE #( ( %cid = cid %param-Status = 'F' ) ).
      RETURN.
    ENDIF.
    "Chỉ trả về một cặp user/credential sử dụng được. Username sai, account
    "inactive/bị khóa hoặc credential thiếu/inactive đều đi qua cùng timing path
    "và nhận cùng public response để giảm rò rỉ thông tin.
    SELECT FROM ztb_mob_user AS user
      INNER JOIN ztb_mob_cred AS credential
        ON credential~user_uuid = user~user_uuid
      FIELDS user~user_uuid, user~failed_login_count, user~last_fail_at,
             user~password_change_required,
             credential~password_hash, credential~password_salt,
             credential~hash_iterations
      WHERE user~normalized_username = @normalized
        AND user~status = 'A'
        AND ( user~locked_until IS INITIAL OR user~locked_until <= @now )
        AND credential~credential_status = 'A'
      INTO TABLE @DATA(login_candidates)
      UP TO 2 ROWS.
    IF lines( login_candidates ) <> 1.
      TRY.
          consume_dummy_password_hash( CONV string( input-Password ) ).
        CATCH cx_abap_message_digest zcx_mob_config.
          report_error( EXPORTING cid = cid text = 'Không thể xử lý yêu cầu đăng nhập'
                        CHANGING failed = failed reported = reported ).
          RETURN.
      ENDTRY.
      result = VALUE #( ( %cid = cid %param-Status = 'F' ) ).
      RETURN.
    ENDIF.
    DATA(user) = login_candidates[ 1 ].
    DATA(credential) = login_candidates[ 1 ].
    TRY.
        DATA(input_hash) = hash_password(
          password = CONV string( input-Password )
          salt = CONV string( credential-password_salt )
          iterations = credential-hash_iterations ).
      CATCH cx_abap_message_digest zcx_mob_config.
        report_error( EXPORTING cid = cid text = 'Không thể xử lý yêu cầu đăng nhập'
                      CHANGING failed = failed reported = reported ).
        RETURN.
    ENDTRY.
    IF zcl_mob_hasher=>equals_constant_time(
         value_1 = CONV string( input_hash )
         value_2 = CONV string( credential-password_hash ) ) = abap_false.
      "Rule workflow đếm một đợt lỗi liên tiếp, không cộng dồn suốt vòng đời account:
      "sai 5 lần trong 1 phút thì khóa 10 phút; lỗi ngoài cửa sổ bắt đầu lại từ 1.
      DATA(failure_window_end) = COND utclong(
        WHEN user-last_fail_at IS INITIAL THEN VALUE utclong( )
        ELSE utclong_add(
          val = user-last_fail_at minutes = c_failure_window_minutes ) ).
      DATA(failed_count) = COND i(
        WHEN user-last_fail_at IS INITIAL OR now > failure_window_end THEN 1
        ELSE user-failed_login_count + 1 ).
      DATA(locked_until) = COND utclong(
        WHEN failed_count >= c_max_failed_logins
        THEN utclong_add( val = now minutes = c_lock_minutes )
        ELSE VALUE utclong( ) ).
      MODIFY ENTITIES OF zi_mob_user IN LOCAL MODE ENTITY MobileUser
        UPDATE FIELDS ( FailedLoginCount LastFailedLoginAt LockedUntil )
        WITH VALUE #( ( UserUUID = user-user_uuid
          FailedLoginCount = failed_count
          LastFailedLoginAt = now
          LockedUntil = locked_until ) )
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
    "Mỗi device chỉ giữ một active session và tổng session active của account có
    "giới hạn; nếu không, login lặp lại sẽ làm session table tăng vô hạn và để
    "lại quá nhiều bearer token còn hiệu lực.
    DATA(session_revoke_ok) = abap_true.
    revoke_login_sessions(
      EXPORTING user_uuid = user-user_uuid
                device_id = input-DeviceID
                now = now
      CHANGING success = session_revoke_ok
               failed = failed
               reported = reported ).
    IF session_revoke_ok = abap_false.
      RETURN.
    ENDIF.
    TRY.
        DATA(access_token) = cl_system_uuid=>create_uuid_c36_static( )
                          && cl_system_uuid=>create_uuid_c36_static( ).
        DATA(refresh_token) = cl_system_uuid=>create_uuid_c36_static( )
                           && cl_system_uuid=>create_uuid_c36_static( ).
        DATA(access_hash) = hash_token( CONV string( access_token ) ).
        DATA(refresh_hash) = hash_token( CONV string( refresh_token ) ).
      CATCH cx_uuid_error cx_abap_message_digest zcx_mob_config.
        report_error( EXPORTING cid = cid text = 'Không thể tạo phiên đăng nhập'
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
      UPDATE FIELDS ( FailedLoginCount LastFailedLoginAt LockedUntil LastLoginAt )
      WITH VALUE #( ( UserUUID = user-user_uuid FailedLoginCount = 0
        LastFailedLoginAt = VALUE utclong( )
        LockedUntil = VALUE utclong( ) LastLoginAt = now ) )
      FAILED DATA(failed_login_update)
      REPORTED DATA(reported_login_update).
    IF failed_login_update IS NOT INITIAL.
      "FAILED làm reject toàn bộ LUW nên session vừa tạo ở trên cũng bị loại cùng
      "update này; không cần một bước compensation riêng.
      failed = CORRESPONDING #( failed_login_update ).
      reported = CORRESPONDING #( reported_login_update ).
      RETURN.
    ENDIF.
    "Danh sách quyền được trả cho device để render menu mà không cần round trip
    "thứ hai. Đây chỉ là dữ liệu hiển thị; mọi protected operation đều kiểm tra
    "lại quyền server-side qua zcl_mob_token_validator và không đọc danh sách này.
    DATA(permissions) = zcl_mob_token_validator=>get_permissions(
      user-user_uuid ).
    DATA(work_contexts) = zcl_mob_token_validator=>get_work_contexts(
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
          AppModule = permission-app_module ) )
      _WorkContexts = VALUE #( FOR work_context IN work_contexts
        ( WorkID = work_context-work_id
          WorkName = work_context-work_name
          Plant = work_context-plant
          WorkCenter = work_context-workcenter
          BoPhan = work_context-bo_phan
          Location = work_context-location ) ) ) ) ).
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
      CATCH cx_abap_message_digest zcx_mob_config.
        report_error( EXPORTING cid = cid text = 'Không thể xử lý yêu cầu đăng xuất'
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
      CATCH cx_abap_message_digest zcx_mob_config.
        report_error( EXPORTING cid = cid text = 'Không thể xử lý refresh token'
                      CHANGING failed = failed reported = reported ).
        RETURN.
    ENDTRY.
    SELECT FROM ztb_mob_session AS session
      INNER JOIN ztb_mob_user AS user
        ON user~user_uuid = session~user_uuid
      FIELDS session~session_id, session~user_uuid, session~token_version,
             user~status AS user_status,
             user~password_change_required
      WHERE session~refresh_token_hash = @old_hash
        AND session~device_id = @input-DeviceID
        AND session~status = 'A'
        AND session~refresh_expires_at > @now
      INTO TABLE @DATA(refresh_sessions)
      UP TO 2 ROWS.
    IF lines( refresh_sessions ) <> 1.
      report_error( EXPORTING cid = cid text = 'Refresh token không hợp lệ hoặc hết hạn'
                    CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    DATA(session) = refresh_sessions[ 1 ].
    IF session-user_status <> 'A'.
      report_error( EXPORTING cid = cid text = 'Refresh token không hợp lệ hoặc hết hạn'
                    CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    TRY.
        DATA(access_token) = cl_system_uuid=>create_uuid_c36_static( )
                          && cl_system_uuid=>create_uuid_c36_static( ).
        DATA(refresh_token) = cl_system_uuid=>create_uuid_c36_static( )
                           && cl_system_uuid=>create_uuid_c36_static( ).
        DATA(access_hash) = hash_token( CONV string( access_token ) ).
        DATA(refresh_hash) = hash_token( CONV string( refresh_token ) ).
      CATCH cx_uuid_error cx_abap_message_digest zcx_mob_config.
        report_error( EXPORTING cid = cid text = 'Không thể làm mới phiên đăng nhập'
                      CHANGING failed = failed reported = reported ).
        RETURN.
    ENDTRY.
    DATA(expires_at) = utclong_add( val = now minutes = 30 ).
    MODIFY ENTITIES OF zi_mob_user IN LOCAL MODE ENTITY MobileSession
      UPDATE FIELDS ( AccessTokenHash RefreshTokenHash TokenVersion
        LastActivityAt ExpiresAt )
      WITH VALUE #( ( SessionID = session-session_id
        AccessTokenHash = access_hash RefreshTokenHash = refresh_hash
        TokenVersion = session-token_version + 1 LastActivityAt = now
        ExpiresAt = expires_at ) )
      FAILED DATA(failed_update) REPORTED DATA(reported_update).
    IF failed_update IS NOT INITIAL.
      failed = CORRESPONDING #( failed_update ).
      reported = CORRESPONDING #( reported_update ).
      RETURN.
    ENDIF.
    "Refresh token đồng thời refresh danh sách quyền để assignment mới được thay đổi
    "trong lúc session đang mở sẽ tới device ở lần rotation tiếp theo.
    DATA(permissions) = zcl_mob_token_validator=>get_permissions(
      session-user_uuid ).
    DATA(work_contexts) = zcl_mob_token_validator=>get_work_contexts(
      session-user_uuid ).
    result = VALUE #( ( %cid = cid %param = VALUE #(
      UserUUID = session-user_uuid
      SessionID = session-session_id
      AccessToken = access_token
      RefreshToken = refresh_token
      ExpiresAt = expires_at
      Status = COND #( WHEN session-password_change_required = abap_true
                       THEN 'P' ELSE 'A' )
      PasswordChangeRequired = session-password_change_required
      _Permissions = VALUE #( FOR permission IN permissions
        ( FuncID = permission-func_id
          FuncName = permission-func_name
          AppModule = permission-app_module ) )
      _WorkContexts = VALUE #( FOR work_context IN work_contexts
        ( WorkID = work_context-work_id
          WorkName = work_context-work_name
          Plant = work_context-plant
          WorkCenter = work_context-workcenter
          BoPhan = work_context-bo_phan
          Location = work_context-location ) ) ) ) ).
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
      CATCH cx_abap_message_digest zcx_mob_config.
        report_error( EXPORTING cid = cid text = 'Không thể xác thực phiên đăng nhập'
                      CHANGING failed = failed reported = reported ).
        RETURN.
    ENDTRY.
    IF auth-is_valid = abap_false.
      report_error( EXPORTING cid = cid text = |Token không hợp lệ: { auth-error_code }|
                    CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    SELECT FROM ztb_mob_cred AS credential
      INNER JOIN ztb_mob_user AS user
        ON user~user_uuid = credential~user_uuid
      FIELDS credential~password_hash, credential~password_salt,
             credential~hash_iterations, user~normalized_username
      WHERE credential~user_uuid = @auth-user_uuid
      INTO TABLE @DATA(password_credentials)
      UP TO 1 ROWS.
    IF password_credentials IS INITIAL.
      report_error( EXPORTING cid = cid text = 'Tên đăng nhập hoặc mật khẩu không hợp lệ'
                    CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
    DATA(credential) = password_credentials[ 1 ].
    IF input-NewPassword = input-CurrentPassword
       OR password_is_acceptable(
            password = CONV string( input-NewPassword )
            username = CONV string( credential-normalized_username ) ) = abap_false.
      report_error(
        EXPORTING cid = cid
                  text = |Mật khẩu mới phải khác mật khẩu cũ; tối thiểu { c_min_password_length } ký tự|
                      && ' và không chứa tên đăng nhập'
        CHANGING failed = failed reported = reported ).
      RETURN.
    ENDIF.
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
      CATCH cx_uuid_error cx_abap_message_digest zcx_mob_config.
        report_error( EXPORTING cid = cid text = 'Không thể cập nhật mật khẩu'
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

    "Mọi token hiện tại đều được phát hành dưới credential cũ. Revoke cả session
    "hiện tại để buộc đăng nhập sạch, đặc biệt quan trọng sau khi thay mật khẩu
    "tạm thời ở lần sử dụng đầu tiên.
    SELECT FROM ztb_mob_session
      FIELDS session_id
      WHERE user_uuid = @auth-user_uuid
        AND status = 'A'
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

  METHOD changepasswordadmin.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    "Không cho đổi mật khẩu nhiều tài khoản trong cùng một request
    IF lines( keys ) > 1.
      LOOP AT keys ASSIGNING FIELD-SYMBOL(<multiple_key>).
        APPEND VALUE #(
          %tky = <multiple_key>-%tky
        ) TO failed-mobileuser.

        APPEND VALUE #(
          %tky = <multiple_key>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'Mỗi yêu cầu chỉ được đổi mật khẩu một tài khoản'
          )
        ) TO reported-mobileuser.
      ENDLOOP.
      RETURN.
    ENDIF.

    ASSIGN keys[ 1 ] TO FIELD-SYMBOL(<admin_key>).

    DATA(new_password) =
      CONV string( <admin_key>-%param-NewPassword ).

    "Đọc tài khoản đang được chọn
    READ ENTITIES OF zi_mob_user IN LOCAL MODE
      ENTITY MobileUser
      FIELDS ( UserUUID Username NormalizedUsername )
      WITH VALUE #( ( %tky = <admin_key>-%tky ) )
      RESULT DATA(users)
      FAILED DATA(failed_user_read)
      REPORTED DATA(reported_user_read).

    IF failed_user_read IS NOT INITIAL OR users IS INITIAL.
      failed = CORRESPONDING #( failed_user_read ).
      reported = CORRESPONDING #( reported_user_read ).

      IF users IS INITIAL.
        APPEND VALUE #(
          %tky = <admin_key>-%tky
        ) TO failed-mobileuser.

        APPEND VALUE #(
          %tky = <admin_key>-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'Tài khoản không tồn tại'
          )
        ) TO reported-mobileuser.
      ENDIF.

      RETURN.
    ENDIF.

    DATA(user) = users[ 1 ].

    "Kiểm tra chính sách mật khẩu
    IF new_password IS INITIAL
       OR password_is_acceptable(
            password = new_password
            username = CONV string( user-NormalizedUsername )
          ) = abap_false.

      APPEND VALUE #(
        %tky = user-%tky
      ) TO failed-mobileuser.

      APPEND VALUE #(
        %tky = user-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text     =
            |Mật khẩu phải có ít nhất { c_min_password_length } ký tự và không chứa tên đăng nhập|
        )
      ) TO reported-mobileuser.

      RETURN.
    ENDIF.

    "Tài khoản phải có credential
    SELECT FROM ztb_mob_cred
      FIELDS user_uuid
      WHERE user_uuid = @user-UserUUID
      INTO TABLE @DATA(credentials)
      UP TO 1 ROWS.

    IF credentials IS INITIAL.
      APPEND VALUE #(
        %tky = user-%tky
      ) TO failed-mobileuser.

      APPEND VALUE #(
        %tky = user-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text     = 'Tài khoản chưa có thông tin xác thực'
        )
      ) TO reported-mobileuser.

      RETURN.
    ENDIF.

    "Sinh salt mới và hash mật khẩu
    TRY.
        DATA(new_salt) =
          cl_system_uuid=>create_uuid_c36_static( ).

        DATA(new_hash) = hash_password(
          password   = new_password
          salt       = CONV string( new_salt )
          iterations = c_iterations
        ).

      CATCH cx_uuid_error
            cx_abap_message_digest
            zcx_mob_config.

        APPEND VALUE #(
          %tky = user-%tky
        ) TO failed-mobileuser.

        APPEND VALUE #(
          %tky = user-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'Không thể xử lý mật khẩu mới'
          )
        ) TO reported-mobileuser.

        RETURN.
    ENDTRY.

    DATA(now) = utclong_current( ).

    "Cập nhật credential và bắt buộc user đổi mật khẩu sau khi đăng nhập
    MODIFY ENTITIES OF zi_mob_user IN LOCAL MODE
      ENTITY MobileCredential
        UPDATE FIELDS (
          PasswordHash
          PasswordSalt
          HashAlgorithm
          HashIterations
          PasswordChangedAt
          CredentialStatus
        )
        WITH VALUE #(
          (
            UserUUID          = user-UserUUID
            PasswordHash      = new_hash
            PasswordSalt      = new_salt
            HashAlgorithm     = 'SHA256-ITER'
            HashIterations    = c_iterations
            PasswordChangedAt = now
            CredentialStatus  = 'A'
          )
        )

      ENTITY MobileUser
        UPDATE FIELDS ( PasswordChangeRequired )
        WITH VALUE #(
          (
            %tky                   = user-%tky
            PasswordChangeRequired = abap_true
          )
        )

      FAILED DATA(failed_update)
      REPORTED DATA(reported_update).

    failed = CORRESPONDING #( failed_update ).
    reported = CORRESPONDING #( reported_update ).

    IF failed_update IS NOT INITIAL.
      RETURN.
    ENDIF.

    "Thu hồi tất cả session phát hành bằng mật khẩu cũ
    SELECT FROM ztb_mob_session
      FIELDS session_id
      WHERE user_uuid = @user-UserUUID
        AND status = 'A'
      INTO TABLE @DATA(active_sessions).

    IF active_sessions IS NOT INITIAL.
      MODIFY ENTITIES OF zi_mob_user IN LOCAL MODE
        ENTITY MobileSession
          UPDATE FIELDS (
            Status
            LogoutAt
            RevokedReason
          )
          WITH VALUE #(
            FOR session IN active_sessions
            (
              SessionID     = session-session_id
              Status        = 'R'
              LogoutAt      = now
              RevokedReason = 'ADMIN_PWD_RESET'
            )
          )
        FAILED DATA(failed_revoke)
        REPORTED DATA(reported_revoke).

      IF failed_revoke IS NOT INITIAL.
        failed = CORRESPONDING #( failed_revoke ).
        reported = CORRESPONDING #( reported_revoke ).
        RETURN.
      ENDIF.
    ENDIF.

    APPEND VALUE #(
      %tky = user-%tky
      %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-success
        text     = 'Đã đặt lại mật khẩu thành công'
      )
    ) TO reported-mobileuser.
  ENDMETHOD.

  METHOD unlockUser.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zi_mob_user IN LOCAL MODE
      ENTITY MobileUser
        FIELDS ( Status
                 FailedLoginCount
                 LastFailedLoginAt
                 LockedUntil )
        WITH CORRESPONDING #( keys )
      RESULT DATA(users)
      FAILED DATA(failed_read)
      REPORTED DATA(reported_read).

    failed   = CORRESPONDING #( failed_read ).
    reported = CORRESPONDING #( reported_read ).

    IF users IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zi_mob_user IN LOCAL MODE
      ENTITY MobileUser
        UPDATE FIELDS (
          FailedLoginCount
          LastFailedLoginAt
          LockedUntil )
        WITH VALUE #(
          FOR user IN users
          ( %tky               = user-%tky
            FailedLoginCount   = 0
            LastFailedLoginAt  = VALUE #( )
            LockedUntil        = VALUE #( ) ) )
      FAILED DATA(failed_update)
      REPORTED DATA(reported_update).

    APPEND LINES OF failed_update-mobileuser
      TO failed-mobileuser.

    APPEND LINES OF reported_update-mobileuser
      TO reported-mobileuser.

    IF failed_update-mobileuser IS NOT INITIAL.
      RETURN.
    ENDIF.

    "Đọc lại dữ liệu sau khi mở khóa để trả đầy đủ $self
    READ ENTITIES OF zi_mob_user IN LOCAL MODE
      ENTITY MobileUser
        ALL FIELDS
        WITH VALUE #(
          FOR user IN users
          ( %tky = user-%tky ) )
      RESULT DATA(unlocked_users)
      FAILED DATA(failed_result)
      REPORTED DATA(reported_result).

    APPEND LINES OF failed_result-mobileuser
      TO failed-mobileuser.

    APPEND LINES OF reported_result-mobileuser
      TO reported-mobileuser.

    result = VALUE #(
      FOR unlocked_user IN unlocked_users
      ( %tky   = unlocked_user-%tky
        %param = unlocked_user ) ).

    LOOP AT unlocked_users ASSIGNING FIELD-SYMBOL(<unlocked_user>).
      APPEND VALUE #(
        %tky = <unlocked_user>-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-success
          text     = 'Đã mở khóa tài khoản' ) )
        TO reported-mobileuser.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS lhc_mobileuserrole DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS validateRoleAssignment FOR VALIDATE ON SAVE
      IMPORTING keys FOR MobileUserRole~validateRoleAssignment.
ENDCLASS.

CLASS lhc_mobileuserrole IMPLEMENTATION.
  METHOD validateRoleAssignment.
    READ ENTITIES OF zi_mob_user IN LOCAL MODE
      ENTITY MobileUserRole
      FIELDS ( RoleID )
      WITH CORRESPONDING #( keys )
      RESULT DATA(assignments).

    LOOP AT assignments ASSIGNING FIELD-SYMBOL(<assignment>).
      SELECT FROM ztb_mob_role
        FIELDS role_id
        WHERE role_id = @<assignment>-RoleID
          AND status = 'A'
        INTO TABLE @DATA(active_roles)
        UP TO 1 ROWS.
      IF active_roles IS INITIAL.
        APPEND VALUE #( %tky = <assignment>-%tky ) TO failed-mobileuserrole.
        APPEND VALUE #(
          %tky = <assignment>-%tky
          %element-RoleID = if_abap_behv=>mk-on
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text = 'Chức danh không tồn tại hoặc không còn hiệu lực' ) )
          TO reported-mobileuserrole.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
