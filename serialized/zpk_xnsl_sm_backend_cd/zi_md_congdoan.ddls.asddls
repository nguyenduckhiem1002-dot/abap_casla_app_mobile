@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Master công đoạn'
define root view entity ZI_MD_CongDoan
  as select from ztb_md_congdoan
  association [0..1] to ZI_MOB_Work as _Work
    on $projection.BoPhan = _Work.BoPhan
   and _Work.IsActive = 'A'
{
  key ma_congdoan           as MaCongDoan,
  key valid_from            as ValidFrom,
  key bo_phan               as BoPhan,
      ten_congdoan          as TenCongDoan,
      _Work.WorkName        as WorkName,
      _Work.Plant            as Plant,
      _Work.WorkCenter       as WorkCenter,
      dongia_xm             as DonGiaXM,
      dongia_gc             as DonGiaGC,
      valid_to              as ValidTo,
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      _Work
}
