if exists (select 1 from sys.objects where name = 'BTSaveBudget')
begin 
  drop procedure BTSaveBudget
end 
go
create proc dbo.BTSaveBudget /**************************************************************
BTSaveBudget

Purpose:    

Called by:   
Calls:          

Parameters:  

Syntax:      

Tables used:    
 
Views   used:   

Tables updated:

Results:

Revision History    :
JB-2011.09.16   : written
LN-2012.07.16   : CHG0030141-do not create zero dollar budgets in future years when ICR and Admin Fee are calculated
LN-2012.10.16   : CHG0031697
JB-2013.04.09   : CHG0033447
LN-2013.05.07   : CHG0033688 
JB-2014.02.05   : CHG0042333 - fix handling of transaction owner
LN-2015.04.06   : CHG0043259 - FY16 amount missing in batch BUDT220490 sent to ARC on 3/31/15
LN-2016.05.25   : CHG0047271 - MS SQL server implementation
***************************************************************#*/
@userid    char(4),
@transid   char(8),
@chartid1  char(7),
@chartid2  char(7),
@typeid    char(3),
@periodid  char(7),
@deltaStr  varchar(20)

as

declare @delta       money
declare @posted      char(3)
declare @statusid    char(3)
declare @errno       int
declare @errmsg      varchar(255)
declare @stmt        varchar(255)
declare @budgetid    char(8)
declare @typeid0     char(3) -- original typeid 051 or 052
declare @typeidtrans char(3)
declare @msg         varchar(300)
declare @owner       char(1)

select @posted      = '###'--dbo.GetConfigValue('002')
select @errno       = 0
select @errmsg      = ''
select @typeid0     = @typeid

select @typeidtrans = T.Type_Id,
       @owner       = isnull(A.Attribute_Value,'T')
  from FS_TRANSACTION T left join FS_TRANSACTION_ATTRIBUTE A on T.Transaction_Id+'OWNER' = A.Transaction_Id+A.Attribute
 where T.Transaction_Id = @transid

if @typeid is null select @typeid = '###'

-- 999 is used to denote a current estimate which is the sum of 051 and 052, so translating to 052 adjustment
if @typeid = '999' 
begin
  select @typeid = '052'
end

if @errno > 0                   goto endproc 
if lower(@deltaStr) = 'null'    goto endproc 		--all statements are needed
if dbo.isempty(@deltaStr) = 'Y' goto endproc
if @typeid = '###'	     goto endproc

---------------------------------------------------------------------------
-- validation section
---------------------------------------------------------------------------
if @typeid not in ('051','052')
begin
  select @msg = ''
  select @msg = @msg + 'BTSaveBudget: attempting to save record with typeid='+@typeid+char(13)
  select @msg = @msg + '@userid='+@userid+char(13)
  select @msg = @msg + '@transid='+@transid+char(13)  
  select @msg = @msg + '@periodid='+@periodid+char(13)       
  select @msg = @msg + '@deltaStr='+@deltaStr+char(13)              
  select @msg = @msg + 'Time='+convert(varchar(20),getdate())            

  execute FINSendEMail 'BTSaveBudget error','jb1223@columbia.edu,bw8@columbia.edu,in21@columbia.edu','',@msg

  goto endproc
end

select @delta    = convert(money,@deltaStr)

if @typeidtrans = '102' and @owner = 'O' and @chartid2 != '#######' --dbo.getTransactionOwner(@transid) = 'O'
begin
   select @delta = -@delta
   select @deltaStr = convert(varchar(20),@delta)
end

select @statusid = Status_Id 
  from FS_TRANSACTION
 where Transaction_Id = @transid

---------------------------------------------------------------------------
-- validate transaction status and raise an error if saving is done outside of NEW, OPEN or REJECT state
---------------------------------------------------------------------------
if @statusid not in ('100','101','103')
begin
  select @errno  = 51004, 
         @errmsg = 'Invalid save status for transaction: ' + @transid
  goto endproc
end

---------------------------------------------------------------------------
-- validate chartid
---------------------------------------------------------------------------
if @chartid1 = '#######'
begin
  select @msg = ''
  select @msg = @msg + 'BTSaveBudget: attempting to save record with chartidid=#######'+char(13)
  select @msg = @msg + '@userid='+@userid+char(13)
  select @msg = @msg + '@transid='+@transid+char(13)  
  select @msg = @msg + '@periodid='+@periodid+char(13)       
  select @msg = @msg + '@deltaStr='+@deltaStr+char(13)              
  select @msg = @msg + 'Time='+convert(varchar(20),getdate())            

  execute FINSendEMail 'BTSaveBudget error','jb1223@columbia.edu,bw8@columbia.edu,in21@columbia.edu','',@msg

  goto endproc
end


--------------------------------------------------------------
-- check for existing budget to update
--------------------------------------------------------------
select @budgetid = '########'

select @budgetid = B.Budget_Id
  from FS_BUDGET      B,
       FS_TRANSACTION T,
       _STATUS        S
 where B.Transaction_Id = @transid
   and B.Transaction_Id = T.Transaction_Id
   and B.Chart_Id       = @chartid1
   and B.Type_Id        = @typeid
   and B.Period_Id      = @periodid
   and T.Status_Id      = S.Status_Id
   and S.Current_Flag   = 'Y'       

if @budgetid = '########'
begin
  exec FSGetNextIdentifier 'FS_BUDGET',8,@budgetid output,'A'

  insert into FS_BUDGET
  (
    Budget_Id, 
    Chart_Id, 
    Type_Id, 
    Transaction_Id, 
    Period_Id, 
    User_Id,
    Amount, 
    Last_Updated
  ) 
  select @budgetid,@chartid1,@typeid,@transid,@periodid,@userid,@delta,getdate()
end
else begin
  update FS_BUDGET 
     set Amount       = Amount + @delta,
         User_Id      = @userid,
         Last_Updated = getdate()
   where Budget_Id = @budgetid         
end

if @statusid = '100'
begin
  execute FSProcessTransaction @userid,@transid,'143','BT',''
end     

if @chartid2 != '#######'
begin
  select @deltaStr = convert(varchar(20),@delta * -1)
  select @stmt = 'execute BTSaveBudget @userid,@transid,@chartid2,''#######'',@typeid0,@periodid,@deltaStr'
  select @stmt = replace(@stmt,'@userid',  dbo.addQuotes(@userid))
  select @stmt = replace(@stmt,'@transid', dbo.addQuotes(@transid))
  select @stmt = replace(@stmt,'@chartid2',dbo.addQuotes(@chartid2))
  select @stmt = replace(@stmt,'@typeid0', dbo.addQuotes(@typeid0))
  select @stmt = replace(@stmt,'@periodid',dbo.addQuotes(@periodid))
  select @stmt = replace(@stmt,'@deltaStr',dbo.addQuotes(@deltaStr))
  
  
  --  execute BTSaveBudget @userid,@transid,@chartid2,'#######',@typeid0,@periodid,@deltaStr
  -- select @stmt = "execute BTSaveBudget dbo.addQuotes(@userid), dbo.addQuotes(@transid), dbo.addQuotes(@chartid2), '#######', dbo.addQuotes(@typeid0), dbo.addQuotes(@periodid), dbo.addQuotes(@deltaStr)"
  execute (@stmt)
end

endproc:
if @errno > 0
begin
  RAISERROR(@errmsg, 16, 1)
end

return