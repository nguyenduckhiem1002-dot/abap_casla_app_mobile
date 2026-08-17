@EndUserText.label: 'Tham số gửi đồng bộ di động'
define root abstract entity ZA_PP_SubmitSync
{
  ExternalID : abap.char(64);
  DeviceID : abap.char(64);
  _Items : composition [1..*] of ZA_PP_SubmitSyncItem;
}
