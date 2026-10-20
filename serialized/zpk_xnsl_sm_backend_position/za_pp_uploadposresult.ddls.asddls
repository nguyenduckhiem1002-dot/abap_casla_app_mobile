@EndUserText.label: 'Kết quả tải Excel vị trí làm việc'
define root abstract entity ZA_PP_UploadPosResult {
  @EndUserText.label: 'Số dòng vị trí đã xử lý'
  PositionCount : abap.int4;
  @EndUserText.label: 'Số dòng phân công đã xử lý'
  AssignmentCount : abap.int4;
}
