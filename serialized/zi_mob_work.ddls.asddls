
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Vị trí làm việc ứng dụng di động'
define root view entity ZI_MOB_Work
  as select from ztb_mob_work
{
  key work_id    as WorkID,
      @Semantics.text: true
      work_name  as WorkName,
      plant      as Plant,
      workcenter as WorkCenter,
      bo_phan    as BoPhan,
      location   as Location,
      is_active  as IsActive,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt
}
