@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection View for Billing Item'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZAB_C_BILL_ITEM as projection on zab_i_bill_item
{
    key BillId,
    key ItemNo,
    MaterialId,
    Description,
    @Semantics.quantity.unitOfMeasure: 'Uom'
    Quantity,
    @Semantics.amount.currencyCode: 'Currency'
    ItemAmount,
    Currency,
    Uom,
    Createdby,
    Createdat,
    Lastchangedby,
    Lastchangedat,
    Locallastchangedat,
    /* Associations */
    _header: redirected to parent ZAB_C_BillHeader
}
