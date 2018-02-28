if exists (select 1 from sys.objects where name = 'CSHTransmit')
begin 
  drop procedure CSHTransmit
end 
go
CREATE PROCEDURE [dbo].[CSHTransmit] 
/*#****************************************************************************

dbo.CSHTransmit

Purpose:    This procedure writes transactions to the ARC upload
            file. It is called in the evening batch process.
            
            ARC Upload file:
            - A header file, #tempHeader, is written to the beginning.
            - Transaction lines from #ffe_outboud_arc are summed for like 
              transaction chartstrings and appended.
            - Offset lines from #ffe_outboud_arc are summed for like 
              offset chartstrings (based on batch type) and appended.
            - A trailer file, #tempTrailer, with totals is appended to the end.

Called by:  fineve -  evening batch process

Calls:      FSProcessTransaction      


Parameters: @istest (if 'Y' it does not do updates) 


Reference Information:

  Translation of old status codes to ARC codes:

            F = 102 Released
            D = 102,105 could be just released or may have preliminary approvals
            R = 103 rejected batch
            P = 105 preliminarily approved
            T = 108 transmitted batch
            B = 111 Dept Approved
            M = 112 conditionally approved (not used for now)
             m = 141 selected for teller balance (not used for now)
            G = 113 teller approved
             g = 138 selected for teller balance
            C = 114 batch awaiting controllers office approval (teller balanced)
             c = 139 selected for campus balance 1 (primary)
            A = 115 primary campus balanced
             a = 140 selected for campus balance 2 (secondary)
            Y = 116 finally approved batch
            E = 135 batch awaiting controllers office equipment final approval
            L = 136 reconciled batch (new code)
            N = 137 new or open batch (new code)
            S = ??? released???


  Deposit Types/Transmit Batch Types:

            337 - Smart Safe/MS         = 'U' -- Smart Safe ULID (MS)
            338 - Dept RDC/MS           = 'R' -- Dept RDC machines (MS)
            339 - Cashier RDC/MS & CUMC = 'D' -- MS Cashier RDC Machine (MS)
            340 - SIS/MS                = 'C' -- SIS Processsed by Cashiers (MS)
            341 - OAD                   = 'O' -- UDAR transactions
            342 - ULID/CUMC (bank)      = 'U' -- Bank ULID (CUMC)
            343 - Dept RDC/CUMC         = 'R' -- Dept RDC machines CUMC)
            344 - SIS/CUMC              = 'C' -- SIS Processsed by Cashiers (SIS)
            345 - Dept/MS               = 'C' -- Processsed by Cashiers (MS)    - phasing out
            346 - Dept/CUMC             = 'C' -- Processsed by Cashiers (CUMC)  - phasing out


Syntax:         CSHTransmit 'N'

Tables used:    FS_USER     

Views used:     V_CASH_BATCH_HEADER
                V_CASH_BATCH_DETAIL

Tables updated: FS_TRANSACTION          via FSProcessTransaction
                FS_TRANSACTION_HISTORY  via FSProcessTransaction

Results:

Rewritten by:   Lou Proyect
Rewrite date:   9/20/2011

-------------------------------------------------
Comments:            
-------------------------------------------------

-- 2012.01.26
Per Mike K - 1/26/2012
Business_Unit:
Business_Unit is the header value.  
For the FFE Cash Module, this should be COLUM.
Business_Unit_GL:
Business_Unit_GL is the line business unit.  
For the ChartString below (the cash offset), the value is COLUM.  However, 
when departments enter their ChartString, they may choose any valid business unit.

Here is the Offset ChartString:
Account: 11000
Business Unit: COLUM
Department: 2516137
Fund: 01         -- spaces per SIR# 655
PC BU: GENRL     -- spaces per SIR# 655
Project: UR004745
Activity: 01
Initiative: blank
Segment: blank
Site: blank
Function: blank

-- 2012.02.09
From: derek.j.miller@accenture.com [mailto:derek.j.miller@accenture.com] 
Sent: Thursday, February 09, 2012 2:38 PM
To: vjr1@columbia.edu
Subject: RE: Cash File Run
Joan,
Can you try with Initiative of 00000 (5 zeroes) and Segment of 00000000 (8 zeroes).  
That is equivalent to no initiative or segment.
****************

-- 2012.06.12
From: derek.j.miller@accenture.com [mailto:derek.j.miller@accenture.com] 
Sent: Tuesday, June 12, 2012 7:06 PM
To: vjr1@columbia.edu; Louis Proyect
Cc: jat25@columbia.edu; mf2817@columbia.edu; mk1225@columbia.edu
Subject: RE: Generate test Cash transaction file from findev

Joan,

The file will have to be modified so that debits equal credits 
by BUSINESS UNIT and ACCOUNTING DATE.

-- 2013.04.04 begin:
From: Kenndy Montes 
Sent: Thursday, April 04, 2013 11:56 AM
To: Joan Richards; Patricia Reid
Cc: Patrice Elliott; 'cashteam@columbia.edu' (cashteam@columbia.edu)
Subject: RE: CHG0032178: Wrong project been used in the Cash Module 

Hi Joan,

This is the correct chartstring.

Thanks,

kenndy

Business Unit    = COLUM  
Account         = 11000 
Department       = 2516103                  
Fund Code        = 01                
PC Business Unit = GENRL
Project ID       = UR007176
Activity ID      = 01
Initiative       = 00000
Segment          = 00000000
Site             = spaces
Function         = SPACES
Line Description = REMARK=Cash Module Deposit

-- 2013.04.04 end

-- 2014.01.21 begin:
Cashiering Chartstring 1/21/2014 

Hi Joan,

The chartstring for the new account is listed below:
 
Cash Account: 10271
MCA Clearing Account: 11271
Department: 2516152
Initiative: 00000
Segment: 00000000
Project: UR007246
 
Please let me know if you need anything else. Thank you.

Regards,
Eric
Eric Kaplan | Director, Treasury Operations
| Office of the Treasurer | Columbia University | 615 West 131st St, 3rd Fl.,  NY NY 10027-7922
| t 212-854-9704 | m 203-733-6536 | e ek2819@columbia.edu

Joan, please use the 11271.  Only TWS (Treasury Work Station post to the 10 accounts).
 
Best,
 
Kenndy
 
-- 2014.01.21 end

-------------------------------------------------
Revision History:
-------------------------------------------------
LP-2012.07.10: CHG0030083 - Remove carriage return from description line
BW-2012.08.27: CHG0031000 - to correct dupe Batch ID
SS-2013.04.09: CHG0032139 - Wrong project been used in the Cash Module for 
                            the Concentration Account 
BW-2013.09.16: CHG0035030 - add function passesCurrentBudgetCheck.
SS-2014.01.17: CHG0037230 - Offset chartstrings for DAs must be different from 
                            Cashier's; Cashiering office deposits to be routed 
                            to the new bank account
JV-2015.10.07: CHG0046155 - JV137 Change the Line Reference field on all Cash 
                            Module batches from format DDMMYYZ000 to MMDDYYZ271
LN-2016.05.25: CHG0047271 - MS SQL server implementation
BW 2016-11-23: CHG0052488 - Modify FFE Cash module to reflect CUMC departmental 
                            access change and ULID
BW 2017-09-12: CHG0057656 - Correct effect of UNION not selecting all copies of 
                            identical offset records.
BW-2017.08.23: CHG0056226 - Add functionality for new Cash deposit types; 
                            MS Smart Safe ULIDs for Cash and RDC machines for 
                            all checks (supercedes CHG0052488)  
BW-2017.10.26: CHG0058616 - Smart Safe/RDC soft launch.
BW-2017.11.21: CHG0059046 - Filter on Deposit_Type.
BW-2017.12.04: CHG0059519 - Fix bug in handling SIS batches.
BW-2017.12.05: CHG0059615 - Cash clean-up; reformat for clarity, replace use 
                            of Batch Type with Deposit Type where possible.
BW-2017.12.20: CHG0060012 - Make value of Accounting Date conditional on Deposit Type. 
BW-2018.01.04: CHG0059091 - Enlarge RDC column to 12 characters.
BW-2018.01.05: CHG0060211 - Non-teller-balanced deposits: Accounting_Date = current date.

****************************************************************************#*/

@istest char(1) = 'Y'   

as

/*#************* for FFEEVE *************************************#*/
        
declare 
@datetime24       char(15),
@datetime24_x     char(24),
@yyyy             char(4),
@yy               char(2),
@mm               char(2),
@dd               char(2),
@hr               char(2),
@min              char(2),
@sec              char(2)
        
