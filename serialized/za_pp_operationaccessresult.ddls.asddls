@EndUserText.label: 'Kết quả kiểm tra quyền và sản lượng công đoạn'
define abstract entity ZA_PP_OperationAccessResult
{
  IsAllowed : abap_boolean;
  ErrorCode : abap.char(40);
  Message : abap.char(255);

  @EndUserText.label: 'Lệnh sản xuất'
  ProductionOrder : abap.char(12);
  @EndUserText.label: 'Công đoạn'
  Operation : abap.char(4);
  @EndUserText.label: 'Mã công đoạn'
  MaCongDoan : abap.char(7);
  @EndUserText.label: 'Nhà máy'
  Plant : abap.char(4);
  @EndUserText.label: 'Trung tâm làm việc'
  WorkCenter : abap.char(8);
  @EndUserText.label: 'Vị trí làm việc'
  WorkID : abap.char(30);
  @EndUserText.label: 'Tên vị trí làm việc'
  WorkName : abap.char(100);
  @EndUserText.label: 'Bộ phận vị trí làm việc'
  WorkBoPhan : abap.char(60);
  @EndUserText.label: 'Địa điểm vị trí làm việc'
  Location : abap.char(100);
  @EndUserText.label: 'Tên công đoạn'
  OperationName : abap.char(100);
  @EndUserText.label: 'Bộ phận công đoạn'
  OperationBoPhan : abap.char(50);

  @EndUserText.label: 'Sản lượng công đoạn'
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  OperationQuantity : abap.quan(15,3);
  @EndUserText.label: 'Giao ban đầu'
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  InitialAssignedQuantity : abap.quan(15,3);
  @EndUserText.label: 'Chuyển vào'
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  TransferredInQuantity : abap.quan(15,3);
  @EndUserText.label: 'Chuyển ra'
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  TransferredOutQuantity : abap.quan(15,3);
  @EndUserText.label: 'Thu hồi'
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  RecalledQuantity : abap.quan(15,3);
  @EndUserText.label: 'Đã xác nhận'
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  CompletedQuantity : abap.quan(15,3);
  @EndUserText.label: 'Còn phải hoàn thành'
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  RemainingQuantity : abap.quan(15,3);
  @EndUserText.label: 'Đã giao hiện tại'
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  CurrentAssignedQuantity : abap.quan(15,3);
  @EndUserText.label: 'Chưa giao'
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  UnassignedQuantity : abap.quan(15,3);
  @EndUserText.label: 'Đơn vị tính'
  UnitOfMeasure : abap.unit(3);

  @EndUserText.label: 'Mã ca'
  ShiftID : abap.char(10);
  @EndUserText.label: 'Ngày làm việc'
  WorkDate : abap.dats;
  @EndUserText.label: 'Thời điểm quét UTC'
  ExecutedAt : abap.utclong;
}
