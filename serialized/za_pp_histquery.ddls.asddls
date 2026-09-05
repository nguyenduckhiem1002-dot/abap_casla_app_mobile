@EndUserText.label: 'Tham số tra cứu lịch sử giao/nhận việc'
define abstract entity ZA_PP_HistQuery {
  @EndUserText.label: 'Token truy cập'
  AccessToken : abap.char(128);
  @EndUserText.label: 'Mã thiết bị'
  DeviceID : abap.char(120);
  @EndUserText.label: 'Khoảng thời gian'
  RangeCode : abap.char(1);
  @EndUserText.label: 'Từ ngày'
  DateFrom : abap.dats;
  @EndUserText.label: 'Đến ngày'
  DateTo : abap.dats;
  @EndUserText.label: 'Mã nhân công'
  WorkerID : abap.char(8);
  SummaryOnly : abap_boolean;
}
