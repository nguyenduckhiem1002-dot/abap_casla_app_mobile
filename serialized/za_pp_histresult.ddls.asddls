@EndUserText.label: 'Kết quả tra cứu lịch sử giao/nhận việc'
define root abstract entity ZA_PP_HistResult {
  ScopeCode : abap.char(1);
  DateFrom : abap.dats;
  DateTo : abap.dats;
  WorkerCount : abap.int4;
  EntryCount : abap.int4;
  IsTruncated : abap_boolean;
  _Workers : composition [0..*] of ZA_PP_HistWorker;
  _Entries : composition [0..*] of ZA_PP_HistEntry;
}