declare 
@fy               char(4), 
@month            char(2),
@day              char(2),
@year             char(4),
@Rate_Mult        char(17), --S9999999.99999999
@Rate_Div         char(16), --9999999.99999999
@Foreign_Amount   char(28), --S99999999999999999999999.999
@cnt              int,
@cntchar          char(5),
@batchID          char(15),
@lineNum          int,
@transLine        char(3),
@transNum         char(10),
@cntpad           char(5),
@juldd            char(5),
@julianDate       char(5),
@JNL_LN_Ref_Date  char(10),
@offset_Date      char(6)
        
declare 
@recordCnt        int,
@sumAmountSum     money,   
@sumAmountAccChar char(27), 
@sumAmountAcc     numeric(28,3),   
@sumAmountAccTot  char(28),    
@sumAmountFmt     numeric(28,3),
--@cashAmountFmt    numeric(28,3),    
@CreditAmountFmt  numeric(28,3),        
@DebitAmountFmt   numeric(28,3),
@prodtest         char(1), 
@bankCode         char(4) 

     
--------------------------------------------------------------------------
-- Initialize variables
--------------------------------------------------------------------------
Select @bankCode        = 'Z271'  -- Value received from Kenndy Montes  -- See CHG0046155
        
select @month           =  right('00' + convert(varchar(2),month(getdate())), 2) 
select @day             =  right('00' + convert(varchar(2),day(getdate())), 2) 
select @year            =  right('0000' + convert(varchar(4),year(getdate())), 4) 

select @datetime24_x    = convert(char(24), getdate(), 20)

select @yy              = substring(@datetime24_x, 3, 2)
select @yyyy            = substring(@datetime24_x, 1, 4)
select @mm              = substring(@datetime24_x, 6, 2)
select @dd              = substring(@datetime24_x, 9, 2)
select @hr              = substring(@datetime24_x, 12, 2)
select @min             = substring(@datetime24_x, 15, 2)
select @sec             = substring(@datetime24_x, 18, 2)
select @datetime24      = @yyyy+@mm+@dd+@hr+@min+@sec

select @Rate_Mult       = space(7)+'1.00000000'  -- char(17), --S9999999.99999999
select @Rate_Div        = space(6)+'1.00000000'  -- char(16), --9999999.99999999
select @Foreign_Amount  = space(23)+'0.000'      -- char(28), --S99999999999999999999999.999
select @juldd           = convert(char(03),datepart(dy,getdate()))
select @julianDate      = substring(convert(char(04),datepart(yy,getdate())),3,2) + stuff(rtrim(@juldd), 1,0 , replicate('0', 3 - datalength(rtrim(@juldd))))
select @prodtest        = 'P'


--------------------------------------------------------------------------
-- Create temp tables:
--  #tempHeader
--  #tempTrailer
--  #ffe_outboud_arc
--  #transCnt
--------------------------------------------------------------------------
create table #tempHeader
(
  Header_Record          char(973)
)

create table #tempTrailer
(
  Trailer_Record         char(973)
)

create table #ffe_outboud_arc
(
  Batch_Identifier       char(15), 
  Batch_Item_Number      int,
  Record_ID              char(3),
  Business_Unit          char(5),
  Transaction_ID         char(10),
  Transaction_Line       char(3), --unique to each line item, starting with 1for each tramnsmission
  Ledger_Group           char(10),
  Ledger                 char(10), 
  Accounting_Date        char(10),
  Appl_Jrnl_ID           char(10),
  Business_Unit_GL       char(5),
  Fiscal_Year            char(4), --numeric (4),
  Accounting_Period      char(3), --numeric (3),
  Journal_ID             char(10),
  Journal_Date           char(10),
  Journal_Line           char(9), --numeric (9),
  Account                char(10),
  AltAcct                char(10), --n/a
  DeptID                 char(10),
  Operating_Unit         char(8), --n/a
  Product                char(6), --n/a
  Fund_Code              char(5),
  [Function]             char(5), -- CLASS_FLD
  Initiative             char(5), --PROGRAM_CODE,
  Budget_Ref             char(8), --n/a
  Affiliate              char(5),
  Affiliate_Intra1       char(10),
  Affiliate_Intra2       char(10), --n/a
  Segment                char(10), --CHARTFIELD1
  Site                   char(10), --CHARTFIELD2
  Chartfield3            char(10), --n/a
  Business_Unit_PC       char(5),
  Project_ID             char(15),
  Activity_ID            char(15),
  Resource_Type          char(5),
  Resource_Category      char(5),
  Resource_Sub_Cat       char(5),
  Analysis_Type          char(3),
  Currency_Cd            char(3),
  Statistics_Code        char(3), --n/a
  Foreign_Currency       char(3),
  RT_Type                char(5),
  Rate_Mult              char(17), --S9999999.99999999
  Rate_Div               char(16), --9999999.99999999
  Monetary_Amount        char(28), --S99999999999999999999999.999
  Foreign_Amt_Fmt        numeric(28,3) NULL, --S99999999999999999999999.999
  Statistic_Amount       char(17), --n/a --S9999999.99999999 
  Movement_Flag          char(1), --defalut = N (Natural)
  Doc_Type               char(8),  --n/a 
  Doc_Seq_Nbr            char(12),  --n/a 
  Doc_Seq_Date           char(10), --n/a 
  Jnrl_Ln_Ref            char(10), 
  Line_Descr             char(30),
  IU_Sys_Tran_Cd         char(8),
  IU_Tran_Cd             char(8),
  IU_Anchor_Flg          char(1), 
  GL_Distrib_Status      char(1),
  SpeedTyp_Key           char(10),
  CU_User_Defn1          char(10), --Batch_Identifier
  CU_User_Defn2          char(10), --Transaction Number
  CU_User_Defn3          char(10),
  CU_User_Defn4          char(10),
  CU_User_Defn5          char(10), 
  CU_User_Defn6          char(10),
  CU_User_Defn7          char(10),
  CU_User_Defn8          char(10),        
  CU_User_Defn9          char(10),
  CU_User_Defn10         char(10),
  CU_User_Defn11         char(30),
  CU_User_Defn12         char(30),
  CU_User_Defn13         char(30),
  CU_User_Defn14         char(60) NULL, --Transaction_Note_Text (pos 1-60)
  CU_User_Defn15         char(60) NULL, --Transaction_Note_Text (pos 61-100)
  CU_User_Defn16         char(28),
  CU_User_Defn17         char(28),
  CU_User_Defn18         char(28),
  CU_User_Defn19         char(28),
  CU_User_Defn20         char(28),
  Process_Instance       char(10),
  Batch_Type             char(1)  
)

create table #transCnt
(
  BatchID       char(15),
  LineNum       int,
  TransLine     char(3),
  TransNum      char(10)
)


set rowcount 0

