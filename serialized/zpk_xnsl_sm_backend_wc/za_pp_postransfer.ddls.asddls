@EndUserText.label: 'Tham số điều chuyển công nhân vào vị trí'
define abstract entity ZA_PP_PosTransfer
{
  @EndUserText.label: 'Mã công nhân'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_Worker_VH', element: 'WorkerID' } }]
  WorkerID   : abap.char(8);
  @EndUserText.label: 'Lý do điều chuyển'
  ReasonText : abap.char(120);
}
