@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'API phạm vi nhân công di động'
define view entity ZC_MOB_UsrWrk
  as projection on ZI_MOB_UsrWrk
{
  key UserWorkerUUID,
      UserUUID,
      WorkerID,
      Plant,
      WorkCenter,
      ValidFrom,
      ValidTo,
      Status,
      _User : redirected to parent ZC_MOB_User
}