-------------------------------------------------------------------------------
-- Select approved Cash batches only (all types) into #cshHrds                       
-------------------------------------------------------------------------------
select 'Transaction_Id'   = h.Transaction_Id,
       'Batch_Identifier' = h.Batch_Identifier,   

   --  CHG0060012 12/20/2017 
   --  for teller-balanced batch use Campus Balance Date  (Deposit Type = 339,340,344,345 or 346)
   --  for ULID or Dept RDC batch use current date        (Deposit Type = 337,338 or 343) 
   --  for GiftSystems (OAD) batch use Deposit Date       (Deposit Type = 341) 
      'Accounting_Date'   = case 
                              when h.Deposit_Type in ('339','340','344','345','346') 
   --  CHG0060211 01/05/2018
   --  For teller-balanced deposits: Accounting_Date = Campus_Balance_Date with fall-back of current date.
   --                           then isnull(convert(char(10), h.Campus_Balance_Date,101),convert(char(10), h.Deposit_Date,101))
   --  For non-teller-balanced deposits: Accounting_Date = current date.
   --                           when h.Deposit_Type in ('337','342','338','343') 
   --                           then convert(char(10), getdate(),101) 
   --                           else convert(char(10), h.Deposit_Date,101) 

                              then isnull(convert(char(10), h.Campus_Balance_Date,101),convert(char(10), getdate(),101))
                              else convert(char(10), getdate(),101) 
                            end, 

   --  use Deposit Date for all batch types  9/29/2015 CHG0046155   
      'JNL_LN_Ref_Date'   = (  right('00' + convert(varchar(2),month(h.Deposit_Date)), 2) 
                             + right('00' + convert(varchar(2),day(h.Deposit_Date)), 2)  
                             + substring(right('00' + convert(varchar(4),year(h.Deposit_Date)), 2), 1, 2) )
                             + @bankCode,  

      'Released_by_Name'  = Released_by_Name,
      'Batch_Type'        = case 
                              when Deposit_Type = '341'           then 'O' -- UDAR transactions                   10/6/2017 (Batch_Type = 'AR')          
                              when Deposit_Type in ('345','346')  then 'C' -- Processsed by Cashiers (MS & CUMC)  10/6/2017 (Batch_Type = 'R') --To be phased out
                              when Deposit_Type in ('340','344')  then 'C' -- Processsed by Cashiers (SIS)        12/4/2017 (Batch_Type = 'R')
                              when Deposit_Type = '339'           then 'D' -- MS Cashier RDC Machine Deposit Type 10/6/2017 (Batch_Type = 'R')
                              when Deposit_Type = '342'           then 'U' -- CUMC Bank ULID Deposit Type         10/6/2017 (Batch_Type = 'R')
                              when Deposit_Type = '337'           then 'S' -- MS Smart Safe ULID Deposit Type     10/6/2017 (Batch_Type = 'R')
                              when Deposit_Type in ('338','343')  then 'R' -- MS & CUMC Depts RDC machines        10/6/2017 (Batch_Type = 'R')
                              else '?'
                            end, --'C' & 'D' = Cashiering Office; 'O' = OAD, 'U' = CUMC ULID, 'R' = MS & CUMC Depts RDC machines, 'S' = MS Smart Safe ULID Deposit Type, '?' = undetermined  
                          
      'Batch_Tot_Amt'     = Total_Combo_Amount,
      'ULID'              = ULID,
      'RDC'               = RDC, 
      'PIN'               = PIN

 into #cshHrds                

  from V_CASH_BATCH_HEADER h  --CS_TRANSACTION, FS_TRANSACTION  

 where Approval_Status_Id = '116'
    or ( Approval_Status_Id IN ('998') and db_name() != 'finprod' )

 --where Transaction_Id  IN ('0001DTTD', '0001DTRF','0001DTS6', '0001DTTK',  '0001DTTF', '0001DTTH', '0001DTTR', '0001DTTP','0001DTT5', '0001DTTN', '0001DSPJ', '0001DTTG', '0001DTT7', '0001DTTM','0001DTTS', '0001DTTT')


  
      
/*****************************************************************************
SELECT 'DB', db_name()
SELECT '1',* FROM CS_TRANSACTION C, FS_TRANSACTION F
  WHERE C.Transaction_Id = F.Transaction_Id
  AND Status_Id = '998'

SELECT '2',* FROM V_CASH_BATCH_HEADER
WHERE Approval_Status_Id = '998'

select '3 - cshHrds', * from #cshHrds

Select '4 - ???cshHrds',* from #cshHrds
  where Batch_Type = '?'
return
   
return 
******************************************************************************/


-------------------------------------------------------------------------------
-- Delete batches from #cshHrds for which a bogus Account value exists or 
-- for which Batch_Type could not be determined.
-------------------------------------------------------------------------------
delete #cshHrds
  from #cshHrds C, V_CASH_BATCH_DETAIL D
 where D.Transaction_Id         = C.Transaction_Id
   and D.Batch_Identifier       = C.Batch_Identifier
   and (substring(D.Account, 6, 1) != ' ' or
        C.Batch_Type = '?')  --10/16/2017 Batch Type not properly defined


-------------------------------------------------------------------------------
--Begin: Assign today's date to the offset transaction
-------------------------------------------------------------------------------
select @offset_Date = right('00' + convert(varchar(2),day(getdate())), 2)
                                 + (right('00' + convert(varchar(2),month(getdate())), 2)   
                                 + substring(right('0000' + convert(varchar(4),year(getdate())), 4), 1, 2) )  
  
-------------------------------------------------------------------------------
-- Load transactions generated from Cash Module
-------------------------------------------------------------------------------
Insert into #ffe_outboud_arc
select Batch_Identifier  = D.Batch_Identifier, 
       Batch_Item_Number = D.Batch_Item_Number,
       Record_ID         = '100',  
       Business_Unit     = 'COLUM',   -- Alice to provide a list of valid BU
       Transaction_ID    = space(10), --to be populated by the Journal Generation process
       Transaction_Line  = space(3),  --'000', --'3 digit seq# to be calculated below',
       Ledger_Group      = convert(char(10), 'ACTUALS'),
       Ledger            = space(10),
       Accounting_Date   = H.Accounting_Date, -- @mm/@dd/@yyyy,  --Teller Approval Date, per Mike says Troy 
       Appl_Jrnl_ID      = convert(char(10), 'CSH'), --'Provided by Troy   
       Business_Unit_GL  = Business_Unit, -- Alice to provide a list of valid BU
       Fiscal_Year       = space(4),  --Will be derived from Accounting Date in the Journal Generation process 
       Accounting_Period = space(3),  --Will be derived from Accounting Date in the Journal Generation process
       Journal_ID        = space(10), --To be populated by PS Journal Generation process
       Journal_Date      = space(10), --To be populated by PS Journal Generation process; @mm+@dd+@yyyy,       
       Journal_Line      = space(9),  --To be populated by PS Journal Generation process  
       Account           = convert(char(10), Account),
       AltAcct           = space(10), --n/a
       DeptID            = convert(char(10), Department_Number),
       Operating_Unit    = space(8),  --n/a
       Product           = space(6),  --n/a
       Fund_Code         = space(5),  --'fund will be defaulted by the Journal Generation process 
       [Function]        = space(5),  --'function will be defaulted in the Journal Generation process, -- CLASS_FLD
       Initiative        = convert(char(5), Initiative), --PROGRAM_CODE,
       Budget_Ref        = space(8),  --n/a ,
       Affiliate         = space(5), 
       Affiliate_Intra1  = space(10),  
       Affiliate_Intra2  = space(10), --n/a
       Segment           = convert(char(10), Segment),  
       Site              = case when Site = '#####' then space(10) else  convert(char(10), Site) end, 
       Chartfield3       = space(10), --n/a       
       Business_Unit_PC  = space(5),  --'PC_Business_Unit will be defaulted in ARC'
       Project_ID        = convert(char(15), Project_ID), --      
       Activity_ID       = convert(char(15), Activity_ID),
       Resource_Type     = space(5), 
       Resource_Category = space(5), 
       Resource_Sub_Cat  = space(5), 
       Analysis_Type     = space(3),        
       Currency_Cd       = space(3),
       Statistics_Code   = space(3),  --n/a
       Foreign_Currency  = 'USD',
       RT_Type           = space(5),  --'CRRNT',       
       Rate_Mult         = space(17), --@Rate_Mult,   
       Rate_Div          = space(16),   
       Monetary_Amount   = space(28), --@Foreign_Amount,  
       Foreign_Amt_Fmt   = case when Debit_Credit_Flag = 'C' then (Transaction_Amount*-1) else Transaction_Amount end, --S9(22).999 
       Statistic_Amount  = space(17), --n/a --S9999999.99999999 
       Movement_Flag     = space(1),  -- ('N' = Natural)
       Doc_Type          = space(8),  --n/a 
       Doc_Seq_Nbr       = space(12), --n/a 
       Doc_Seq_Date      = space(10), --n/a 
       Jnrl_Ln_Ref       = JNL_LN_Ref_Date,--+@bankCode, --9/29/2015 CHG0046155 Deposit date mmddyy+Bank Code(Z271)   - To be used by TWS for reconciliation
       Line_Descr        = isnull(convert(char(30), Description),space(30)), -- Change to char(30),
       IU_Sys_Tran_Cd    = space(8),
       IU_Tran_Cd        = space(8),
       IU_Anchor_Flg     = space(1),  
       GL_Distrib_Status = space(1),
       SpeedTyp_Key      = space(10), 
       CU_User_Defn1     = convert(char(10), D.Batch_Identifier),
       CU_User_Defn2     = convert(char(10), D.Transaction_Id), --space(10),
       CU_User_Defn3     = convert(char(10), D.Detail_Id), --space(10),   
       CU_User_Defn4     = convert(char(10), @year+@month+@day),  --space(10), --Transmit date
       CU_User_Defn5     = convert(char(10), H.Released_by_Name), --space(10), --Who released the batch for approval

