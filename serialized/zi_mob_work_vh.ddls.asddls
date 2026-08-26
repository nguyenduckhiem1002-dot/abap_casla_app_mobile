@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Trợ giúp chọn vị trí làm việc'
define view entity ZI_MOB_Work_VH
  as select from ztb_mob_work
{
  key work_id    as WorkID,
      work_name  as WorkName,
      plant      as Plant,
      workcenter as WorkCenter,
      bo_phan    as BoPhan,
      location   as Location
}
where is_active = 'A'
