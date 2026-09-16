@EndUserText.label: 'Tham số tra cứu lịch sử giao/nhận việc'
define abstract entity ZA_PP_HistQuery {
  AccessToken : abap.char(128);
  DeviceID : abap.char(120);
  RangeCode : abap.char(1);
  DateFrom : abap.dats;
  DateTo : abap.dats;
  WorkerID : abap.char(8);
  @EndUserText.label: 'Lệnh sản xuất'
  ProductionOrder : abap.char(12);
  @EndUserText.label: 'Công đoạn'
  Operation : abap.char(4);
  @EndUserText.label: 'Mã ca'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_Shift', element: 'ShiftID' } }]
  ShiftID : abap.char(10);
  SummaryOnly : abap_boolean;
}