-- CHG0059091: Remove unneeded ULID/PIN/RDC values from CU_User_Defn6, CU_User_Defn7
--       CU_User_Defn6     = case when  H.ULID = '#######' then convert(char(10), H.RDC) else convert(char(10), H.ULID) end, 
--       CU_User_Defn7     = convert(char(10), H.PIN), 
       CU_User_Defn6     = space(10), 
       CU_User_Defn7     = space(10),
-------------       

       CU_User_Defn8     = space(10),          
       CU_User_Defn9     = space(10),
       CU_User_Defn10    = space(10),
       CU_User_Defn11    = space(30),
       CU_User_Defn12    = space(30),
       CU_User_Defn13    = space(30),
       CU_User_Defn14    = isnull(substring(Transaction_Note, 1, 60),space(60)), --Transaction_Note_Text (pos 1-60)
       CU_User_Defn15    = isnull(convert(char(60), substring(Transaction_Note, 61, 40)),space(60)), --Transaction_Note_Text (pos 61-100)
       CU_User_Defn16    = space(28),
       CU_User_Defn17    = space(28),
       CU_User_Defn18    = space(28),
       CU_User_Defn19    = space(28),
       CU_User_Defn20    = space(28),
       Process_Instance  = space(10),
       Batch_Type  

  from #cshHrds             H, 
       V_CASH_BATCH_DETAIL  D

where H.Transaction_Id   = D.Transaction_Id
  and H.Batch_Identifier = D.Batch_Identifier
  and Transaction_Amount <> 0.00
order by D.Batch_Identifier, D.Batch_Item_Number

select @cnt = 0
select @cnt = count(*) from #ffe_outboud_arc
--select '@cnt', @cnt

if @cnt is null or @cnt = 0 
begin

   return

end

-- 2017.10.16 test:
--select '5 - #ffe_outboud_arc', * from #ffe_outboud_arc
--return

-------------------------------------------------------------------------------
--SS: CHG0037230 Begin Create offset tranasaction for Cashiering Office deposits
-------------------------------------------------------------------------------
create table #offsetstuffCashier
(
  AccountingDate  char(10),
  JnlLnRefDate    char(10),
  TotAmount       numeric(28,3),
  Batch_Type      char(1)
)

insert into #offsetstuffCashier
select  distinct 
        Accounting_Date, 
        Jnrl_Ln_Ref, 
        sum(Foreign_Amt_Fmt),
        Batch_Type 

 from  #ffe_outboud_arc

where  Batch_Type in ('C', 'D')
group by Accounting_Date, Jnrl_Ln_Ref, Batch_Type 


-------------------------------------------------------------------------------
-- Load offset values for Cashiers transactions
-------------------------------------------------------------------------------
insert into #ffe_outboud_arc

select Batch_Identifier  = 'CASHOFFSET', 
       Batch_Item_Number = 1,
       Record_ID         = '100',  
       Business_Unit     = 'COLUM',   -- Business Unit: COLUM   Per Mike K 
       Transaction_ID    = space(10), --to be populated by the Journal Generation process
       Transaction_Line  = space(3),  --'3 digit seq# to be calculated below',
       Ledger_Group      = convert(char(10), 'ACTUALS'),
       Ledger            = space(10),
       Accounting_Date   = AccountingDate, --convert(char(10), getdate(),101), --@mm/@dd/@yyyy,  --using todays date 
       Appl_Jrnl_ID      = convert(char(10), 'CSH'), --'Provided by Troy   
       Business_Unit_GL  = 'COLUM',   --Alice to provide a list of valid BU
       Fiscal_Year       = space(4),  --Will be derived from Accounting Date in the Journal Generation process 
       Accounting_Period = space(3),  --Will be derived from Accounting Date in the Journal Generation process
       Journal_ID        = space(10), --To be populated by PS Journal Generation process
       Journal_Date      = space(10), --To be populated by PS Journal Generation process; @mm+@dd+@yyyy,       
       Journal_Line      = space(9),  --To be populated by PS Journal Generation process  
       Account           = convert(char(10), '11271'), --1/21/2014  --Account: 11000 --per Milke K
       AltAcct           = space(10), --n/a
       DeptID            = convert(char(10), '2516152'), --1/21/2014 --Department: 2516103 per CHG0032178; --old: 2516137 per Mike K;  
       Operating_Unit    = space(8),  --n/a
       Product           = space(6),  --n/a
       Fund_Code         = space(5),  --convert(char(5), '01'), -- Fund: 01  per Mike K; spaces per SIR# 655
       [Function]        = space(5),  --'function will be defaulted in the Journal Generation process, -- CLASS_FLD --Function: blank per Mike K
       Initiative        = convert(char(5), '00000'), --PROGRAM_CODE, Initiative: blank per Mike K; 00000 (5 zeroes) Per Derek M
       Budget_Ref        = space(8),  --n/a ,
       Affiliate         = space(5), 
       Affiliate_Intra1  = space(10),  
       Affiliate_Intra2  = space(10), --n/a
       Segment           = convert(char(10), '00000000'), -- Segment: blank per Mike K; 00000000 (8 zeroes) per Derek M 
       Site              = space(10), -- Site: blank per Mike K
       Chartfield3       = space(10), --n/a       
       Business_Unit_PC  = space(5),  --'GENRL', -- PC BU: GENRL   per Mike K; spaces per SIR# 655
       Project_ID        = convert(char(15), 'UR007246'), --1/21/2014 -- Project: UR007176 PER CHG0032178; --old: UR004745 per Mike K     
       Activity_ID       = convert(char(15), '01'), --Activity: 01 per Mike K  
       Resource_Type     = space(5), 
       Resource_Category = space(5), 
       Resource_Sub_Cat  = space(5), 
       Analysis_Type     = space(3),        
       Currency_Cd       = space(3),
       Statistics_Code   = space(3),  --n/a
       Foreign_Currency  = 'USD',
       RT_Type           = space(5),  --'CRRNT',       
       Rate_Mult         = space(17), --@Rate_Mult,   
       Rate_Div          = space(16),   
       Monetary_Amount   = space(28), --@Foreign_Amount,  
       Foreign_Amt_Fmt   = ((TotAmount)* -1), --((@cashAmountFmt)* -1),
       Statistic_Amount  = space(17), --n/a 
       Movement_Flag     = space(1),  -- ('N' = Natural)
       Doc_Type          = space(8),  --n/a 
       Doc_Seq_Nbr       = space(12),  --n/a 
       Doc_Seq_Date      = space(10), --n/a 
       Jnrl_Ln_Ref       = JnlLnRefDate,--+@bankCode, --9/29/2015 CHG0046155 Deposit date mmddyy+Bank Code(Z271) - To be used by TWS for reconciliation
       Line_Descr        = convert(char(30), 'Cash Module Deposit '), 
       IU_Sys_Tran_Cd    = space(8),
       IU_Tran_Cd        = space(8),
       IU_Anchor_Flg     = space(1),  
       GL_Distrib_Status = space(1),
       SpeedTyp_Key      = space(10),
       CU_User_Defn1     = convert(char(10), 'CASHOFFSET'),  --space(10),
       CU_User_Defn2     = space(10),
       CU_User_Defn3     = space(10),   
       CU_User_Defn4     = convert(char(10), @year+@month+@day),  --space(10), --Transmit date
       CU_User_Defn5     = space(10), 
       CU_User_Defn6     = space(10),
       CU_User_Defn7     = space(10),
       CU_User_Defn8     = space(10),        
       CU_User_Defn9     = space(10),
       CU_User_Defn10    = space(10),
       CU_User_Defn11    = space(30),
       CU_User_Defn12    = space(30),
       CU_User_Defn13    = space(30),
       CU_User_Defn14    = space(60),  
       CU_User_Defn15    = space(60),
       CU_User_Defn16    = space(28),
       CU_User_Defn17    = space(28),
       CU_User_Defn18    = space(28),
       CU_User_Defn19    = space(28),
       CU_User_Defn20    = space(28),
       Process_Instance  = space(10),
       Batch_Type

  from #offsetstuffCashier


-- 2017.10.16 test
--select '6 -  #ffe_outboud_arc', * from #ffe_outboud_arc
--return

-- End Build offset for Cashiering Office *************************************

-------------------------------------------------------------------------------
--SS: CHG0037230 Begin to Create offset tranasaction for *OAD* CASH deposits
-------------------------------------------------------------------------------
create table #offsetstuffOAD
(
  AccountingDate  char(10),
  JnlLnRefDate    char(10),
  TotAmount       numeric(28,3),
  Batch_Type      char(1)
)
        
