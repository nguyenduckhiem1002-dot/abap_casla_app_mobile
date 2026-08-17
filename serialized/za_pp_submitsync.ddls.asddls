@EndUserText.label: 'Tham số gửi đồng bộ di động'
define root abstract entity ZA_PP_SubmitSync
{
  ExternalID : abap.char(64);
  DeviceID : abap.char(64);
  association [1..*] to ZA_PP_SubmitSyncItem as _Items;
}
