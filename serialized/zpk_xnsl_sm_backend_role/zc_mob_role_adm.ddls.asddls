@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Quản trị chức danh'
@Metadata.allowExtensions: true
define root view entity ZC_MOB_Role_Adm
  provider contract transactional_query
  as projection on ZI_MOB_Role
{
  @EndUserText.label: 'Mã chức danh'
  @ObjectModel.text.element: ['RoleName']
  key RoleID,
  @EndUserText.label: 'Tên chức danh'
      RoleName,
  @EndUserText.label: 'Trạng thái'
      Status,
  @EndUserText.label: 'Người tạo'
      CreatedBy,
  @EndUserText.label: 'Thời điểm tạo'
      CreatedAt,
  @EndUserText.label: 'Người thay đổi cuối cùng'
      LastChangedBy,
  @EndUserText.label: 'Thời điểm thay đổi cuối cùng'
      LastChangedAt,
  @EndUserText.label: 'Thời điểm thay đổi cục bộ cuối cùng'
      LocalLastChangedAt,
      _Functions : redirected to composition child ZC_MOB_RolFunc_Adm,
      _WorkAssignments : redirected to composition child ZC_MOB_RolWork_Adm
}
