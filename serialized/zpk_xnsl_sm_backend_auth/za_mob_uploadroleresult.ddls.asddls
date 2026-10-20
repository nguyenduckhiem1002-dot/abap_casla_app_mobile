@EndUserText.label: 'Kết quả tải Excel chức danh'
define root abstract entity ZA_MOB_UploadRoleResult {
  @EndUserText.label: 'Số chức danh đã xử lý'
  RoleCount : abap.int4;
  @EndUserText.label: 'Số quyền chức năng mới'
  FunctionCount : abap.int4;
  @EndUserText.label: 'Số phạm vi Work ID mới'
  WorkCount : abap.int4;
}
