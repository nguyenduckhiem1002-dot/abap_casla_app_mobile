@EndUserText.label: 'Sơ đồ vị trí công nhân'
define root abstract entity ZA_PP_PosBoardResult
{
  WorkCenterCount : abap.int4;
  PositionCount   : abap.int4;
  _Positions      : composition [0..*] of ZA_PP_PosBoardItem;
}
