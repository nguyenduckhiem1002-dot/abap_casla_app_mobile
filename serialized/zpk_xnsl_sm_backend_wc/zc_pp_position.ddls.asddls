@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'API vị trí làm việc cho mobile'
define root view entity ZC_PP_Position
  provider contract transactional_query
  as projection on ZR_PP_Position
{
  key WorkCenter,
  key PositionID,
  key MachineID,
      PositionName,
      Status,
      LastChangedAt,
      LocalLastChangedAt
}
