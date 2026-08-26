@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Danh mục vị trí làm việc di động'
define root view entity ZI_MOB_Work
  as select from ztb_mob_work
{
  key work_id    as WorkID,
      work_name  as WorkName,
      plant      as Plant,
      workcenter as WorkCenter,
      bo_phan    as BoPhan,
      location   as Location,
      is_active  as IsActive
}
