@EndUserText.label: 'Tham số thu hồi phân bổ'
define abstract entity ZA_PP_Recall
{
  ProductionOrder         : abap.char(12);
  Operation               : abap.char(4);
  @EndUserText.label      : 'Vị trí làm việc'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MOB_Work_Hist_VH', element: 'WorkID' } }]
  WorkID                  : abap.char(30);
  WorkerID                : abap.char(8);
  //   @EndUserText.label: 'Vị trí hiện tại'
  //  PositionID : abap.char(10);
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  Quantity                : abap.quan(15,3);
  UnitOfMeasure           : abap.unit(3);
  @EndUserText.label      : 'Mã ca'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_Shift', element: 'ShiftID' } }]
  ShiftID                 : abap.char(10);
  ExecutionDate           : abap.dats;
  @EndUserText.label      : 'Thời điểm thực hiện thực tế UTC'
  ExecutedAt              : abap.utclong;
  @EndUserText.label      : 'Ngày hạch toán (ngày làm việc của ca)'
  PostingDate             : abap.dats;
  @EndUserText.label      : 'Ngày nhập (giờ địa phương)'
  EntryDate               : abap.dats;
  @EndUserText.label      : 'Giờ nhập (giờ địa phương)'
  EntryTime               : abap.tims;
  OriginalTransactionUUID : sysuuid_x16;
  AccessToken             : abap.char(128);
  DeviceID                : abap.char(120);
  WorkerPassword          : abap.char(255);
  SyncItemUUID            : sysuuid_x16;
}