insert into #offsetstuffOAD
select  distinct 
        Accounting_Date, 
        Jnrl_Ln_Ref, 
        sum(Foreign_Amt_Fmt),
        Batch_Type 

 from  #ffe_outboud_arc

where  Batch_Type = 'O'  
group by Accounting_Date, Jnrl_Ln_Ref, Batch_Type 


-------------------------------------------------------------------------------
--Load offset values for OAD transactions
-------------------------------------------------------------------------------
Insert into #ffe_outboud_arc
select Batch_Identifier  = 'CASHOFFSET', 
       Batch_Item_Number = 2,
       Record_ID         = '100',  
       Business_Unit     = 'COLUM',   -- Business Unit: COLUM   Per Mike K 
       Transaction_ID    = space(10), --to be populated by the Journal Generation process
       Transaction_Line  = space(3),  --'3 digit seq# to be calculated below',
       Ledger_Group      = convert(char(10), 'ACTUALS'),
       Ledger            = space(10),
       Accounting_Date   = AccountingDate, --convert(char(10), getdate(),101), --@mm/@dd/@yyyy,  --using todays date 
       Appl_Jrnl_ID      = convert(char(10), 'CSH'), --'Provided by Troy   
       Business_Unit_GL  = 'COLUM',   --Alice to provide a list of valid BU
       Fiscal_Year       = space(4),  --Will be derived from Accounting Date in the Journal Generation process 
       Accounting_Period = space(3),  --Will be derived from Accounting Date in the Journal Generation process
       Journal_ID        = space(10), --To be populated by PS Journal Generation process
       Journal_Date      = space(10), --To be populated by PS Journal Generation process; @mm+@dd+@yyyy,       
       Journal_Line      = space(9),  --To be populated by PS Journal Generation process  
       Account           = convert(char(10), '11000'),  --Account: 11000 --per Milke K
       AltAcct           = space(10), --n/a
       DeptID            = convert(char(10), '2516103'), --Department: 2516103 per CHG0032178; --old: 2516137 per Mike K;  
       Operating_Unit    = space(8),  --n/a
       Product           = space(6),  --n/a
       Fund_Code         = space(5),  --convert(char(5), '01'), -- Fund: 01  per Mike K; spaces per SIR# 655
       [Function]        = space(5),  --'function will be defaulted in the Journal Generation process, -- CLASS_FLD --Function: blank per Mike K
       Initiative        = convert(char(5), '00000'), --PROGRAM_CODE, Initiative: blank per Mike K; 00000 (5 zeroes) Per Derek M
       Budget_Ref        = space(8),  --n/a ,
       Affiliate         = space(5), 
       Affiliate_Intra1  = space(10),  
       Affiliate_Intra2  = space(10), --n/a
       Segment           = convert(char(10), '00000000'), -- Segment: blank per Mike K; 00000000 (8 zeroes) per Derek M 
       Site              = space(10), -- Site: blank per Mike K
       Chartfield3       = space(10), --n/a       
       Business_Unit_PC  = space(5),  --'GENRL', -- PC BU: GENRL   per Mike K; spaces per SIR# 655
       Project_ID        = convert(char(15), 'UR007176'), -- Project: UR007176 PER CHG0032178; --old: UR004745 per Mike K     
       Activity_ID       = convert(char(15), '01'), --Activity: 01 per Mike K  
       Resource_Type     = space(5), 
       Resource_Category = space(5), 
       Resource_Sub_Cat  = space(5), 
       Analysis_Type     = space(3),        
       Currency_Cd       = space(3),
       Statistics_Code   = space(3),  --n/a
       Foreign_Currency  = 'USD',
       RT_Type           = space(5),  --'CRRNT',       
       Rate_Mult         = space(17), --@Rate_Mult,   
       Rate_Div          = space(16),   
       Monetary_Amount   = space(28), --@Foreign_Amount,  
       Foreign_Amt_Fmt   = ((TotAmount)* -1), --((@cashAmountFmt)* -1),
       Statistic_Amount  = space(17), --n/a 
       Movement_Flag     = space(1),  -- ('N' = Natural)
       Doc_Type          = space(8),  --n/a 
       Doc_Seq_Nbr       = space(12),  --n/a 
       Doc_Seq_Date      = space(10), --n/a 
       Jnrl_Ln_Ref       = JnlLnRefDate,--+@bankCode, --@offset_Date+@bankCode, --@offsetDepositDate+@bankCode, --ddmmyy - To be used by TWS for reconciliation
       Line_Descr        = convert(char(30), 'Cash Module OAD Deposit '), 
       IU_Sys_Tran_Cd    = space(8),
       IU_Tran_Cd        = space(8),
       IU_Anchor_Flg     = space(1),  
       GL_Distrib_Status = space(1),
       SpeedTyp_Key      = space(10),
       CU_User_Defn1     = convert(char(10), 'CASHOFFSET'),  --space(10),
       CU_User_Defn2     = space(10),
       CU_User_Defn3     = space(10),   
       CU_User_Defn4     = convert(char(10), @year+@month+@day),  --space(10), --Transmit date
       CU_User_Defn5     = space(10), 
       CU_User_Defn6     = space(10),
       CU_User_Defn7     = space(10),
       CU_User_Defn8     = space(10),        
       CU_User_Defn9     = space(10),
       CU_User_Defn10    = space(10),
       CU_User_Defn11    = space(30),
       CU_User_Defn12    = space(30),
       CU_User_Defn13    = space(30),
       CU_User_Defn14    = space(60),  
       CU_User_Defn15    = space(60),
       CU_User_Defn16    = space(28),
       CU_User_Defn17    = space(28),
       CU_User_Defn18    = space(28),
       CU_User_Defn19    = space(28),
       CU_User_Defn20    = space(28),
       Process_Instance  = space(10),
       Batch_Type

  from #offsetstuffOAD


-- 2017.10.16 test
--select '7-  #ffe_outboud_arc', * from #ffe_outboud_arc
--return

-- End Build offset for OAD ***************************************************

-------------------------------------------------------------------------------
-- BW:  Begin to Create offset tranasaction for *CUMC ULID* CASH deposits
-------------------------------------------------------------------------------

create table #offsetstuff_CULID
(
  Batch_Identifier  char(10),
  AccountingDate    char(10),
  JnlLnRefDate      char(10),
  TotAmount         numeric(28,3),
  Batch_Type        char(1),
  Released_by_Name  char(8),
  ULID              char(7),
  PIN               char(4) 
)

insert into #offsetstuff_CULID
select  distinct 
        H.Batch_Identifier,
        H.Accounting_Date, 
        H.JNL_LN_Ref_Date, 
        max(H.Batch_Tot_Amt), 
        H.Batch_Type, 
        max(H.Released_by_Name),
        max(H.ULID),
        max(H.PIN)
        
  from  #ffe_outboud_arc  A,
        #cshHrds          H
       
  where A.Batch_Identifier  = H.Batch_Identifier 
    and H.Batch_Type        = 'U'
 group by H.Batch_Identifier, H.Accounting_Date, H.JNL_LN_Ref_Date, H.Batch_Type 


--select ' #offsetstuff_CULID', * from  #offsetstuff_CULID
--select '#cshHrds',* from  #cshHrds
--return


