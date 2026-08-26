@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Quản trị tài khoản giám sát'
@UI.headerInfo: {
  typeName: 'Tài khoản giám sát',
  typeNamePlural: 'Tài khoản giám sát',
  title: { value: 'Username' }
}
@UI.facet: [
  { id: 'General', type: #IDENTIFICATION_REFERENCE,
    label: 'Thông tin tài khoản', position: 10 },
  { id: 'Roles', type: #LINEITEM_REFERENCE,
    label: 'Chức danh', position: 20, targetElement: '_Roles' }
]
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
  @UI.identification: [{ position: 20 }]
      FullName,
  @UI.lineItem: [{ position: 40 }]
  @UI.identification: [{ position: 30 }]
      Email,
  @UI.lineItem: [{ position: 45 }]
  @UI.identification: [{ position: 40 }]
      WorkerID,
  @UI.lineItem: [{ position: 50 }]
  @UI.identification: [{ position: 50 }]
      Status,
  @UI.lineItem: [{ position: 60 }]
      PasswordChangeRequired,
  @UI.lineItem: [{ position: 70 }]
      LastLoginAt,
  @UI.lineItem: [{ position: 80 }]
      CreatedAt,
      _Roles : redirected to composition child ZC_MOB_UsrRol_Adm
}
