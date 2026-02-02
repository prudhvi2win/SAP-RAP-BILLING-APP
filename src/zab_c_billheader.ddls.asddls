@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection View for Billing Header'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZAB_C_BillHeader
  provider contract transactional_query
  as projection on ZAB_I_Bill_Header
{
  key BillId,
      BillType,
      BillDate,
      CustomerId,
      @Semantics.amount.currencyCode: 'Currency'
      NetAmount,
      Currency,
      SalesOrg,
      Createdby,
      Createdat,
      Lastchangedby,
      Lastchangedat,
      Locallastchangedat
}
