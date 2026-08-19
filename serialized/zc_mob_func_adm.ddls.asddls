@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Quản trị chức năng'
@UI.headerInfo: {
  typeName: 'Chức năng',
  typeNamePlural: 'Chức năng',
  title: { value: 'FuncName' }
}
define root view entity ZC_MOB_Func_Adm
  provider contract transactional_query
  as projection on ZI_MOB_Func
{
  @UI.lineItem: [{ position: 10 }]
  @UI.identification: [{ position: 10 }]
  key FuncID,
  @UI.lineItem: [{ position: 20 }]
  @UI.identification: [{ position: 20 }]
      FuncName,
  @UI.lineItem: [{ position: 30 }]
  @UI.identification: [{ position: 30 }]
      Module
}
