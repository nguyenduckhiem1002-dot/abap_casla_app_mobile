@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'API phân công vị trí cho mobile'
define root view entity ZC_PP_PosAssign
  provider contract transactional_query
  as projection on ZR_PP_PosAssign
{
  key WorkCenter,
  key PositionID,
  key WorkerID,
      Status,
      LastChangedAt,
      LocalLastChangedAt
}
