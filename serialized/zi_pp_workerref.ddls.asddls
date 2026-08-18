@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Tham chiếu nhân công để kiểm tra'
define view entity ZI_PP_WorkerRef
  as select from ztb_kb_nhancong
{
  key uuid_nhancong as WorkerUUID,
      worker_id     as WorkerID,
      from_date     as ValidFrom,
      case when to_date = dats'00000000'
           then dats'99991231'
           else to_date
      end           as ValidTo,
      work_center   as WorkCenter,
      plant         as Plant,
      worker_name   as WorkerName
}