-------------------------------------------------------------------------------
-- Load offset values for *CUMC ULID Bank* deposit transactions (no PIN)
-------------------------------------------------------------------------------
Insert into #ffe_outboud_arc
select Batch_Identifier  = Batch_Identifier, 
       Batch_Item_Number = 999,
       Record_ID         = '100',  
       Business_Unit     = 'COLUM',     -- Business Unit: COLUM   Per Mike K 
       Transaction_ID    = space(10),   -- to be populated by the Journal Generation process
       Transaction_Line  = space(3),    -- '3 digit seq# to be calculated below',
       Ledger_Group      = convert(char(10), 'ACTUALS'),
       Ledger            = space(10),
       Accounting_Date   = AccountingDate, -- convert(char(10), getdate(),101), --@mm/@dd/@yyyy,  --using todays date 
       Appl_Jrnl_ID      = convert(char(10), 'CSH'), -- 'Provided by Troy   
       Business_Unit_GL  = 'COLUM',     -- Alice to provide a list of valid BU
       Fiscal_Year       = space(4),    -- Will be derived from Accounting Date in the Journal Generation process 
       Accounting_Period = space(3),    -- Will be derived from Accounting Date in the Journal Generation process
       Journal_ID        = space(10),   -- To be populated by PS Journal Generation process
       Journal_Date      = space(10),   -- To be populated by PS Journal Generation process; @mm+@dd+@yyyy,       
       Journal_Line      = space(9),    -- To be populated by PS Journal Generation process  
       Account           = convert(char(10), '11271'),    -- Account: 11271 per Donna Ulijn
       AltAcct           = space(10),   --n/a
       DeptID            = convert(char(10), '2516152'),  -- Department: 2516152 per Donna Ulijn
       Operating_Unit    = space(8),    -- n/a
       Product           = space(6),    -- n/a
       Fund_Code         = space(5),    -- convert(char(5), '01'), -- Fund: 01 per Mike K; spaces per SIR# 655
       [Function]        = space(5),    -- 'function will be defaulted in the Journal Generation process, -- CLASS_FLD --Function: blank per Mike K
       Initiative        = convert(char(5), '00000'), -- PROGRAM_CODE, Initiative: blank per Mike K; 00000 (5 zeroes) Per Derek M
       Budget_Ref        = space(8),    -- n/a ,
       Affiliate         = space(5), 
       Affiliate_Intra1  = space(10),  
       Affiliate_Intra2  = space(10),   -- n/a
       Segment           = convert(char(10), '00000000'), -- Segment: blank per Mike K; 00000000 (8 zeroes) per Derek M 
       Site              = space(10),   -- Site: blank per Mike K
       Chartfield3       = space(10),   -- n/a       
       Business_Unit_PC  = space(5),    -- 'GENRL', -- PC BU: GENRL per Mike K; spaces per SIR# 655
       Project_ID        = convert(char(15), 'UR007246'), -- Project: UR007246 per Donna Ulijn  
       Activity_ID       = convert(char(15), '01'), -- Activity: 01 per Mike K  
       Resource_Type     = space(5), 
       Resource_Category = space(5), 
       Resource_Sub_Cat  = space(5), 
       Analysis_Type     = space(3),        
       Currency_Cd       = space(3),
       Statistics_Code   = space(3),    -- n/a
       Foreign_Currency  = 'USD',
       RT_Type           = space(5),    -- 'CRRNT',       
       Rate_Mult         = space(17),   -- @Rate_Mult,   
       Rate_Div          = space(16),   
       Monetary_Amount   = space(28),   -- @Foreign_Amount,  
       Foreign_Amt_Fmt   = (TotAmount), -- ((@cashAmountFmt)* -1), -- no need to multiply by -1 because getting amount from batch header, not ARC temp file like the other offsets.
       Statistic_Amount  = space(17),   -- n/a 
       Movement_Flag     = space(1),    -- ('N' = Natural)
       Doc_Type          = space(8),    -- n/a 
       Doc_Seq_Nbr       = space(12),   -- n/a 
       Doc_Seq_Date      = space(10),   -- n/a 
       Jnrl_Ln_Ref       = JnlLnRefDate,-- +@bankCode, --@offset_Date+@bankCode, --@offsetDepositDate+@bankCode, --ddmmyy - To be used by TWS for reconciliation
       Line_Descr        = convert(char(30), ULID + ' - ' + Released_by_Name),
       IU_Sys_Tran_Cd    = space(8),
       IU_Tran_Cd        = space(8),
       IU_Anchor_Flg     = space(1),  
       GL_Distrib_Status = space(1),
       SpeedTyp_Key      = space(10),
       CU_User_Defn1     = convert(char(10), 'CASHOFFSET'),  -- space(10),
       CU_User_Defn2     = space(10),
       CU_User_Defn3     = space(10),   
       CU_User_Defn4     = convert(char(10), @year+@month+@day),  -- space(10), --Transmit date
       CU_User_Defn5     = convert(char(10), Batch_Identifier),   -- Making the transaction unique in the event there are multiple batches with the same valuues

-- CHG0059091: Remove unneeded ULID/PIN values from CU_User_Defn6, CU_User_Defn7 (in Line_Descr)
--       CU_User_Defn6     = convert(char(10), ULID), 
--       CU_User_Defn7     = convert(char(10), PIN), 
       CU_User_Defn6     = space(10), 
       CU_User_Defn7     = space(10),
------------

       CU_User_Defn8     = space(10),        
       CU_User_Defn9     = space(10),
       CU_User_Defn10    = space(10),
       CU_User_Defn11    = space(30),
       CU_User_Defn12    = space(30),
       CU_User_Defn13    = space(30),
       CU_User_Defn14    = space(60),  
       CU_User_Defn15    = space(60),
       CU_User_Defn16    = space(28),
       CU_User_Defn17    = space(28),
       CU_User_Defn18    = space(28),
       CU_User_Defn19    = space(28),
       CU_User_Defn20    = space(28),
       Process_Instance  = space(10),
       Batch_Type

  from #offsetstuff_CULID



-- 2017.10.16 test
--select '8 U-  #ffe_outboud_arc', * from #ffe_outboud_arc
--return

-- End Build offset for CUMC ULID *********************************************


-------------------------------------------------------------------------------
-- BW: Begin to Create offset tranasaction for *MS Smart Safe ULID* CASH deposits
-------------------------------------------------------------------------------

create table #offsetstuff_SmartSafe
(
  Batch_Identifier  char(10),
  AccountingDate    char(10),
  JnlLnRefDate      char(10),
  TotAmount         numeric(28,3),
  Batch_Type        char(1),
  Released_by_Name  char(8),
  ULID              char(7),
  PIN               char(4) 
)

insert into #offsetstuff_SmartSafe
select  distinct 
        H.Batch_Identifier,
        H.Accounting_Date, 
        H.JNL_LN_Ref_Date, 
        max(H.Batch_Tot_Amt), -- sum(A.Foreign_Amt_Fmt), --*** replace w name on #cshHrds
        H.Batch_Type, 
        max(H.Released_by_Name),
        max(H.ULID),
        max(PIN)

  from  #cshHrds H

  where H.Batch_Type = 'S'
 group by H.Batch_Identifier, H.Accounting_Date, H.JNL_LN_Ref_Date, H.Batch_Type 


--select ' #offsetstuff_SmartSafe', * from  #offsetstuff_SmartSafe
--select '#cshHrds',* from  #cshHrds
--return


