CLASS lhc_mobileuser DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR MobileUser RESULT result.
    METHODS createuser FOR MODIFY
      IMPORTING keys FOR ACTION MobileUser~createUser RESULT result.
    METHODS login FOR MODIFY
      IMPORTING keys FOR ACTION MobileUser~login RESULT result.
    METHODS logout FOR MODIFY
      IMPORTING keys FOR ACTION MobileUser~logout.
    METHODS refresh FOR MODIFY
      IMPORTING keys FOR ACTION MobileUser~refresh RESULT result.
    METHODS changepassword FOR MODIFY
      IMPORTING keys FOR ACTION MobileUser~changePassword.
ENDCLASS.

CLASS lhc_mobileuser IMPLEMENTATION.
  METHOD get_global_authorizations.
    result-%action-login = if_abap_behv=>auth-allowed.
    result-%action-refresh = if_abap_behv=>auth-allowed.
    result-%action-logout = if_abap_behv=>auth-allowed.
    result-%action-changePassword = if_abap_behv=>auth-allowed.
    result-%action-createUser = if_abap_behv=>auth-unauthorized.
    result-%create = if_abap_behv=>auth-unauthorized.
    result-%update = if_abap_behv=>auth-unauthorized.
    result-%delete = if_abap_behv=>auth-unauthorized.
  ENDMETHOD.

  METHOD createuser.
    APPEND VALUE #( %cid = keys[ 1 ]-%cid
      %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-error
        text = 'Chức năng tạo tài khoản chưa được cấu hình quyền quản trị' ) )
      TO reported-mobileuser.
  ENDMETHOD.

  METHOD login.
    APPEND VALUE #( %cid = keys[ 1 ]-%cid
      %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-error
        text = 'Dịch vụ token chưa được cấu hình secret an toàn' ) )
      TO reported-mobileuser.
  ENDMETHOD.

  METHOD logout.
    APPEND VALUE #( %cid = keys[ 1 ]-%cid
      %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-error
        text = 'Dịch vụ token chưa được cấu hình secret an toàn' ) )
      TO reported-mobileuser.
  ENDMETHOD.

  METHOD refresh.
    APPEND VALUE #( %cid = keys[ 1 ]-%cid
      %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-error
        text = 'Dịch vụ token chưa được cấu hình secret an toàn' ) )
      TO reported-mobileuser.
  ENDMETHOD.

  METHOD changepassword.
    APPEND VALUE #( %cid = keys[ 1 ]-%cid
      %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-error
        text = 'Dịch vụ token chưa được cấu hình secret an toàn' ) )
      TO reported-mobileuser.
  ENDMETHOD.
ENDCLASS.
