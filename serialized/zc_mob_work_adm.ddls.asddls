@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Quản trị vị trí làm việc'
@UI.headerInfo: {
  typeName: 'Vị trí làm việc',
  typeNamePlural: 'Vị trí làm việc',
  title: { value: 'WorkName' }
}
@UI.facet: [
  { id: 'General', type: #IDENTIFICATION_REFERENCE,
    label: 'Thông tin vị trí làm việc', position: 10 }
]
define root view entity ZC_MOB_Work_Adm
  provider contract transactional_query
  as projection on ZI_MOB_Work
{
  @UI.lineItem: [{ position: 10 }]
  @UI.identification: [{ position: 10 }]
  key WorkID,
  @UI.lineItem: [{ position: 20 }]
  @UI.identification: [{ position: 20 }]
      WorkName,
  @UI.lineItem: [{ position: 30 }]
  @UI.identification: [{ position: 30 }]
      Plant,
  @UI.lineItem: [{ position: 40 }]
  @UI.identification: [{ position: 40 }]
      WorkCenter,
  @UI.lineItem: [{ position: 50 }]
  @UI.identification: [{ position: 50 }]
      BoPhan,
  @UI.lineItem: [{ position: 60 }]
  @UI.identification: [{ position: 60 }]
      Location,
  @UI.lineItem: [{ position: 70 }]
  @UI.identification: [{ position: 70 }]
      IsActive
}
