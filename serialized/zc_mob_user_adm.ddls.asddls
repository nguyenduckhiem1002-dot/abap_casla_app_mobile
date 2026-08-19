@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Quản trị tài khoản giám sát'
@UI.headerInfo: {
  typeName: 'Tài khoản giám sát',
  typeNamePlural: 'Tài khoản giám sát',
  title: { value: 'Username' }
}
define root view entity ZC_MOB_User_Adm
  provider contract transactional_query
  as projection on ZI_MOB_User
{
  @UI.lineItem: [
    { position: 10 },
    { position: 90, type: #FOR_ACTION,
      dataAction: 'createUser', label: 'Tạo tài khoản' }
  ]
  key UserUUID,
  @UI.lineItem: [{ position: 20 }]
  @UI.identification: [{ position: 10 }]
      Username,
  @UI.lineItem: [{ position: 30 }]
      FullName,
  @UI.lineItem: [{ position: 40 }]
      Email,
  @UI.lineItem: [{ position: 42 }]
      WorkerID,
  @UI.lineItem: [{ position: 44 }]
      Plant,
  @UI.lineItem: [{ position: 46 }]
      BoPhan,
  @UI.lineItem: [{ position: 50 }]
      Status,
  @UI.lineItem: [{ position: 60 }]
      PasswordChangeRequired,
  @UI.lineItem: [{ position: 70 }]
      LastLoginAt,
  @UI.lineItem: [{ position: 80 }]
      CreatedAt,
      /* Composition */
      _Roles : redirected to composition child ZC_MOB_UsrRol_Adm
}
