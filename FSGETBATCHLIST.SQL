if exists (select 1 from sys.objects where name = 'FSGetBatchList')
begin 
  drop procedure FSGetBatchList
end 
go
CREATE PROCEDURE [dbo].[FSGetBatchList]
/**************************************************************
dbo.FSGetBatchList

Purpose:    Retrieve and list all uploaded batches that have 
            not been deleted.

Called by:  Client application

Calls:      n/a          

Parameters: @userid: ARC user id of person executing procedure  

Syntax:      

Tables used:    T_BATCH_DIRECT
                BT_BATCH_DIRECT_STAGE
                T_BATCH_TRANSFER
                BT_BATCH_TRANSFER_STAGE
                T_BATCH_PAYROLL
                BT_BATCH_PAYROLL_STAGE
                FS_TRANSACTION
                FS_FILE
                BT_BATCH_ERROR
                FS_TRANSACTION_HISTORY
                FS_USER
                T_ACCESS_DEPARTMENT
 
Views used:     V_USER   

Tables updated: #batchlist
                #batchsize
                

Results:

Revision History    :
BW-2012.01.13: written
BW-2013.01.02: modified - CHG0032104
BW-2013.01.14: modified - CHG0032385
BW-2013.03.08: modified - CHG0033048
BW-2013.03.25: modified - CHG0033235 rewrite for performance
BW-2013.05.02: removed filtering out of queued for processing (143)
BW-2013.05.13: CHG0033749 make UNI comparisson uppercase
BW-2013.07.10: CHG0033018 - limit fringe calc to @batchid scope.
BW-2014.02.26: CHG0037941 - Uppercase UNI for filtering.
BW-2014.10.23: CHG0040718 - Remove duplicates.
BW-2017.06.06: CHG0042143 - Overhaul batch upload process.


***************************************************************/
@userid char(04)

as 

declare @cutoffdate     datetime


select @cutoffdate = dateadd(dd,-30,getdate())

-------------------------------------------------------------------------------
-- Create a temp table to hold all possible batches.
-------------------------------------------------------------------------------
create table #batchlist
(
  Column00  varchar(3)  NOT NULL,   -- Batch Type 
  Column01  char(8)     NOT NULL,   -- Batch ID
  Column02  varchar(40) NULL,       -- Creator UNI
  Column03  char(10)    NULL,       -- User Admin Dept
  Column04  char(100)   NOT NULL,   -- File Name
  Column05  varchar(20) NULL,       -- Last Update
  Column06  varchar(21) NOT NULL,   -- Status
  Column07  varchar(20) NULL,       -- Number of Rows
  Id        char(8)     NOT NULL,   -- Batch ID
  Status_Id char(3)     NOT NULL,
  User_Id   char(4)     NULL,
  Type_Id   char(3)     NOT NULL
)

create table #batchsize
(
  Transaction_Id  char(8)     NOT NULL,   -- Batch ID
  Type_Id         char(3)     NOT NULL,   -- Batch Type
  Batch_Size      int         NOT NULL
)

  
-------------------------------------------------------------------------------
-- Get mid- & post-validate DA batches.
-------------------------------------------------------------------------------

insert into #batchlist

select distinct
  Column00  = 'DA',                   -- Batch Type 
  Column01  = tx.Transaction_Id,      -- Batch ID
  Column02  = NULL,                   -- Creator UNI
  Column03  = NULL,                   -- User Admin Dept
  Column04  = f.File_Name,            -- File Name
  Column05  = NULL,                   -- Last Update
  Column06  = case                    -- Status
                when tx.Status_Id = '100' then 'Queued for Validation' 
                when tx.Status_Id = '004' then 'Validated' 
                when tx.Status_Id = '005' then 'Errors Exist' 
                when tx.Status_Id = '143' then 'Queued for Processing' 
                when tx.Status_Id = '144' then 'In Process' 
--                when tx.Status_Id = '134' then 'Applied' 
                                          else 'Unvalidated' 
              end,
  Column07  = NULL,       
  Id        = tx.Transaction_Id,      -- Batch ID
  Status_Id   = tx.Status_Id,
  User_Id   = NULL,                   -- Creator Id
  Type_Id   = '105'

 from BT_BATCH_DIRECT_STAGE B,
--    FS_CHART              C,
      FS_TRANSACTION        tx,
      FS_FILE               f

where tx.Transaction_Id = B.Transaction_Id
--  and B.Chart_Id_Target     = C.Chart_Id
  and tx.Status_Id    not in ('110','134')
  and f.File_Id         = tx.File_Id


insert into #batchsize
select 
    min(b.Column01),
    '105',
    count(B.Transaction_Id)
 from #batchlist b,
      BT_BATCH_DIRECT_STAGE  B
where B.Transaction_Id  = b.Column01
  and b.Type_Id         = '105'
group by b.Column01


-------------------------------------------------------------------------------
-- Get mid- & post-validate TX batches.
-------------------------------------------------------------------------------

insert into #batchlist

select distinct
  Column00  = 'TRN',                  -- Batch Type 
  Column01  = tx.Transaction_Id,      -- Batch ID
  Column02  = NULL,                   -- Creator UNI
  Column03  = NULL,                   -- User Admin Dept
  Column04  = f.File_Name,            -- File Name
  Column05  = NULL,                   -- Last Update
  Column06  = case                    -- Status
                when tx.Status_Id = '100' then 'Queued for Validation' 
                when tx.Status_Id = '004' then 'Validated' 
                when tx.Status_Id = '005' then 'Errors Exist' 
                when tx.Status_Id = '143' then 'Queued for Processing' 
                when tx.Status_Id = '144' then 'In Process' 
                when tx.Status_Id = '134' then 'Applied' 
                                          else 'Unvalidated' 
              end,
  Column07  = NULL,       
  Id        = tx.Transaction_Id,      -- Batch ID
  Status_Id = tx.Status_Id,
  User_Id   = NULL,                   -- Creator Id
  Type_Id   = '106'

 from BT_BATCH_TRANSFER_STAGE B,
