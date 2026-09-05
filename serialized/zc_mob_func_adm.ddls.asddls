
@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Quản trị chức năng'
@Metadata.allowExtensions: true
define root view entity ZC_MOB_Func_Adm
  provider contract transactional_query
  as projection on ZI_MOB_Func
{
  @EndUserText.label: 'Mã chức năng'
      key FuncID,
  @EndUserText.label: 'Tên chức năng'
      FuncName,
  @EndUserText.label: 'Phân hệ ứng dụng'
      AppModule,
  @EndUserText.label: 'Thời điểm thay đổi cuối'
      LastChangedAt,
  @EndUserText.label: 'Thời điểm cập nhật bản ghi'
      LocalLastChangedAt
}