-------------------------------------------------------------------------------
--Load offset values for *MS Smart Safe ULID* CASH deposit transactions (PIN)
-------------------------------------------------------------------------------
Insert into #ffe_outboud_arc
select Batch_Identifier  = Batch_Identifier, 
       Batch_Item_Number = 999,
       Record_ID         = '100',  
       Business_Unit     = 'COLUM',     -- Business Unit: COLUM   Per Mike K 
       Transaction_ID    = space(10),   -- to be populated by the Journal Generation process
       Transaction_Line  = space(3),    -- '3 digit seq# to be calculated below',
       Ledger_Group      = convert(char(10), 'ACTUALS'),
       Ledger            = space(10),
       Accounting_Date   = AccountingDate, -- convert(char(10), getdate(),101), --@mm/@dd/@yyyy,  --using todays date 
       Appl_Jrnl_ID      = convert(char(10), 'CSH'), -- 'Provided by Troy   
       Business_Unit_GL  = 'COLUM',     -- Alice to provide a list of valid BU
       Fiscal_Year       = space(4),    -- Will be derived from Accounting Date in the Journal Generation process 
       Accounting_Period = space(3),    -- Will be derived from Accounting Date in the Journal Generation process
       Journal_ID        = space(10),   -- To be populated by PS Journal Generation process
       Journal_Date      = space(10),   -- To be populated by PS Journal Generation process; @mm+@dd+@yyyy,       
       Journal_Line      = space(9),    -- To be populated by PS Journal Generation process  
       Account           = convert(char(10), '11316'),    -- Account: Provided by Marcela Ruano
       AltAcct           = space(10),   --n/a
       DeptID            = convert(char(10), '2516152'),  -- Department: Provided by Marcela Ruano
       Operating_Unit    = space(8),    -- n/a
       Product           = space(6),    -- n/a
       Fund_Code         = space(5),    -- convert(char(5), '01'), -- Fund: 01 per Mike K; spaces per SIR# 655
       [Function]        = space(5),    -- 'function will be defaulted in the Journal Generation process, -- CLASS_FLD --Function: blank per Mike K
       Initiative        = convert(char(5), '00000'), -- PROGRAM_CODE, Initiative: Provided by Marcela Ruano
       Budget_Ref        = space(8),    -- n/a ,
       Affiliate         = space(5), 
       Affiliate_Intra1  = space(10),  
       Affiliate_Intra2  = space(10),   -- n/a
       Segment           = convert(char(10), '00000000'), -- Segment: Provided by Marcela Ruano 
       Site              = space(10),   -- Site: blank per Mike K
       Chartfield3       = space(10),   -- n/a       
       Business_Unit_PC  = space(5),    -- 'GENRL', -- PC BU: GENRL per Mike K; spaces per SIR# 655
       Project_ID        = convert(char(15), 'UR002655'), -- Project: Provided by Marcela Ruano 
       Activity_ID       = convert(char(15), '01'), -- Activity: Provided by Marcela Ruano   
       Resource_Type     = space(5), 
       Resource_Category = space(5), 
       Resource_Sub_Cat  = space(5), 
       Analysis_Type     = space(3),        
       Currency_Cd       = space(3),
       Statistics_Code   = space(3),    -- n/a
       Foreign_Currency  = 'USD',
       RT_Type           = space(5),    -- 'CRRNT',       
       Rate_Mult         = space(17),   -- @Rate_Mult,   
       Rate_Div          = space(16),   
       Monetary_Amount   = space(28),   -- @Foreign_Amount,  
       Foreign_Amt_Fmt   = (TotAmount), -- ((@cashAmountFmt)* -1), -- no need to multiply by -1 because getting amount from batch header, not ARC temp file like the other offsets.
       Statistic_Amount  = space(17),   -- n/a 
       Movement_Flag     = space(1),    -- ('N' = Natural)
       Doc_Type          = space(8),    -- n/a 
       Doc_Seq_Nbr       = space(12),   -- n/a 
       Doc_Seq_Date      = space(10),   -- n/a 
       Jnrl_Ln_Ref       = JnlLnRefDate,-- +@bankCode, --@offset_Date+@bankCode, --@offsetDepositDate+@bankCode, --ddmmyy - To be used by TWS for reconciliation
       Line_Descr        = convert(char(30), ULID + ' - ' + PIN + ' - ' + Released_by_Name),
       IU_Sys_Tran_Cd    = space(8),
       IU_Tran_Cd        = space(8),
       IU_Anchor_Flg     = space(1),  
       GL_Distrib_Status = space(1),
       SpeedTyp_Key      = space(10),
       CU_User_Defn1     = convert(char(10), 'CASHOFFSET'),  -- space(10),
       CU_User_Defn2     = space(10),
       CU_User_Defn3     = space(10),   
       CU_User_Defn4     = convert(char(10), @year+@month+@day),  -- space(10), --Transmit date
       CU_User_Defn5     = convert(char(10), Batch_Identifier),   -- Making the transaction unique in the event there are multiple batches with the same valuues

-- CHG0059091: Remove unneeded ULID/PIN/RDC values from CU_User_Defn6, CU_User_Defn7 (in Line_Descr)
--       CU_User_Defn6     = convert(char(10), ULID), 
--       CU_User_Defn7     = convert(char(10), PIN), 
       CU_User_Defn6     = space(10), 
       CU_User_Defn7     = space(10), 
------------

       CU_User_Defn8     = space(10),        
       CU_User_Defn9     = space(10),
       CU_User_Defn10    = space(10),
       CU_User_Defn11    = space(30),
       CU_User_Defn12    = space(30),
       CU_User_Defn13    = space(30),
       CU_User_Defn14    = space(60),  
       CU_User_Defn15    = space(60),
       CU_User_Defn16    = space(28),
       CU_User_Defn17    = space(28),
       CU_User_Defn18    = space(28),
       CU_User_Defn19    = space(28),
       CU_User_Defn20    = space(28),
       Process_Instance  = space(10),
       Batch_Type

  from #offsetstuff_SmartSafe


-- 2017.10.16 test
--select '9 S- #ffe_outboud_arc', * from #ffe_outboud_arc
--return

-- End Build offset for MS Smart Safe *****************************************


-------------------------------------------------------------------------------
-- BW:  Begin to Create offset tranasaction for MS & CUMC Dept RDC Machine deposits
-------------------------------------------------------------------------------

create table #offsetstuff_MSandCUMC_RDC
(
  Batch_Identifier  char(10),
  AccountingDate    char(10),
  JnlLnRefDate      char(10),
  TotAmount         numeric(28,3),
  Batch_Type        char(1),
  Released_by_Name  char (8),
  RDC               char(12) 
)

insert into #offsetstuff_MSandCUMC_RDC
select  distinct 
        H.Batch_Identifier,
        H.Accounting_Date, 
        H.JNL_LN_Ref_Date, 
        max(H.Batch_Tot_Amt), -- sum(A.Foreign_Amt_Fmt), --*** replace w name on #cshHrds
        H.Batch_Type, 
        max(H.Released_by_Name),
        max(H.RDC)

 from  #ffe_outboud_arc A,  
       #cshHrds H

 where A.Batch_Identifier = H.Batch_Identifier 
   and H.Batch_Type       = 'R'
 group by H.Batch_Identifier, H.Accounting_Date, H.JNL_LN_Ref_Date, H.Batch_Type 


--select '#offsetstuff_MSandCUMC_RDC', * from  #offsetstuff_MSandCUMC_RDC
--select '#cshHrds',* from  #cshHrds
--return


-------------------------------------------------------------------------------
--Load offset values for MS & CUMC RDC Machine deposit transactions
-------------------------------------------------------------------------------
Insert into #ffe_outboud_arc
select Batch_Identifier  = Batch_Identifier, 
       Batch_Item_Number = 999,
       Record_ID         = '100',  
       Business_Unit     = 'COLUM',     -- Business Unit: COLUM   Per Mike K 
       Transaction_ID    = space(10),   -- to be populated by the Journal Generation process
       Transaction_Line  = space(3),    -- '3 digit seq# to be calculated below',
       Ledger_Group      = convert(char(10), 'ACTUALS'),
       Ledger            = space(10),
       Accounting_Date   = AccountingDate, -- convert(char(10), getdate(),101), --@mm/@dd/@yyyy,  --using todays date 
       Appl_Jrnl_ID      = convert(char(10), 'CSH'), -- 'Provided by Troy   
       Business_Unit_GL  = 'COLUM',     -- Alice to provide a list of valid BU
       Fiscal_Year       = space(4),    -- Will be derived from Accounting Date in the Journal Generation process 
       Accounting_Period = space(3),    -- Will be derived from Accounting Date in the Journal Generation process
       Journal_ID        = space(10),   -- To be populated by PS Journal Generation process
       Journal_Date      = space(10),   -- To be populated by PS Journal Generation process; @mm+@dd+@yyyy,       
       Journal_Line      = space(9),    -- To be populated by PS Journal Generation process  
       Account           = convert(char(10), '11331'),    -- Account: Received from Marcela Ruano
       AltAcct           = space(10),   -- n/a
       DeptID            = convert(char(10), '2516152'),  -- Department: Received from Marcela Ruano
       Operating_Unit    = space(8),    -- n/a
       Product           = space(6),    -- n/a
       Fund_Code         = space(5),    -- convert(char(5), '01'), -- Fund: 01 per Mike K; spaces per SIR# 655
       [Function]        = space(5),    -- 'function will be defaulted in the Journal Generation process, -- CLASS_FLD --Function: blank per Mike K
       Initiative        = convert(char(5), '00000'), -- PROGRAM_CODE, Initiative: Received from Marcela Ruano
       Budget_Ref        = space(8),    -- n/a ,
       Affiliate         = space(5), 
       Affiliate_Intra1  = space(10),  
       Affiliate_Intra2  = space(10),   -- n/a
       Segment           = convert(char(10), '00000000'), -- Segment: Received from Marcela Ruano
       Site              = space(10),   -- Site: blank per Mike K
       Chartfield3       = space(10),   -- n/a       
       Business_Unit_PC  = space(5),    -- 'GENRL', -- PC BU: GENRL per Mike K; spaces per SIR# 655
       Project_ID        = convert(char(15), 'UR002656'), -- Project: Received from Marcela Ruano 
       Activity_ID       = convert(char(15), '01'), -- Activity: Received from Marcela Ruano
       Resource_Type     = space(5), 
       Resource_Category = space(5), 
       Resource_Sub_Cat  = space(5), 
       Analysis_Type     = space(3),        
       Currency_Cd       = space(3),
       Statistics_Code   = space(3),    -- n/a
       Foreign_Currency  = 'USD',
       RT_Type           = space(5),    -- 'CRRNT',       
       Rate_Mult         = space(17),   -- @Rate_Mult,   
       Rate_Div          = space(16),   
       Monetary_Amount   = space(28),   -- @Foreign_Amount,  
       Foreign_Amt_Fmt   = (TotAmount), -- ((@cashAmountFmt)* -1), -- no need to multiply by -1 because getting amount from batch header, not ARC temp file like the other offsets.
       Statistic_Amount  = space(17),   -- n/a 
       Movement_Flag     = space(1),    -- ('N' = Natural)
       Doc_Type          = space(8),    -- n/a 
       Doc_Seq_Nbr       = space(12),   -- n/a 
       Doc_Seq_Date      = space(10),   -- n/a 
       Jnrl_Ln_Ref       = JnlLnRefDate,-- +@bankCode, --@offset_Date+@bankCode, --@offsetDepositDate+@bankCode, --ddmmyy - To be used by TWS for reconciliation
       Line_Descr        = convert(char(30), RDC + ' - ' + Released_by_Name),
       IU_Sys_Tran_Cd    = space(8),
       IU_Tran_Cd        = space(8),
       IU_Anchor_Flg     = space(1),  
       GL_Distrib_Status = space(1),
       SpeedTyp_Key      = space(10),
       CU_User_Defn1     = convert(char(10), 'CASHOFFSET'),  -- space(10),
       CU_User_Defn2     = space(10),
       CU_User_Defn3     = space(10),   
       CU_User_Defn4     = convert(char(10), @year+@month+@day),  -- space(10), --Transmit date
       CU_User_Defn5     = convert(char(10), Batch_Identifier),   -- Making the transaction unique in the event there are multiple batches with the same valuues

