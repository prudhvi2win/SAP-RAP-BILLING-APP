@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface view for Billing Doc Item'
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity zab_i_bill_item
  as select from zab_bill_item
  association to parent ZAB_I_Bill_Header as _header on $projection.BillId = _header.BillId
{
  key zab_bill_item.bill_id            as BillId,
  key zab_bill_item.item_no            as ItemNo,
      zab_bill_item.material_id        as MaterialId,
      zab_bill_item.description        as Description,
      zab_bill_item.quantity           as Quantity,
      zab_bill_item.item_amount        as ItemAmount,
      zab_bill_item.currency           as Currency,
      zab_bill_item.uom                as Uom,
      @Semantics.user.createdBy: true
      zab_bill_item.createdby          as Createdby,
      @Semantics.systemDateTime.createdAt: true
      zab_bill_item.createdat          as Createdat,
      @Semantics.user.lastChangedBy: true
      zab_bill_item.lastchangedby      as Lastchangedby,
      @Semantics.systemDateTime.lastChangedAt: true
      zab_bill_item.lastchangedat      as Lastchangedat,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      zab_bill_item.locallastchangedat as Locallastchangedat,

      _header
}
