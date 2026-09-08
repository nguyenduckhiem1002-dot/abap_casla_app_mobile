
@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Quản trị vị trí làm việc'
@Metadata.allowExtensions: true
define root view entity ZC_MOB_Work_Adm
  provider contract transactional_query
  as projection on ZI_MOB_Work
{
key WorkID,
WorkName,
Plant,
WorkCenter,
BoPhan,
Location,
IsActive,
LastChangedAt,
LocalLastChangedAt
}
