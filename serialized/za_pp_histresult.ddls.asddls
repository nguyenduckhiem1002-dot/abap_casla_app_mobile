@EndUserText.label: 'Kết quả tra cứu lịch sử giao/nhận việc'
define root abstract entity ZA_PP_HistResult {
  @EndUserText.label: 'Phạm vi xem'
  ScopeCode : abap.char(1);
  @EndUserText.label: 'Từ ngày'
  DateFrom : abap.dats;
  @EndUserText.label: 'Đến ngày'
  DateTo : abap.dats;
  @EndUserText.label: 'Số nhân công'
  WorkerCount : abap.int4;
  @EndUserText.label: 'Số giao dịch'
  EntryCount : abap.int4;
  IsTruncated : abap_boolean;
  _Workers : composition [0..*] of ZA_PP_HistWorker;
  _Entries : composition [0..*] of ZA_PP_HistEntry;
}
