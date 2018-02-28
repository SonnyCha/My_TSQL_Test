if exists (select 1 from sys.objects where name = 'GetCashTotal')
begin 
  drop function GetCashTotal
end 
go
CREATE FUNCTION dbo.GetCashTotal
( 
  @transid char(8),
  @typeid  char(3)
)

/*
BW-2012.07.26:  modified - ticket CHG0030274 correct totals to credits - debits.
*/
returns money

as
begin
  declare @totalCRT money
  declare @totalDBT money

  select @totalCRT = 0.00
  select @totalDBT = 0.00

  select @totalCRT = isnull(sum(D.Amount),0.00)
    from CS_TRANSACTION_DETAIL D
   where D.Transaction_Id = @transid
     and @typeid  in ('TOT',D.Type_Id)
     and D.Debit_Credit_Flag  = 'C'
  
  select @totalDBT = isnull(sum(D.Amount),0.00)
    from CS_TRANSACTION_DETAIL D
   where D.Transaction_Id = @transid
     and @typeid  in ('TOT',D.Type_Id)
     and D.Debit_Credit_Flag  = 'D'
  
return @totalCRT - @totalDBT
end