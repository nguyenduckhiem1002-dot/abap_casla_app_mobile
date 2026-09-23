@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Thông tin Work Center theo Công đoạn LSX'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_MFGORD_OPER_WC
  as select distinct from I_ManufacturingOrderOperation as Op
    left outer join I_ManufacturingOrder as MfgOrd
      on Op.ManufacturingOrder = MfgOrd.ManufacturingOrder
  association [1..1] to I_MfgOrderOperationWithStatus as _Status
    on Op.ManufacturingOrder = _Status.ManufacturingOrder
   and _Status.OperationIsDeleted <> 'X'
  association [1..1] to I_ManufacturingOrderOperation as _HeaderOp
    on Op.ManufacturingOrder = _HeaderOp.ManufacturingOrder
   and ( _HeaderOp.WorkCenterInternalID <> '00000000'
      or _HeaderOp.WorkCenterInternalID is not initial )
  association [0..1] to I_WorkCenter as _WorkCenter
    on $projection.WorkCenterInternalID = _WorkCenter.WorkCenterInternalID
  association [0..1] to I_WorkCenterText as _WorkCenterText
    on $projection.WorkCenterInternalID = _WorkCenterText.WorkCenterInternalID
   and _WorkCenterText.Language = $session.system_language
  association [0..1] to I_UnitOfMeasure as _OperationUnit
    on $projection.OperationUnit = _OperationUnit.UnitOfMeasure
  association [1..1] to I_ManufacturingOrder as _ManufacturingOrder
    on $projection.ManufacturingOrder = _ManufacturingOrder.ManufacturingOrder
  association [0..1] to I_Product as _Product
    on $projection.Product = _Product.Product
  association [0..1] to I_ProductText as _ProductText
    on $projection.Product = _ProductText.Product
   and _ProductText.Language = $session.system_language
  association [1..1] to I_ManufacturingOrderItem as _MfgOrderMainItem
    on $projection.ManufacturingOrder = _MfgOrderMainItem.ManufacturingOrder
   and _MfgOrderMainItem.ManufacturingOrderItem = '0001'
{
  key Op.ManufacturingOrder         as ManufacturingOrder,
  key Op.ManufacturingOrderSequence as ManufacturingOrderSequence,
  key Op.ManufacturingOrderOperation as MfgOrderOperation,

  key case
        when Op.WorkCenterInternalID = '00000000'
          or Op.WorkCenterInternalID is initial
        then _HeaderOp.WorkCenterInternalID
        else Op.WorkCenterInternalID
      end as WorkCenterInternalID,

  key _MfgOrderMainItem.SalesOrder     as SalesOrder,
  key _MfgOrderMainItem.SalesOrderItem as SalesOrderItem,

      Op.MfgOrderOperationText  as MfgOrderOperationText,

      @Semantics.quantity.unitOfMeasure: 'OperationUnit'
      Op.OpPlannedTotalQuantity as OpPlannedTotalQuantity,

      @ObjectModel.foreignKey.association: '_OperationUnit'
      Op.OperationUnit as OperationUnit,

      @ObjectModel.foreignKey.association: '_Product'
      @ObjectModel.text.association: '_ProductText'
      MfgOrd.Product as Product,

      _ProductText.ProductName as ProductName,

      Op.OperationStandardTextCode as OperationStandardTextCode,
      Op.OperationControlProfile   as OperationControlProfile,

      _Status,
      _HeaderOp,
      _WorkCenter,
      _WorkCenterText,
      _OperationUnit,
      _ManufacturingOrder,
      _Product,
      _ProductText,
      _MfgOrderMainItem
}
