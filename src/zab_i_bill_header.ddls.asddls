@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ROOT ENTITY FOR BILLING HEADER'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZAB_I_Bill_Header
  as select from zab_bill_header
  //composition of target_data_source_name as _association_name
{
  key bill_id            as BillId,
      bill_type          as BillType,
      bill_date          as BillDate,
      customer_id        as CustomerId,
      @Semantics.amount.currencyCode : 'Currency'
      net_amount         as NetAmount,
      currency           as Currency,
      sales_org          as SalesOrg,
      @Semantics.user.createdBy: true
      createdby          as Createdby,
      @Semantics.systemDateTime.createdAt: true
      createdat          as Createdat,
      @Semantics.user.lastChangedBy: true
      lastchangedby      as Lastchangedby,
      @Semantics.systemDateTime.lastChangedAt: true
      lastchangedat      as Lastchangedat,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      locallastchangedat as Locallastchangedat
      //_association_name // Make association public
}