-- CHG0059091: Remove unneeded RDC value from CU_User_Defn6 (in Line_Descr)
--       CU_User_Defn6     = convert(char(10), RDC), 
       CU_User_Defn6     = space(10), 
------------

       CU_User_Defn7     = space(10),
       CU_User_Defn8     = space(10),        
       CU_User_Defn9     = space(10),
       CU_User_Defn10    = space(10),
       CU_User_Defn11    = space(30),
       CU_User_Defn12    = space(30),
       CU_User_Defn13    = space(30),
       CU_User_Defn14    = space(60),  
       CU_User_Defn15    = space(60),
       CU_User_Defn16    = space(28),
       CU_User_Defn17    = space(28),
       CU_User_Defn18    = space(28),
       CU_User_Defn19    = space(28),
       CU_User_Defn20    = space(28),
       Process_Instance  = space(10),
       Batch_Type
  
  from #offsetstuff_MSandCUMC_RDC


-- 2017.10.16 test
-- select '10 R- #ffe_outboud_arc', * from #ffe_outboud_arc
-- return


-- End Build offset for MS & CUMC RDC *****************************************




-------------------------------------------------------------------------------
-- Update Status of the FinSys Cash transactions.
-------------------------------------------------------------------------------
if db_name()  in ('finprod')
Begin
   -------------------------------------------------------------------------------
   -- Update the batch status as being sent to ARC.
   -- Load cursor with Transaction_Id for each transmitted batch.
   -------------------------------------------------------------------------------
   declare @cursortransid  char(8)
   declare @userid         char(4)
   declare @description    varchar(40)

   select @userid = User_Id
     from FS_USER
    where Code = 'SYSTEM' 

   select @description = 'Transmitted Cash Batch'

   declare batchtrans CURSOR LOCAL FORWARD_ONLY DYNAMIC FOR

   select C.Transaction_Id
     from #cshHrds             H, 
          CS_TRANSACTION       C
    where H.Transaction_Id   = C.Transaction_Id
      and H.Batch_Identifier = C.Batch_Id

  
   -------------------------------------------------------------------------------
   -- Process the transactions with the 'Transmitted' action type.
   -------------------------------------------------------------------------------
   open batchtrans

   while 1 = 1
   begin

     fetch batchtrans into @cursortransid

     if @@FETCH_STATUS != 0 break

     execute FSProcessTransaction @userid,@cursortransid,'148','CS',@description,'N'

   end

--   close batchtrans

--   deallocate batchtrans

End


-------------------------------------------------------------------------------
-- Create Header Record
-------------------------------------------------------------------------------
insert into #tempHeader
select '000'                                 -- Record Type
       +'CSH'                                -- System
       +@prodtest                            -- Prod/Test indicator
       +'TOFERP '                            -- Direction
       +'GL'                                 -- Module
       +'15'                                 -- Interface ID
       +'JRN'                                -- File content
       +dbo.alltrim(@datetime24)             -- Date/Time (YYYYMMDDHHMMSS 24-hr clock)
       +convert(char(40),'ZCU_GL_IMP')       -- Additional Identifier
       +convert(char(100),'FFE CASH MODULE') -- Free form text


-------------------------------------------------------------------------------
-- Create Trailer Record
-------------------------------------------------------------------------------
select @sumAmountFmt    = (select sum(Foreign_Amt_Fmt)  from #ffe_outboud_arc)
select @recordCnt       = (select count(*)              from #ffe_outboud_arc)
select @DebitAmountFmt  = (select sum(Foreign_Amt_Fmt)  from #ffe_outboud_arc   where Foreign_Amt_Fmt > 0.00)
select @CreditAmountFmt = (select sum(Foreign_Amt_Fmt)  from #ffe_outboud_arc   where Foreign_Amt_Fmt < 0.00)
select @sumAmountAccTot = right(space(28) + (convert(varchar(28),@sumAmountFmt)),28 ) 

insert into #tempTrailer
select '999'                                                           --Record Type
       + convert(char(40),'ZCU_GL_IMP')                                --Identifier
       + right('0000000000' + convert(varchar(10),@recordCnt), 10)     --Record count; number of lines, excluding header & trailer
       + right(space(28)+ (convert(varchar(28),@DebitAmountFmt)),28 )  --Calculate total debits
       + right(space(28)+ (convert(varchar(28),@CreditAmountFmt)),28 ) --Calculate total credits
     
select * from #tempHeader
union 
select  Record_ID+
        Business_Unit+
        Transaction_ID+
        Transaction_Line+ 
        Ledger_Group+
        Ledger+
        Accounting_Date+
        Appl_Jrnl_ID+
        Business_Unit_GL+
        Fiscal_Year+
        Accounting_Period+
        Journal_ID+
        Journal_Date+
        Journal_Line+
        Account+
        AltAcct+
        DeptID+
        Operating_Unit+
        Product+
        Fund_Code+
        [Function]+
        Initiative+
        Budget_Ref+
        Affiliate+
        Affiliate_Intra1+
        Affiliate_Intra2+
        Segment+
        Site+
        Chartfield3+
        Business_Unit_PC+
        Project_ID+
        Activity_ID+
        Resource_Type+
        Resource_Category+
        Resource_Sub_Cat+
        Analysis_Type+
        Currency_Cd+
        Statistics_Code+
        Foreign_Currency+
        RT_Type+
        Rate_Mult+
        Rate_Div+
        Monetary_Amount+
        (right(space(28)+ (convert(varchar(28),Foreign_Amt_Fmt)),28 ) )+
        Statistic_Amount+
        Movement_Flag+
        Doc_Type+
        Doc_Seq_Nbr+
        Doc_Seq_Date+
        Jnrl_Ln_Ref+ 
        replace(Line_Descr, char(13)+char(10),'')+ 
        IU_Sys_Tran_Cd+
        IU_Tran_Cd+
        IU_Anchor_Flg+ 
        GL_Distrib_Status+
        SpeedTyp_Key+
        CU_User_Defn1+
        CU_User_Defn2+
        CU_User_Defn3+
        CU_User_Defn4+
        CU_User_Defn5+
        CU_User_Defn6+
        CU_User_Defn7+
        CU_User_Defn8+        
        CU_User_Defn9+
        CU_User_Defn10+
        CU_User_Defn11+
        CU_User_Defn12+
        CU_User_Defn13+
        replace(CU_User_Defn14, char(13)+char(10),'')+ 
        replace(CU_User_Defn15, char(13)+char(10),'')+ 
        CU_User_Defn16+
        CU_User_Defn17+
        CU_User_Defn18+
        CU_User_Defn19+
        CU_User_Defn20+
        Process_Instance 

 from #ffe_outboud_arc

union

select * from #tempTrailer  



-------------------------------------------------------------------------------
-- clean up
-------------------------------------------------------------------------------
drop table #cshHrds
drop table #offsetstuffCashier
drop table #offsetstuffOAD
drop table #transCnt
drop table #ffe_outboud_arc
drop table #tempHeader 
drop table #tempTrailer