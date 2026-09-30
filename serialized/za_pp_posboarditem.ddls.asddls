@EndUserText.label: 'Vị trí trên sơ đồ công nhân'
define abstract entity ZA_PP_PosBoardItem
{
  _Result      : association to parent ZA_PP_PosBoardResult;
  WorkCenter   : abap.char(8);
  PositionID   : abap.char(10);
  MachineID    : abap.char(10);
  PositionName : abap.char(60);
  // Trống nếu vị trí chưa có người ngồi.
  WorkerID     : abap.char(8);
  WorkerName   : abap.char(80);
  IsOccupied   : abap_boolean;
}
