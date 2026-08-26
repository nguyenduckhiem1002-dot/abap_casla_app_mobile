@AccessControl.authorizationCheck: #MANDATORY
@EndUserText.label: 'Quản trị chức danh'
@UI.headerInfo: {
  typeName: 'Chức danh',
  typeNamePlural: 'Chức danh',
  title: { value: 'RoleName' }
}
@UI.facet: [
  { id: 'General', type: #IDENTIFICATION_REFERENCE,
    label: 'Thông tin chức danh', position: 10 },
  { id: 'Functions', type: #LINEITEM_REFERENCE,
    label: 'Quyền chức năng', position: 20, targetElement: '_Functions' },
  { id: 'WorkAssignments', type: #LINEITEM_REFERENCE,
    label: 'Vị trí làm việc', position: 30, targetElement: '_WorkAssignments' }
]
define root view entity ZC_MOB_Role_Adm
  provider contract transactional_query
  as projection on ZI_MOB_Role
{
  @UI.lineItem: [{ position: 10 }]
  @UI.identification: [{ position: 10 }]
  key RoleID,
  @UI.lineItem: [{ position: 20 }]
  @UI.identification: [{ position: 20 }]
      RoleName,
  @UI.lineItem: [{ position: 30 }]
  @UI.identification: [{ position: 30 }]
      Status,
  @UI.lineItem: [{ position: 40 }]
      CreatedBy,
  @UI.lineItem: [{ position: 50 }]
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _Functions : redirected to composition child ZC_MOB_RolFunc_Adm,
      _WorkAssignments : redirected to composition child ZC_MOB_RolWork_Adm
}
