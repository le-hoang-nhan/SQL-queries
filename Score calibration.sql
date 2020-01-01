set datefirst 1;
declare @end as datetime = '20191217 23:59:59'																									
																									
select																								
	i.InvoiceNumberFull, i.Id		'InvoiceId', --i.FactoryBankId,																						
	a.Name							'DistributorName',																	
	g.Description					'DistributorGroup',																			
	--o.CustomerId					'CustomerId',																			
    cast(o.ApprovalDate as date) ApprovalDate ,																									
	cast(i.InvoiceDate as date)			'InvoiceDate',	
	datepart(week, InvoiceDate) as Week, 	
	datepart(month, InvoiceDate) as month,
	datepart(year, InvoiceDate) as year,																			
	concat(year(i.InvoiceDate)%100 , FORMAT(i.InvoiceDate,'MM')) InvPeriods,																								
	concat(year(o.ApprovalDate )%100 , FORMAT(o.ApprovalDate ,'MM')) ADPeriods,																								
	coalesce(r.MaxReminder,0)		'ReminderLevel',																						
	e.Code							'WHG',																	
	coalesce(i.OrderTotal,0)					'OriginalAmount',																			
	case when cast(i.OrderTotal-coalesce(c.Amount,0) as money) < 0 then 0 else cast(i.OrderTotal-coalesce(c.Amount,0) as money)  end as  'Inv_netCN',																								
	case when cast(i.OrderTotal-coalesce(p.Amount,0)-coalesce(c.Amount,0) + coalesce(r.Amount,0)  as money) <0 then 0 else																								
		 cast(i.OrderTotal-coalesce(p.Amount,0)-coalesce(c.Amount,0) +coalesce(r.Amount,0)  as money) end as'OpenAmount',																							
	coalesce(r2.ReminderAmount,0)	'RemindersAmount',
	--coalesce(r.Amount,0)		 'r.Reminder' ,																					
	i.TermOfPaymentDays				'termsodpaymentsD',																				
	coalesce(p.Amount,0)			'PaymentsAmount',																					
	c.Amount			'CreditsAmount',																					
	case when coalesce(Inkasso,0) = 0 then 'NO' else 'YES' end 'FlagInkasso',																								
	cast(r.InkassoDate as date) 	'InkassoTimestamp',			
	concat(year(r.InkassoDate )%100 , FORMAT(r.InkassoDate ,'MM')) InkPeriods,																				
																									
	case when r.InkassoDate is null or  cast(i.OrderTotal-coalesce(p.Amount,0)-coalesce(c.Amount,0) +coalesce(r.Amount,0)  as money) < 0 																								
		then 0 else cast(i.OrderTotal-coalesce(p.Amount,0)-coalesce(c.Amount,0)+coalesce(r.Amount,0) as money) end as  'InkassoDueAmount',																							
																									
	case when r.InkassoDate is null or  cast(i.OrderTotal-coalesce(p.Amount,0)+coalesce(pa.PaidInk,0)-coalesce(c.Amount,0) + coalesce(r2.ReminderAmount,0)	 as money) < 0 																								
		then 0 else cast(i.OrderTotal-coalesce(p.Amount,0)+coalesce(pa.PaidInk,0)-coalesce(c.Amount,0) + coalesce(r2.ReminderAmount,0)	as money) end as 'InkassoHandover'	,	
	coalesce(pa.PaidInk,0) PaidAfterInkasso, 						
																											
	y.EnglishName		'PaymentMethods', 	
	coalesce(l.MaxInstallment,0)	'InstallmentsCount',															
	n.ScoreValue		'ScoreValue',																						
	case when n.ScoreValue < '450' then '< 450' when n.ScoreValue between  '450' and '475' then '450-475' when n.ScoreValue between  '475' and '500' then '475-500'																								
	when n.ScoreValue between  '500' and '525' then '500-525' when n.ScoreValue between  '525' and '550' then '525-550' when n.ScoreValue between  '550' and '575' then '550-575'																								
	when n.ScoreValue between  '575' and '600' then '575-600' when n.ScoreValue between  '600' and '625' then '600-625' when n.ScoreValue between '625' and '650' then '625-650' 																								
	when n.ScoreValue > '650' then '> 650' else 'NA' end as  ScoreGroup,																								
	v.Percentage	'RatingPercentage' 	, 
	--cast(n.Birthday as date)		'Birthday', 	
	w.Name	'Country'	,															
	case when n.Birthday is not null then  DATEDIFF(yy, n.BIRTHDAY,  @end) else 0 end as Age		,																						
	--u.City							'City', 	u.Zip							'ZIP' , b.Name		'CustomerName'
	i.FactoryBankId, 
	case when r.InkassoDate is null  then 'not in Inkasso' when DATEDIFF(dd, r.InkassoDate, @end) >= 18*30 then 'More 18 months' else 'Less 18 months' end as InkassoStatus, 
	cast(i.InvoiceDate + coalesce(l.MaxInstallment,0)*30 + 90 as date) 'Ageing' , 
	case when r.InkassoDate is null then 'open Invoice' else 'collection invoice' end as 'Collection' ,
	case when r.InkassoDate is null and i.InvoiceDate + coalesce(l.MaxInstallment,0)*30 + 90 < @end and i.OrderTotal-coalesce(p.Amount,0)-coalesce(c.Amount,0) > 5 then 1 else 0 end as Overaged 
 																																																
