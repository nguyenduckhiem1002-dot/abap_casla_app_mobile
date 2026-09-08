@EndUserText.label: 'Tham số tra cứu lịch sử giao/nhận việc'
define abstract entity ZA_PP_HistQuery {
  AccessToken : abap.char(128);
  DeviceID : abap.char(120);
  RangeCode : abap.char(1);
  DateFrom : abap.dats;
  DateTo : abap.dats;
  WorkerID : abap.char(8);
  SummaryOnly : abap_boolean;
}
