
@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Quản trị chức năng'
@Metadata.allowExtensions: true
define root view entity ZC_MOB_Func_Adm
  provider contract transactional_query
  as projection on ZI_MOB_Func
{
  key FuncID,
      FuncName,
      AppModule,
      LastChangedAt,
      LocalLastChangedAt
}