/* + Invoices				*/ from Invoices i																						
																									
/* + Customer				*/ join CustomerOrders o on o.id = i.CustomerOrderId 																									
/* + Currencies				*/ left join  Currencies e on 
e.Id = o.CurrencyId  																									
/* + Payment Options		*/ left join PaymentOptions y on y.Id = o.PaymentOptionId 																									
																									
/* + Payments				*/ left join (select InvoiceId, sum(Amount) Amount, sum(PaymentFee) CashBackFee from Payments where PaymentType = 0 and PaymentDate <= @end group by InvoiceId) p on p.InvoiceId = i.Id																								
/* + Payments after Debt	*/ left join ( select i.id, sum(p.Amount) as PaidInk from Invoices i join Payments p on p.InvoiceId = i.Id 	join Reminders r on r.InvoiceId = i.Id																								
				where  p.PaymentDate between r.ExportedTimeStamp and @end and PaymentType = 0 and r.ExportedTimeStamp is not null	group by i.Id) pa on pa.Id = i.Id																				
																									
/* + Credit Note			*/ left join (select InvoiceId, sum(Amount) Amount from Payments where PaymentType = 1 and PaymentDate <= @end group by InvoiceId) c on c.InvoiceId = i.Id																									
																									
/* + Reminder1				*/ left join (select InvoiceId, max(Id) ReminderId, sum(case when AgreementAmount is null then ReminderFee else AgreementAmount end) Amount, sum(ReminderFee) ReminderAmount, 																									
					sum(AgreementAmount) AgreementAmount, max(ReminderCount) MaxReminder, max(ExportedTimeStamp) InkassoDate, max(cast(Exported as varchar)) Inkasso 																				
					from Reminders group by InvoiceId) r on r.InvoiceId = i.Id		
																							
/* + Reminder2				*/ left join (select InvoiceId, max(Id) ReminderId, sum(ReminderFee) ReminderAmount from Reminders where timestamp < @end group by InvoiceId) r2 on r2.InvoiceId = i.Id 					 															
																									
/* + Reminder3				*/ left join (select ReminderId, max(TimeStamp) AgreementDate from ReminderAgreementHistories 	where TimeStamp < @end group by ReminderId) h on h.ReminderId = r.ReminderId																				
																									
/* + Installment			*/ left join (select InvoiceId, max(InstallmentNumber) MaxInstallment from Installments group by InvoiceId) l on l.InvoiceId = i.Id																									
/* + Partners1				*/ left join Partners a on a.Id = o.DistributorId																									
/* + Partners2				*/ left join Partners b on b.Id = o.CustomerId 																									
/* + Distributor			*/ left join Partners_Distributor d on d.Id = a.Id 																									
/* + DistributorGroups		*/ left join DistributorGroups g on d.DistributorGroupId = g.Id 																									
/* + Addresses				*/ left join (select PartnerId, Street, City, Zip, CountryId from Addresses where AddressTypeId = 1) u on u.PartnerId = b.Id 																									
/* + Countries				*/ left join Countries w on w.Id = u.CountryId																									
/* + ClientScores			*/ left join ClientScores n on n.ClientScoreId = o.ClientScoreId 																									
/* + RiskConversionRates	*/ left join RiskConversionRates v on v.RiskFinalValue = n.ScoreValue	
/* + PaymentOptions			*/ left join PaymentOptions po on po.Id = o.PaymentOptionId																								
																									
 
where a.Id = /*ID for merchant*/ and  (i.InvoiceDate > '20160101 00:00:00' and i.InvoiceDate < @end ) 
and po.id in ('5', '12', '13', '14', '16', '17', '19') -- Id for payment methods																		
order by i.TimeStamp desc