--      FS_CHART                C,
      FS_TRANSACTION          tx,
      FS_FILE                 f

where tx.Transaction_Id = B.Transaction_Id
--  and B.Chart_Id_Target = C.Chart_Id
  and tx.Status_Id    not in ('110','134')
  and f.File_Id         = tx.File_Id


insert into #batchsize
select 
    min(b.Column01),
    '106',
    count(B.Transaction_Id)
 from #batchlist b,
      BT_BATCH_TRANSFER_STAGE  B
where B.Transaction_Id  = b.Column01
  and b.Type_Id         = '106'
group by b.Column01


-------------------------------------------------------------------------------
-- Get mid- & post-validate PAY batches.
-------------------------------------------------------------------------------

insert into #batchlist

select distinct
  Column00  = 'PAY',
  Column01  = tx.Transaction_Id,      -- Batch ID
  Column02  = NULL,                   -- Creator UNI
  Column03  = B.ADMINDEPTID,          -- Dept
  Column04  = f.File_Name,            -- File Name
  Column05  = NULL,                   -- Last Update
  Column06  = case                    -- Status
                when tx.Status_Id = '100' then 'Queued for Validation' 
                when tx.Status_Id = '004' then 'Validated' 
                when tx.Status_Id = '005' then 'Errors Exist' 
                when tx.Status_Id = '143' then 'Queued for Processing' 
                when tx.Status_Id = '144' then 'In Process' 
                when tx.Status_Id = '134' then 'Applied' 
                                          else 'Unvalidated' 
              end,
  Column07  = NULL,       
  Id        = tx.Transaction_Id,      -- Batch ID
  Status_Id = tx.Status_Id,
  User_Id   = NULL,                   -- Creator Id
  Type_Id   = '107'

 from BT_BATCH_PAYROLL_STAGE  B,
      FS_TRANSACTION          tx,
      FS_FILE                 f


where tx.Transaction_Id   = B.Transaction_Id
  and tx.Status_Id    not in ('110','134')
  and f.File_Id = tx.File_Id
  

insert into #batchsize
select 
    min(b.Column01),
    '107',
    count(B.Transaction_Id)
 from #batchlist b,
      BT_BATCH_PAYROLL_STAGE  B
where B.Transaction_Id  = b.Column01
  and b.Type_Id         = '107'
group by b.Column01



-------------------------------------------------------------------------------
-- Delete batches that are too old.
-------------------------------------------------------------------------------

delete #batchlist
where Status_Id in ('005','119') and Column05 < @cutoffdate


-------------------------------------------------------------------------------
-- Get the batch transaction's history data.
-------------------------------------------------------------------------------
--dbo.GetTransactionHistoryInfo(tx.Transaction_Id,'141','002','Y'),-- Creator UNI
update #batchlist
   set Column02 = rtrim(U.Last_Name)+', '+rtrim(U.First_Name)+' ('+upper(rtrim(U.Code))+')',
       User_Id  = H.User_Id
  from FS_TRANSACTION_HISTORY H,
       FS_USER                U
 where H.Transaction_History_Id = (select max(h.Transaction_History_Id)
                                     from FS_TRANSACTION_HISTORY h
                                    where h.Transaction_Id = #batchlist.Column01
                                      and h.Type_Id = '141'
                                      and h.Status_Id = '001')
  and U.User_Id = H.User_Id



--dbo.ttoc(dbo.GetTransactionHistoryDate(tx.Transaction_Id,'143'),901),-- Last Update
update #batchlist
   set Column05 = dbo.ttoc(H.Posted,901),
       User_Id  = H.User_Id
  from FS_TRANSACTION_HISTORY H,
       FS_USER                U
 where H.Transaction_History_Id = (select max(h.Transaction_History_Id)
                                     from FS_TRANSACTION_HISTORY h
                                    where h.Transaction_Id = #batchlist.Column01
                                      and h.Type_Id = '143'
                                      and h.Status_Id = '001')
  and U.User_Id = H.User_Id


-------------------------------------------------------------------------------
-- Update department of remaining DA & TRN batches.
-------------------------------------------------------------------------------

update #batchlist
   set Column03 = Department_Number
  from V_USER U
 where U.User_Id = #batchlist.User_Id
   and Type_Id in ('105','106')


-------------------------------------------------------------------------------
-- Delete batches that are not accessible to this user.
-------------------------------------------------------------------------------

delete #batchlist
where (Column03 = NULL and User_Id != @userid) 
   or (User_Id != @userid
        and Column03 not in (select DEPTID
                               from T_ACCESS_DEPARTMENT
                              where User_Id       = @userid
                                and Module_Id     in ('BT','PADS')
                                and Access_Codes  like '%I%'))


-------------------------------------------------------------------------------
-- Update the batch size.
-------------------------------------------------------------------------------
update #batchlist
   set Column07 = convert(varchar(20), b.Batch_Size)
  from #batchsize b
 where #batchlist.Id = b.Transaction_Id
   and #batchlist.Type_Id = b.Type_Id


-------------------------------------------------------------------------------
-- Return the remaining batches.
-------------------------------------------------------------------------------

select 
  Column00, -- Batch Type
  Column01, -- Batch ID
  Column02, -- Last Person to Update
  Column03, -- Dept
  Column04, -- File Name
  Column05, -- Last Update
  Column06, -- Status
  Column07, -- Number of Rows
  Id,
  Status_Id,
  User_Id

  from #batchlist

order by 6 desc,2 desc


drop table #batchsize
--drop table #batchlist

return