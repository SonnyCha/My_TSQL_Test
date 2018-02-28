if exists (select 1 from sys.objects where name = 'BTGetPayrollWorksheet')
begin 
  drop procedure BTGetPayrollWorksheet
end 
go
CREATE PROCEDURE [dbo].[BTGetPayrollWorksheet]
/**************************************************************
dbo.BTGetPayrollWorksheet

Purpose:          Return payroll budget records in various 
                  formats and levels of detail/summary for 
                  online screens, plus a custom detail format 
                  for batch download when called from 
                  FSNewPayrollDownload.

Called by:        Java client
                  FSNewPayrollDownload
                  
Calls:            BTPostSavePayrollBudget 
                  FSGetUserLockoutFlags
                  

Parameters:       @userid       - User requesting the download
                  @adminDeptId  - Admin Dept on which to filter
                  @chart        - parmstring containing all chart strings
                  @earncode     - Earn Code on which to filter
                  @entrytype    - 1: include fringe chartids 
                                  2: exclude fringe chartids
                  @returntype   - ouput parm indicating: 
                                  D: detail 
                                  S: summary 
                                  R: review (pre-apply view) 
                                  B: batch  (download format) 
                  @test         - N: not test mode (default)
                                  Y: test mode

Syntax:      

Tables used:      FS_EARNCODE
                  FS_CHART
                  FS_PAYROLL_HEADER
                  FS_PAYROLL_BUDGET
                  FS_EMPLOYEE
                  FS_PAYROLL_ACTUAL
                  #payrollH
                  PS_ZCU_CF_ACCT_TBL_EXT
                  #header
                  _RANGE
                  _PERIOD
                  #detail
                  PS_ZCU_CF_DEPT_TBL_EXT
                  #chart
                  #emp
                  _TYPE
                  #diff
                  #grandTableBTGPW
                  #rate
                  FS_RATE
                  FS_DEPTTREE
                  PS_ZCU_CF_PROJ_TBL_EXT
                  PS_ZCU_CF_BU_TBL_EXT
                  PS_ZCU_CF_FUND_TBL_EXT
                  PS_ZCU_PRJ_ACT_TBL_EXT
                  PS_ZCU_CF_INIT_TBL_EXT
                  PS_ZCU_CF_SEG_TBL_EXT                   
                  PS_ZCU_CF_SITE_TBL_EXT
                  PS_ZCU_CF_FUNC_TBL_EXT
 
Views   used:     V_ACCESS
                  V_FS_CHART
                  V_AMOUNTCOL
                  V_PS_ZCU_PRJ_ACT_TBL_EXT
                  V_PS_ZCU_CF_PROJ_TBL_EXT


Tables updated:   #payrollH
                  #header
                  #detail
                  #chart
                  #emp
                  #diff
                  #grandTableBTGPW
                  #rate
                  

Results:          result set 1: user access message
                  result set 2: department list
                  result set 3: generic employee list
                  result set 4: generic chart list
                  result set 5: generic list of earncodes
                  result set 6: column list
                  result set 7: payroll header list
                  result set 8: payroll amount list

              OR for batch download only:
                  result set 1: payroll batch download


Revision History    :
JB-2011.08.15   : written
execute BTGetPayrollWorksheet '0004','7580101','BUSINESS_UNIT=&DEPTID=&BUSINESS_UNIT_PC=&PROJECT_ID=&FUND_CODE=&ACTIVITY_ID=&PROGRAM_CODE=&CHARTFIELD1=&CHARTFIELD2=&ACCOUNT=&CLASS_FLD=&','','R'

JB-2012.11.14     : CHG0031569 Zero out old function on Payroll fringe accounts.
execute BTGetPayrollWorksheet '018V','4564203','BUSINESS_UNIT=&DEPTID=&BUSINESS_UNIT_PC=&PROJECT_ID=&FUND_CODE=#####&ACTIVITY_ID=&PROGRAM_CODE=&CHARTFIELD1=&CHARTFIELD2=&ACCOUNT=&CLASS_FLD=&','','1','S'

BW-2013.01.16   : CHG0031783 Batch download View Only flag = 'Y' when chart Status_Id = '005'
LN-2013.01.22   : CHG0031978 - lockout flags
BW-2013.02.12   : CHG0032679 - Require  Admin/HR Dept
JB-2013.03.01   : CHG0031455 -  add a subtotal for non-fringe lines
JB-2013.04.09   : CHG0033389 - include status_id='004' only for the confirmation screen
BW-2013.04.28   : CHG0033819 - reworked rate query in the batch download section
JB-2013.06.19   : CHG0034185
BW-2013.06.25   : CHG0034295 - adapt download to get CE for budget1 in Q4.
BW-2013.08.13   : CHG0035207 performance enhancements.
JB-2013.10.01   : CHG0030883 - BICS
BW-2013.10.15   : CHG0036041 - Block edit of ineligible Nodes from Payroll worksheet
BW-2013.11.14   : CHG0031702 - Optimize performance of BTGetPayrollWorksheet.
BW-2013.11.14   : CHG0036462 - Drop output inactive lines with no actual or budget amounts.
BW-2013.12.05   : CHG0036810 - Reinstate erroneously commented delete of filtered employees.
BW-2013.12.17   : CHG0036928 - Add second cull of employees after #detail/#header cull.
BW-2014.01.02   : CHG0036978 - Add @module, @minaccess parms to execute BTFlattenDeptTree.
LN-2014.02.26   : CHG0036032 - Add Linkage Between Direct Activity and Payroll Worksheet
BW-2014.04.09   : CHG0038917 - Display columns for unapplied payroll amounts in the payroll download template..
JB-2014.08.26   : CHG0040045 - include more actuals and improve performance
BW-2014.10.14   : CHG0040937 - Remove project budget from download.
BW-2014.11.11   : CHG0041532 - Fix dept desc in download.
JB-2014.01.12   : CHG0042045 - remove summary button and view detail
JB-2015.02.11   : CHG0042454 - do not include accounts that get updated in da
BW-2015.02.12   : CHG0042662 - Change source for download position description; conditionally display base salary.
BW-2015.02.24   : CHG0042675 - Placeholders missing from download.
JB-2015.03.27   : CHG0043180 - execute the post save payroll batch
JB-2015.05.12   : CHG0035212 realign FS_PAYROLL_BUDGET where Transaction_Id101 = '#0000002' and Period_Id = FY+1
JB-2015.07.02   : CHG0041869 - fix inquiry only access
BW-2015.08.20   : CHG0041510 - Add new columns to the download for fringe rate and deduction code.
BW-2015.08.21   : CHG0042445 - Add a new column to the download for the Prior Year OB.
BW-2015.08.21   : CHG0042674 - Add 4 new columns to the download for level 7, 6, 5, & 4 dept nodes.
JB-2015.10.09   : CHG0046191 - display INVALID on chart strings with status_id=005 in the hover
JB-2016.01.16   : CHG0042539 - fix fringe display flag
BW-2016.02.25   : CHG0046834 - Calc Current CE/Salary Variance in download as Total Salary - CE
JB-2016.03.01   : CHG0048601 - fix earncode filter
JB-2014.04.08   : CHG0049034 - ignore filter on account for apply 
JB-2016.04.12   : CHG0042105 - send $0 budgets
JB-2016.04.25   : CHG0048695 - handles status 007
JB-2016.05.13   : CHG0046941 update for BICS to handle 002 (THIS CAN MOVE TO PRODUCTION ANYTIME)
JB-2016.08.16   : CHG0051018 - improve performance of typeB
BW-2016.08.24   : CHG0047271 - Modify joins for sql conversion.
LN-2016.10.13   : CHG0051983 - Resolve duplication of Chart_Id curosr
BW-2016.10.17   : CHG0051190 - Correct logic behind the "ICR/AF Rate" column
BW-2017.01.25   : CHG0045226 - Put PR encumbered start/end dates on download.
SC-2017.03.15   : CHG0041177 - Add UPPER function when derive value for @deptid0 
BW-2017.03.17   : CHG0053593 - Save chart selection values for batch download.
                             - Add ACCOUNT input parm for FSSaveUserChartfields.
LN-2017.04.14   : CHG0054949 - Resolve arithmetic overflow error in payroll worksheet
BW-2017.03.20   : CHG0053987 - Add Employee status column to download.
BW-2017.06.21   : CHG0056183 - Correct wrong rates in download.
LN-2017.12.15   : CHG0048196 - Correctly display the employee name and status in the payroll module instead of "description not found"

execute BTGetPayrollWorksheet '0004','1613103','BUSINESS_UNIT=&DEPTID=&BUSINESS_UNIT_PC=&PROJECT_ID=&FUND_CODE=#####&ACTIVITY_ID=&PROGRAM_CODE=&CHARTFIELD1=&CHARTFIELD2=&ACCOUNT=&CLASS_FLD=&','','1','R' 
****************************************************************#*/
@userid         char(4),
@admindeptid    varchar(10),
@chart          varchar(255),
@earncode       char(3),
@entrytype      char(1) = '1',  -- 1: full 2: simple (no fringe, no totals).  simple only applies to the detail screen
@returntype     char(1),    -- D: detail S: summary R: review B: batch   
@test           char(1) = 'N'

as


declare @errno            int
declare @errmsg           varchar(255)
declare @deptbatchidx      char(8)
declare @minaccess        char(1)
declare @padaccess        char(1)
declare @accessmodule     char(2)
declare @accessid0        char(13)
declare @paramstr         varchar(500)
declare @moduleid         char(2)
declare @deptid0          char(10)
declare @access           char(1)
declare @format           char(1)
declare @periodidp1       char(3) -- previous year 1
declare @periodidp0       char(3) -- previous year 0
declare @periodid0        char(3)
declare @periodid1        char(3)
declare @periodid2        char(3)
declare @periodid3        char(3)
declare @quarter          char(2)
declare @days             int
declare @cdays            varchar(5)
declare @filter           varchar(300)
declare @apply0           char(1) -- apply 0$ payroll budgets

declare @BUSINESS_UNIT    char(5)                  
declare @DEPTID           char(10)                         
declare @FUND_CODE        char(5)                      
declare @BUSINESS_UNIT_PC char(5)               
declare @PROJECT_ID       char(15)                     
declare @ACTIVITY_ID      char(15)                    
declare @PROGRAM_CODE     char(5)                   
declare @CHARTFIELD1      char(10)                    
declare @CHARTFIELD2      char(10)                    
declare @CLASS_FLD        char(5)                      
declare @ACCOUNT          char(10)                        
declare @earncodeid       char(3)
declare @start            datetime

declare @lockout          char(4)
declare @lockout0         char(1)
declare @lockout1         char(1)
declare @lockout2         char(1)
declare @lockout3         char(1)

declare @PDaccessC        char(1)
declare @PDaccessI          char(1)


-----------------------------------------------------------------------------------
-- execute this to see if there are any "unprocessed" payroll batches for the
-- user
-----------------------------------------------------------------------------------
execute dbo.BTPostSavePayrollBudget @userid,'######'

-----------------------------------------------------------------------------------
-- initialize variables
-----------------------------------------------------------------------------------
select @errno            = 0
select @errmsg           = ''

select @deptbatchidx     = '########'
select @deptid0          = dbo.padl(dbo.getFirstWord(UPPER(@admindeptid)),7,'0')
--select @minaccess        = case when @returntype = 'B' then 'I' else 'C' end
select @minaccess        = case when @returntype = 'R' then 'C' else 'I' end
select @access           = @minaccess
--select @accessmodule     = case when @returntype = 'B' then 'PD' else 'BT' end
select @accessmodule     = case when @returntype = 'R' then 'BT' else 'PD' end
select @moduleid         = @accessmodule
--select @accessid0        = @userid+@accessmodule+@deptid0
select @padaccess        = dbo.hasAccess(@userid,'PD','D',@deptid0,@minaccess)
select @apply0           = dbo.GetConfigValue('057')

select @periodidp1       = dbo.GetFiscalYearId(-1)
select @periodidp0       = dbo.GetFiscalYearId(0)
select @periodid0        = dbo.GetFiscalYearId(0)
select @periodid1        = dbo.GetFiscalYearId(1)
select @periodid2        = dbo.GetFiscalYearId(2)
select @periodid3        = dbo.GetFiscalYearId(3)
select @quarter          = dbo.getFiscalQuarter()

select @cdays            = dbo.GetConfigValue('033')
select @days             = convert(int,@cdays)--dbo.GetConfigValue('033'))

select @start            = getdate()


select @BUSINESS_UNIT    = dbo.getFirstWord(upper(dbo.strextract(@chart,'BUSINESS_UNIT','#####')))                                   
select @DEPTID           = dbo.getFirstWord(upper(dbo.strextract(@chart,'DEPTID','#####')))                                                 
select @FUND_CODE        = dbo.getFirstWord(upper(dbo.strextract(@chart,'FUND_CODE','#####')))                                           
select @BUSINESS_UNIT_PC = dbo.getFirstWord(upper(dbo.strextract(@chart,'BUSINESS_UNIT_PC','#####')))                             
select @PROJECT_ID       = dbo.getFirstWord(upper(dbo.strextract(@chart,'PROJECT_ID','#####')))
select @ACTIVITY_ID      = dbo.getFirstWord(upper(dbo.strextract(@chart,'ACTIVITY_ID','#####')))
select @PROGRAM_CODE     = dbo.getFirstWord(upper(dbo.strextract(@chart,'PROGRAM_CODE','#####')))
select @CHARTFIELD1      = dbo.getFirstWord(upper(dbo.strextract(@chart,'CHARTFIELD1','#####')))
select @CHARTFIELD2      = dbo.getFirstWord(upper(dbo.strextract(@chart,'CHARTFIELD2','#####')))
select @CLASS_FLD        = dbo.getFirstWord(upper(dbo.strextract(@chart,'CLASS_FLD','#####')))
select @ACCOUNT          = dbo.getFirstWord(upper(dbo.strextract(@chart,'ACCOUNT','#####')))
select @earncodeid       = '###'

if @returntype = 'R'
begin
  select @CLASS_FLD = '#####'
  select @ACCOUNT   = '#####'
end


if @returntype in ('D','B')
begin
  select @earncodeid     = Earncode_Id from FS_EARNCODE where Code = substring(@earncode,1,3)
end

select @lockout    = 'NNNN'
select @lockout0   = 'N'
select @lockout1   = 'N'
select @lockout2   = 'N'
select @lockout3   = 'N'

execute FSGetUserLockoutFlags @userid,'BT',@lockout output,'N'
select @lockout0 = substring(@lockout,1,1)
select @lockout1 = substring(@lockout,2,1)
select @lockout2 = substring(@lockout,3,1)
select @lockout3 = substring(@lockout,4,1)


-----------------------------------------------------------------------------------
-- build filter
-----------------------------------------------------------------------------------
select @filter = space(1)
if @BUSINESS_UNIT    != '#####' select @filter = @filter + ' Business Unit='+@BUSINESS_UNIT
if @DEPTID           != '#####' select @filter = @filter + ' Department='+@DEPTID
if @FUND_CODE        != '#####' select @filter = @filter + ' Fund Code='+@FUND_CODE
if @BUSINESS_UNIT_PC != '#####' select @filter = @filter + ' PC Business Unit='+@BUSINESS_UNIT_PC
if @PROJECT_ID       != '#####' select @filter = @filter + ' Project='+@PROJECT_ID
if @ACTIVITY_ID      != '#####' select @filter = @filter + ' Activity='+@ACTIVITY_ID
if @PROGRAM_CODE     != '#####' select @filter = @filter + ' Initiative='+@PROGRAM_CODE
if @CHARTFIELD1      != '#####' select @filter = @filter + ' Segment='+@CHARTFIELD1
if @CHARTFIELD2      != '#####' select @filter = @filter + ' Site='+@CHARTFIELD2
if @CLASS_FLD        != '#####' select @filter = @filter + ' Function='+@CLASS_FLD
if @ACCOUNT          != '#####' select @filter = @filter + ' Account='+@ACCOUNT


-----------------------------------------------------------------------------------
-- check access
-----------------------------------------------------------------------------------
-- CHG0041869

if not exists ( select 1
                  from V_ACCESS A
                 where A.User_Id   = @userid
                   and A.Module_Id = @moduleid
                   and A.DEPTID0   = @deptid0
                   and charindex(@access,A.Access_Codes) != 0)
begin                   
  select @errno  = 51001
  select @errmsg = 'User does not have required PAD access to department: '+@deptid0+'. Reference (91).'--@admindeptid
  goto endproc
end


-------------------------------------------------------------------------------
-- Save user's Chart Field parameters:
-------------------------------------------------------------------------------
if @returntype = 'B'
begin

  execute FSSaveUserChartfields   @userid,
                                  '017',
                                  @BUSINESS_UNIT, 
                                  @DEPTID, 
                                  @BUSINESS_UNIT_PC, 
                                  @PROJECT_ID,
                                  @ACTIVITY_ID,
                                  @PROGRAM_CODE,
                                  @CHARTFIELD1,
                                  @CHARTFIELD2,
                                  @ACCOUNT,       -- (new for CHG0053593)
                                  '#####',        -- @OFFSET_DEPTID
                                  '#####'         -- @OFFSET_PROJECT_ID

end


-------------------------------------------------------------------------------
-- build dynamic sql statements
-------------------------------------------------------------------------------
declare @sqlD    varchar(2000)
declare @sqlC    varchar(5000)
declare @sqlH1   varchar(5000)
declare @sqlH    varchar(5000)
declare @fieldH  varchar(1000)

-------------------------------------------------------------------------------
-- build dynamic department sql
-------------------------------------------------------------------------------
select @sqlD = ''
select @sqlD = @sqlD + 'select DEPTID,Access_Codes'                  + char(10)
select @sqlD = @sqlD + '  from V_ACCESS'                             + char(10)
select @sqlD = @sqlD + ' where DEPTID0   = @deptid0'                 + char(10)
select @sqlD = @sqlD + '   and User_Id   = @userid'                  + char(10)
select @sqlD = @sqlD + '   and Module_Id = @moduleid'                + char(10)
select @sqlD = @sqlD + '   and charindex(@access,Access_Codes) != 0' + char(10)
           
select @sqlD = replace(@sqlD,'@deptid0' ,dbo.addQuotes(@deptid0))           
select @sqlD = replace(@sqlD,'@userid'  ,dbo.addQuotes(@userid))           
select @sqlD = replace(@sqlD,'@moduleid',dbo.addQuotes(@moduleid))           
select @sqlD = replace(@sqlD,'@access'  ,dbo.addQuotes(@access))           


           
-------------------------------------------------------------------------------
-- build dynamic fs_chart sql
-------------------------------------------------------------------------------
select @sqlC = ''
select @sqlC = @sqlC + 'select C.Chart_Id'          + char(10)
select @sqlC = @sqlC + '  from FS_CHART C,'         + char(10)
select @sqlC = @sqlC + '       ('                   + char(10)
select @sqlC = @sqlC + @sqlD
select @sqlC = @sqlC + '       )        D'          + char(10)
select @sqlC = @sqlC + ' where C.DEPTID = D.DEPTID' + char(10)

if @BUSINESS_UNIT    != '#####' select @sqlC = @sqlC + 'and C.BUSINESS_UNIT    = @BUSINESS_UNIT '   +char(10)
if @DEPTID           != '#####' select @sqlC = @sqlC + 'and C.DEPTID           = @DEPTID '          +char(10)
if @FUND_CODE        != '#####' select @sqlC = @sqlC + 'and C.FUND_CODE        = @FUND_CODE '       +char(10)
if @BUSINESS_UNIT_PC != '#####' select @sqlC = @sqlC + 'and C.BUSINESS_UNIT_PC = @BUSINESS_UNIT_PC '+char(10)
if @PROJECT_ID       != '#####' select @sqlC = @sqlC + 'and C.PROJECT_ID       = @PROJECT_ID '      +char(10)
if @ACTIVITY_ID      != '#####' select @sqlC = @sqlC + 'and C.ACTIVITY_ID      = @ACTIVITY_ID '     +char(10)
if @PROGRAM_CODE     != '#####' select @sqlC = @sqlC + 'and C.PROGRAM_CODE     = @PROGRAM_CODE '    +char(10)
if @CHARTFIELD1      != '#####' select @sqlC = @sqlC + 'and C.CHARTFIELD1      = @CHARTFIELD1 '     +char(10)
if @CHARTFIELD2      != '#####' select @sqlC = @sqlC + 'and C.CHARTFIELD2      = @CHARTFIELD2 '     +char(10)
if @CLASS_FLD        != '#####' select @sqlC = @sqlC + 'and C.CLASS_FLD        = @CLASS_FLD '       +char(10)
if @ACCOUNT          != '#####' select @sqlC = @sqlC + 'and C.ACCOUNT          = @ACCOUNT '         +char(10)

select @sqlC = replace(@sqlC,'@BUSINESS_UNIT_PC',dbo.addQuotes(@BUSINESS_UNIT_PC))
select @sqlC = replace(@sqlC,'@BUSINESS_UNIT'   ,dbo.addQuotes(@BUSINESS_UNIT))
select @sqlC = replace(@sqlC,'@DEPTID'          ,dbo.addQuotes(@DEPTID))
select @sqlC = replace(@sqlC,'@FUND_CODE'       ,dbo.addQuotes(@FUND_CODE))
select @sqlC = replace(@sqlC,'@PROJECT_ID'      ,dbo.addQuotes(@PROJECT_ID))
select @sqlC = replace(@sqlC,'@ACTIVITY_ID'     ,dbo.addQuotes(@ACTIVITY_ID))
select @sqlC = replace(@sqlC,'@PROGRAM_CODE'    ,dbo.addQuotes(@PROGRAM_CODE))
select @sqlC = replace(@sqlC,'@CHARTFIELD1'     ,dbo.addQuotes(@CHARTFIELD1))
select @sqlC = replace(@sqlC,'@CHARTFIELD2'     ,dbo.addQuotes(@CHARTFIELD2))
select @sqlC = replace(@sqlC,'@CLASS_FLD'       ,dbo.addQuotes(@CLASS_FLD))
select @sqlC = replace(@sqlC,'@ACCOUNT'         ,dbo.addQuotes(@ACCOUNT))



create table #header (
  Payroll_Id      char(7),
  Employee_Id     char(11),
  Employee_Name   char(50),
  ADMINDEPTID     char(10),
  Chart_Id        char(7),
  Chart_Status_Id char(3),
  Chart_Desc      varchar(100),
  DEPTID          char(10),
  ACCOUNT         char(10),
  Earncode_Id     char(3),
  Earncode_Code   char(3),
  Last_Updated    datetime,
  Disabled        char(5),
  Chart_Class     varchar(40),
  Employee_Class  varchar(40),
  Employee_Group  char(2)
)  


create table #payrollH (
  Payroll_Id   char(7),
  Employee_Id  char(11),  
  Chart_Id     char(7),  
  Earncode_Id  char(3),
  Last_Updated datetime,
  Access_Codes char(10)
)

select @fieldH = 'H.Payroll_Id,H.Employee_Id,H.Chart_Id,H.Earncode_Id,max(H.Last_Updated) as Last_Updated,max(Access_Codes) as Access_Codes'

-------------------------------------------------------------------------------
-- build dynamic fs_payroll_header for employees with budgets or actuals
-- 1. all of my employees with budgets
-- 2. all of my employees with actuals
-- 3. all of my chart strings with budgets
-- 4. all of my chart strings with actuals
-- 5. all of my employees added/updated with last @days days
-- 6. all of my chart stings added/updated with last @days days
-------------------------------------------------------------------------------
select @sqlH1 = ''
select @sqlH1 = @sqlH1 + 'insert into #payrollH'                                               + char(10)
select @sqlH1 = @sqlH1 + 'select '+@fieldH                                                     + char(10)
select @sqlH1 = @sqlH1 + '  from FS_PAYROLL_HEADER H,'                                         + char(10)
select @sqlH1 = @sqlH1 + '       FS_PAYROLL_BUDGET B,'                                         + char(10)
select @sqlH1 = @sqlH1 + '       FS_EMPLOYEE       E,'                                         + char(10)
select @sqlH1 = @sqlH1 + '       ('                                                            + char(10)
select @sqlH1 = @sqlH1 + @sqlD
select @sqlH1 = @sqlH1 + '       )        D'                                                   + char(10)
select @sqlH1 = @sqlH1 + ' where H.Employee_Id = E.Employee_Id'                                + char(10)
select @sqlH1 = @sqlH1 + '   and H.Payroll_Id  = B.Payroll_Id'                                 + char(10)
select @sqlH1 = @sqlH1 + '   and E.ADMINDEPTID = D.DEPTID'                                     + char(10)
select @sqlH1 = @sqlH1 + '   and B.Period_Id in (@periodid0,@periodid1,@periodid2,@periodid3)' + char(10)
select @sqlH1 = @sqlH1 + ' group by H.Payroll_Id,H.Chart_Id,H.Employee_Id,H.Earncode_Id'       + char(10)
select @sqlH1 = @sqlH1 + ' union'                                                              + char(10)

--select @sqlH1 = ''
select @sqlH1 = @sqlH1 + 'select '+@fieldH                                                     + char(10)
select @sqlH1 = @sqlH1 + '  from FS_PAYROLL_HEADER H,'                                         + char(10)
select @sqlH1 = @sqlH1 + '       FS_PAYROLL_ACTUAL A,'                                         + char(10)
select @sqlH1 = @sqlH1 + '       FS_EMPLOYEE       E,'                                         + char(10)
select @sqlH1 = @sqlH1 + '       ('                                                            + char(10)
select @sqlH1 = @sqlH1 + @sqlD
select @sqlH1 = @sqlH1 + '       )        D'                                                   + char(10)
select @sqlH1 = @sqlH1 + ' where H.Employee_Id = E.Employee_Id'                                + char(10)
select @sqlH1 = @sqlH1 + '   and H.Payroll_Id  = A.Payroll_Id'                                 + char(10)
select @sqlH1 = @sqlH1 + '   and E.ADMINDEPTID = D.DEPTID'                                     + char(10)
select @sqlH1 = @sqlH1 + '   and A.Period_Id in (@periodidp1,@periodid0)'                      + char(10)
select @sqlH1 = @sqlH1 + ' group by H.Payroll_Id,H.Chart_Id,H.Employee_Id,H.Earncode_Id'       + char(10)
select @sqlH1 = @sqlH1 + ' union'                                                              + char(10)

--select @sqlH1 = ''
select @sqlH1 = @sqlH1 + 'select '+@fieldH                                                     + char(10)
select @sqlH1 = @sqlH1 + '  from FS_PAYROLL_HEADER H,'                                         + char(10)
select @sqlH1 = @sqlH1 + '       FS_PAYROLL_BUDGET B,'                                         + char(10)
select @sqlH1 = @sqlH1 + '       FS_CHART          C,'                                         + char(10)
select @sqlH1 = @sqlH1 + '       ('                                                            + char(10)
select @sqlH1 = @sqlH1 + @sqlD
select @sqlH1 = @sqlH1 + '       )        D'                                                   + char(10)
select @sqlH1 = @sqlH1 + ' where H.Chart_Id    = C.Chart_Id'                                   + char(10)
select @sqlH1 = @sqlH1 + '   and H.Payroll_Id  = B.Payroll_Id'                                 + char(10)
select @sqlH1 = @sqlH1 + '   and C.DEPTID      = D.DEPTID'                                     + char(10)
select @sqlH1 = @sqlH1 + '   and B.Period_Id in (@periodid0,@periodid1,@periodid2,@periodid3)' + char(10)
select @sqlH1 = @sqlH1 + ' group by H.Payroll_Id,H.Chart_Id,H.Employee_Id,H.Earncode_Id'       + char(10)
select @sqlH1 = @sqlH1 + ' union'                                                              + char(10)

--select @sqlH1 = ''
select @sqlH1 = @sqlH1 + 'select '+@fieldH                                                     + char(10)
select @sqlH1 = @sqlH1 + '  from FS_PAYROLL_HEADER H,'                                         + char(10)
select @sqlH1 = @sqlH1 + '       FS_PAYROLL_ACTUAL A,'                                         + char(10)
select @sqlH1 = @sqlH1 + '       FS_CHART          C,'                                         + char(10)
select @sqlH1 = @sqlH1 + '       ('                                                            + char(10)
select @sqlH1 = @sqlH1 + @sqlD
select @sqlH1 = @sqlH1 + '       )        D'                                                   + char(10)
select @sqlH1 = @sqlH1 + ' where H.Chart_Id    = C.Chart_Id'                                   + char(10)
select @sqlH1 = @sqlH1 + '   and H.Payroll_Id  = A.Payroll_Id'                                 + char(10)
select @sqlH1 = @sqlH1 + '   and C.DEPTID      = D.DEPTID'                                     + char(10)
select @sqlH1 = @sqlH1 + '   and A.Period_Id in (@periodidp1,@periodid0)'                      + char(10)
select @sqlH1 = @sqlH1 + ' group by H.Payroll_Id,H.Chart_Id,H.Employee_Id,H.Earncode_Id'       + char(10)
select @sqlH1 = @sqlH1 + ' union'                                                              + char(10)

--select @sqlH1 = ''
select @sqlH1 = @sqlH1 + 'select '+@fieldH                                                     + char(10)
select @sqlH1 = @sqlH1 + '  from FS_PAYROLL_HEADER H,'                                         + char(10)
select @sqlH1 = @sqlH1 + '       FS_EMPLOYEE       E,'                                         + char(10)
select @sqlH1 = @sqlH1 + '       ('                                                            + char(10)
select @sqlH1 = @sqlH1 + @sqlD
select @sqlH1 = @sqlH1 + '       )        D'                                                   + char(10)
select @sqlH1 = @sqlH1 + ' where H.Employee_Id = E.Employee_Id'                                + char(10)
select @sqlH1 = @sqlH1 + '   and E.ADMINDEPTID = D.DEPTID'                                     + char(10)
select @sqlH1 = @sqlH1 + '   and datediff(day,H.Last_Updated,getdate()) < @cdays'               + char(10)
select @sqlH1 = @sqlH1 + ' group by H.Payroll_Id,H.Chart_Id,H.Employee_Id,H.Earncode_Id'       + char(10)
select @sqlH1 = @sqlH1 + ' union'                                                              + char(10)

--select @sqlH1 = ''
select @sqlH1 = @sqlH1 + 'select '+@fieldH                                                     + char(10)
select @sqlH1 = @sqlH1 + '  from FS_PAYROLL_HEADER H,'                                         + char(10)
select @sqlH1 = @sqlH1 + '       FS_CHART          C,'                                         + char(10)
select @sqlH1 = @sqlH1 + '       ('                                                            + char(10)
select @sqlH1 = @sqlH1 + @sqlD
select @sqlH1 = @sqlH1 + '       )        D'                                                   + char(10)
select @sqlH1 = @sqlH1 + ' where H.Chart_Id    = C.Chart_Id'                                   + char(10)
select @sqlH1 = @sqlH1 + '   and C.DEPTID      = D.DEPTID'                                     + char(10)
select @sqlH1 = @sqlH1 + '   and datediff(day,H.Last_Updated,getdate()) < @cdays'               + char(10)
select @sqlH1 = @sqlH1 + ' group by H.Payroll_Id,H.Chart_Id,H.Employee_Id,H.Earncode_Id'       + char(10)


select @sqlH1 = replace(@sqlH1,'@periodidp1'        ,dbo.addQuotes(@periodidp1))
select @sqlH1 = replace(@sqlH1,'@periodid0'         ,dbo.addQuotes(@periodid0))
select @sqlH1 = replace(@sqlH1,'@periodid1'         ,dbo.addQuotes(@periodid1))
select @sqlH1 = replace(@sqlH1,'@periodid2'         ,dbo.addQuotes(@periodid2))
select @sqlH1 = replace(@sqlH1,'@periodid3'         ,dbo.addQuotes(@periodid3))
select @sqlH1 = replace(@sqlH1,'@cdays'             ,@cdays)



-------------------------------------------------------------------------------
-- build #header statement
-------------------------------------------------------------------------------
select @sqlH = ''
select @sqlH = @sqlH + 'insert into #header'                                                   + char(10)
select @sqlH = @sqlH + 'select H.Payroll_Id,'                                                  + char(10)
select @sqlH = @sqlH + '       E.Employee_Id                    as Employee_Id,'               + char(10)          
select @sqlH = @sqlH + '       E.Name                           as Employee_Name,'             + char(10)          
select @sqlH = @sqlH + '       E.ADMINDEPTID                    as ADMINDEPTID,'               + char(10)
select @sqlH = @sqlH + '       C.Chart_Id                       as Chart_Id,'                  + char(10)
select @sqlH = @sqlH + '       C.Status_Id                      as Chart_Status_Id,'           + char(10)
select @sqlH = @sqlH + '       C.Description                    as Chart_Desc,'                + char(10)
select @sqlH = @sqlH + '       C.DEPTID                         as DEPTID,'                    + char(10)
select @sqlH = @sqlH + '       C.ACCOUNT                        as ACCOUNT,'                   + char(10)
select @sqlH = @sqlH + '       R.Earncode_Id                    as Earncode_Id,'               + char(10)
select @sqlH = @sqlH + '       R.Code                           as Earncode_Code,'             + char(10)
select @sqlH = @sqlH + '       H.Last_Updated                   as Last_Updated,'              + char(10)
select @sqlH = @sqlH + '       case'                                                           + char(10)
select @sqlH = @sqlH + '         when charindex(''C'',H.Access_Codes) = 0 then ''true'''       + char(10)
select @sqlH = @sqlH + '         when C.Status_Id    = ''005''            then ''true'''       + char(10)
select @sqlH = @sqlH + '         when C.Status_Id    = ''007''            then ''true'''       + char(10)
select @sqlH = @sqlH + '         when A.Payroll_Flag = ''Y''              then ''false'''      + char(10) 
select @sqlH = @sqlH + '                                                  else ''true'''       + char(10) 
select @sqlH = @sqlH + '       end                              as Disabled,'                  + char(10) 
select @sqlH = @sqlH + '       ''foreign''                      as Chart_Class,'               + char(10)
select @sqlH = @sqlH + '       ''foreign''                      as Employee_Class,'            + char(10)
select @sqlH = @sqlH + '       ''01''                           as Employee_Group'             + char(10)
select @sqlH = @sqlH + '  from #payrollH              H,'                                      + char(10)
select @sqlH = @sqlH + '       FS_EMPLOYEE            E,'                                      + char(10)
select @sqlH = @sqlH + '       FS_EARNCODE            R,'                                      + char(10)
select @sqlH = @sqlH + '       V_FS_CHART             C,'                                      + char(10)
select @sqlH = @sqlH + '       PS_ZCU_CF_ACCT_TBL_EXT A'                                       + char(10)
select @sqlH = @sqlH + ' where H.Employee_Id    = E.Employee_Id'                               + char(10)
select @sqlH = @sqlH + '   and H.Earncode_Id    = R.Earncode_Id'                               + char(10)
select @sqlH = @sqlH + '   and H.Chart_Id       = C.Chart_Id'                                  + char(10)
select @sqlH = @sqlH + '   and C.ACCOUNT        = A.ACCOUNT'                                   + char(10)

if @BUSINESS_UNIT    != '#####' select @sqlH = @sqlH + 'and C.BUSINESS_UNIT    = @BUSINESS_UNIT '   + char(10)
if @DEPTID           != '#####' select @sqlH = @sqlH + 'and C.DEPTID           = @DEPTID '          + char(10)
if @FUND_CODE        != '#####' select @sqlH = @sqlH + 'and C.FUND_CODE        = @FUND_CODE '       + char(10)
if @BUSINESS_UNIT_PC != '#####' select @sqlH = @sqlH + 'and C.BUSINESS_UNIT_PC = @BUSINESS_UNIT_PC '+ char(10)
if @PROJECT_ID       != '#####' select @sqlH = @sqlH + 'and C.PROJECT_ID       = @PROJECT_ID '      + char(10)
if @ACTIVITY_ID      != '#####' select @sqlH = @sqlH + 'and C.ACTIVITY_ID      = @ACTIVITY_ID '     + char(10)
if @PROGRAM_CODE     != '#####' select @sqlH = @sqlH + 'and C.PROGRAM_CODE     = @PROGRAM_CODE '    + char(10)
if @CHARTFIELD1      != '#####' select @sqlH = @sqlH + 'and C.CHARTFIELD1      = @CHARTFIELD1 '     + char(10)
if @CHARTFIELD2      != '#####' select @sqlH = @sqlH + 'and C.CHARTFIELD2      = @CHARTFIELD2 '     + char(10)
if @CLASS_FLD        != '#####' select @sqlH = @sqlH + 'and C.CLASS_FLD        = @CLASS_FLD '       + char(10)
if @ACCOUNT          != '#####' select @sqlH = @sqlH + 'and C.ACCOUNT          = @ACCOUNT '         + char(10)
if @earncodeid       != '###'   select @sqlH = @sqlH + 'and R.Earncode_Id      = @earncodeid '      + char(10)

select @sqlH = replace(@sqlH,'@BUSINESS_UNIT_PC',dbo.addQuotes(@BUSINESS_UNIT_PC))
select @sqlH = replace(@sqlH,'@BUSINESS_UNIT'   ,dbo.addQuotes(@BUSINESS_UNIT))
select @sqlH = replace(@sqlH,'@DEPTID'          ,dbo.addQuotes(@DEPTID))
select @sqlH = replace(@sqlH,'@FUND_CODE'       ,dbo.addQuotes(@FUND_CODE))
select @sqlH = replace(@sqlH,'@PROJECT_ID'      ,dbo.addQuotes(@PROJECT_ID))
select @sqlH = replace(@sqlH,'@ACTIVITY_ID'     ,dbo.addQuotes(@ACTIVITY_ID))
select @sqlH = replace(@sqlH,'@PROGRAM_CODE'    ,dbo.addQuotes(@PROGRAM_CODE))
select @sqlH = replace(@sqlH,'@CHARTFIELD1'     ,dbo.addQuotes(@CHARTFIELD1))
select @sqlH = replace(@sqlH,'@CHARTFIELD2'     ,dbo.addQuotes(@CHARTFIELD2))
select @sqlH = replace(@sqlH,'@CLASS_FLD'       ,dbo.addQuotes(@CLASS_FLD))
select @sqlH = replace(@sqlH,'@ACCOUNT'         ,dbo.addQuotes(@ACCOUNT))
select @sqlH = replace(@sqlH,'@earncodeid'      ,dbo.addQuotes(@earncodeid))

       

execute (@sqlH1)
execute (@sqlH)

update #header
   set Chart_Class = 'local'
  from #header,
       V_ACCESS A
 where A.User_Id   = @userid
   and A.Module_Id = @moduleid
   and A.DEPTID0   = @deptid0
   and charindex(@access,A.Access_Codes) != 0
   and #header.DEPTID = A.DEPTID

update #header
   set Employee_Class = 'local'
  from #header,
       V_ACCESS A
 where A.User_Id   = @userid
   and A.Module_Id = @moduleid
   and A.DEPTID0   = @deptid0
   and charindex(@access,A.Access_Codes) != 0
   and #header.ADMINDEPTID = A.DEPTID

delete #header
 where Chart_Class    = 'foreign'
   and Employee_Class = 'foreign'


-- fringe filter
if @entrytype = '2' and @returntype in ('D')
begin
  delete #header 
    from #header,
         _RANGE
   where _RANGE.Type_Id    = '558'
     and _RANGE.Range_From = #header.ACCOUNT    
end

drop table #payrollH


--select * from #header order by Payroll_Id
--drop table #header
--return



-- CONINUE PERFORMANCE IMPROVEMENTS HERE

-- select distinct -- REMOVED FOR SQL
select distinct
       'Id'          = C.Chart_Id,
       'Chart_Id'    = C.Chart_Id,       
       'Name'        = C.Description,       
       'Description' = C.Description,
       'Title'       = 'Chart_Id='+C.Chart_Id + case when isnull(C.Status_Id,'###') = '005' then ' [INVALID]' else '' end,
       'CSS_Class1'  = 'detail'               + case when isnull(C.Status_Id,'###') = '002' then ' inactive'  else '' end,
       'CSS_Class2'  = case when D.DEPTID is null then 'foreign' else 'local' end,
       'Sort_By'     = C.Description+'01',
       'Status_Id'   = isnull(C.Status_Id,'###')
  into #chart       
  from #header H left join V_FS_CHART C on H.Chart_Id = C.Chart_Id
                 left join (select distinct
                                   A.DEPTID
                              from V_ACCESS A
                             where A.User_Id   = @userid
                               and A.Module_Id = @moduleid
                               and A.DEPTID0   = @deptid0
                               and charindex(@access,A.Access_Codes) != 0) D on H.DEPTID = D.DEPTID
  



-----------------------------------------------------------------------------------
-- details temp table for most returned results sets
-----------------------------------------------------------------------------------
-- select distinct -- REMOVED FOR SQL
select
       'Payroll_Id'    = H.Payroll_Id,
       'Chart_Class'   = H.Chart_Class,
       'Display_Order' = C.Display_Order,
       'Employee_Id'   = H.Employee_Id,
       'Chart_Id'      = H.Chart_Id,
       'ACCOUNT'       = H.ACCOUNT,
       'Earncode_Id'   = H.Earncode_Id,
       'Type_Id'       = C.Type_Id_Budgetx,
       'Period_Id'     = P.Period_Id,
       'Amount'        = convert(bigint,dbo.sumPayrollBudgetByPayrollId2(H.Payroll_Id,C.Type_Id_Budgetx,P.Period_Id)),
       'Id'            = H.Employee_Id+H.Chart_Id+H.Earncode_Id+C.Col_Id,
       'Col_Id'        = C.Col_Id,
       'Disabled'      = case when H.Disabled = 'true' then H.Disabled else C.Disabled end,
       'Enc_Start_Dt'  = space(10),
       'Enc_End_Dt'    = space(10)
  into #detail                
  from #header           H,
       V_AMOUNTCOL       C,
       _PERIOD           P
 where P.Period_Id  = dbo.GetFiscalYearId(C.Fiscal_Year_Offset) 
   and C.Type_Id    = '604'
   and C.Flag1      = 'B'
 union   
-- select distinct -- REMOVED FOR SQL
select
       'Payroll_Id'    = H.Payroll_Id,
       'Chart_Class'   = H.Chart_Class,       
       'Display_Order' = C.Display_Order,
       'Employee_Id'   = H.Employee_Id,
       'Chart_Id'      = H.Chart_Id,
       'ACCOUNT'       = H.ACCOUNT,                
       'Earncode_Id'   = H.Earncode_Id,
       'Type_Id'       = C.Type_Id_Budgetx,
       'Period_Id'     = P.Period_Id,
       'Amount'        = convert(bigint,dbo.sumPayrollActualByPayrollId2(H.Payroll_Id,C.Type_Id_Budgetx,P.Period_Id)),
       'Id'            = H.Employee_Id+H.Chart_Id+H.Earncode_Id+C.Col_Id,
       'Col_Id'        = C.Col_Id,
       'Disabled'      = case when H.Disabled = 'true' then H.Disabled else C.Disabled end,
       'Enc_Start_Dt'  = space(10),
       'Enc_End_Dt'    = space(10)
  from #header           H,
       V_AMOUNTCOL       C,
       _PERIOD           P
 where P.Period_Id  = dbo.GetFiscalYearId(C.Fiscal_Year_Offset) 
   and C.Type_Id    = '604'
   and C.Flag1      = 'A'


-----------------------------------------------------------------------------------
-- #detail: update salary encumbrance start and end dates. (CHG0045226)
-----------------------------------------------------------------------------------
update #detail
   set Enc_Start_Dt = case 
                        when P.CU_ENCM_START_DT_FYTD is NULL or dbo.isempty(P.CU_ENCM_START_DT_FYTD) = 'Y' 
                        then space(10) 
                        else convert(varchar(10),P.CU_ENCM_START_DT_FYTD,102) 
                      end,
       Enc_End_Dt   = case 
                        when P.CU_ENCM_END_DT_FYTD is NULL or dbo.isempty(P.CU_ENCM_END_DT_FYTD) = 'Y' 
                        then space(10) 
                        else convert(varchar(10),P.CU_ENCM_END_DT_FYTD,102) 
                      end
       
  from #detail D left join FS_CHART     C on D.Chart_Id     = C.Chart_Id
                 left join FS_EARNCODE  X on D.Earncode_Id  = X.Earncode_Id,
       PAC_PAYROLL_SUMMARY_DAILY        P
       
 where substring(D.Employee_Id,1,8) = P.EMPLID
   and X.Code                       = P.ERNCD
   and C.BUSINESS_UNIT              = P.BUSINESS_UNIT
   and C.DEPTID                     = P.DEPTID
   and C.BUSINESS_UNIT_PC           = P.PC_BUSINESS_UNIT
   and C.PROJECT_ID                 = P.PROJECT_ID
   and C.ACTIVITY_ID                = P.ACTIVITY_ID
   and C.PROGRAM_CODE               = P.PROGRAM_CODE
   and C.CHARTFIELD1                = P.CHARTFIELD1
   and C.CHARTFIELD2                in ( P.CHARTFIELD2,'#####')
   and C.ACCOUNT                    = P.ACCOUNT
   and C.FUND_CODE                  = P.FUND_CODE
   and substring(C.CLASS_FLD,1,3)   = substring(P.CLASS_FLD,1,3)


/*
if @test = 'Y'
begin

    select 'Chart_Id'    = D.Chart_Id,  
           'Enc_Start_Dt' = case 
                              when P.CU_ENCM_START_DT_FYTD is NULL 
                              then 'n/a' 
                              else convert(varchar(10),P.CU_ENCM_START_DT_FYTD,101) 
                            end,
           'Enc_End_Dt'   = case 
                              when P.CU_ENCM_END_DT_FYTD is NULL 
                              then 'n/a' 
                              else convert(varchar(10),P.CU_ENCM_END_DT_FYTD,101) 
                            end

      from #detail D left join FS_CHART     C on D.Chart_Id     = C.Chart_Id
                     left join FS_EARNCODE  X on D.Earncode_Id  = X.Earncode_Id,
           PAC_PAYROLL_SUMMARY_DAILY        P

     where substring(D.Employee_Id,1,8) = P.EMPLID
       and X.Code                       = P.ERNCD
       and C.BUSINESS_UNIT              = P.BUSINESS_UNIT
       and C.DEPTID                     = P.DEPTID
       and C.BUSINESS_UNIT_PC           = P.PC_BUSINESS_UNIT
       and C.PROJECT_ID                 = P.PROJECT_ID
       and C.ACTIVITY_ID                = P.ACTIVITY_ID
       and C.PROGRAM_CODE               = P.PROGRAM_CODE
       and C.CHARTFIELD1                = P.CHARTFIELD1
       and C.CHARTFIELD2                in ( P.CHARTFIELD2,'#####')
       and C.ACCOUNT                    = P.ACCOUNT
       and C.FUND_CODE                  = P.FUND_CODE
       and substring(C.CLASS_FLD,1,3)   = substring(P.CLASS_FLD,1,3)

end
*/


if @returntype = 'B' goto typeB

--select * from #detail where Employee_Id = '10052619000' and Chart_Id = '002D55P'
delete #detail where Amount is null and Disabled = 'true'




-----------------------------------------------------------------------------------
-- return result set 1
-----------------------------------------------------------------------------------
declare @message01 varchar(3000)

select @message01 = 'This screen displays only transactions for which the user has '+case when @moduleid = 'BT' then 'BUD' else 'PAD' end + ' access.'

if @returntype = 'R'
begin
  select @message01 = @message01+' Only chart strings for which you have BUD create access will be applied.'
end

select 'User_Id'             = @userid,
       'ADMINDEPTID'         = @deptid0,
       'DeptBatchId'         = @deptbatchidx,
       'Rows_Per_Page'       = dbo.GetConfigValue('015'),
       'SubHeader'           = 'Admin Department: '+@deptid0,
       'Access_PD'           = @padaccess,
       'Earncode_Id_Default' = dbo.GetConfigValue('016'),
       'Message01'           = @message01, --'This screen displays only transactions for which the user has '+case when @moduleid = 'BT' then 'BUD' else 'PAD' end + ' access.',
       'Message02'           = @filter


-----------------------------------------------------------------------------------
-- return result set 2: department list
-----------------------------------------------------------------------------------
select 'Description' = rtrim(D.DEPTID)+' - '+DESCR,
       'Id'          = D.DEPTID 
  from V_ACCESS               A,
       PS_ZCU_CF_DEPT_TBL_EXT D   
 where A.User_Id   = @userid
   and A.Module_Id = @accessmodule
   and A.DEPTID0   = @deptid0
   and charindex(@minaccess,A.Access_Codes) != 0
   and A.DEPTID    = D.DEPTID   
 order by 1


if @returntype = 'R'
begin
  goto typeR
end


-----------------------------------------------------------------------------------
-- return result set 3: generic employee list
-----------------------------------------------------------------------------------
-- select distinct -- REMOVED FOR SQL
select
       'Id'          = H.Employee_Id,
       'CSS_Class1'  = convert(char(7),H.Employee_Class),
       'CSS_Class2'  = '',       
       'Sort_By'     = '01' + H.Employee_Name,
       'Deletable'   = 'false', --case when H.Place_Holder='Y' and H.Employee_Class = 'local' then 'true' else 'false' end       
	   'Description' = dbo.alltrim(E.Name + case when S.Active = 'Y' then '' else '['+dbo.alltrim(S.Description)+']' end)+
	                   ' DEPT='+dbo.alltrim(E.ADMINDEPTID)+' ID='+dbo.alltrim(E.Employee_Id)+
					   case when H.Employee_Class != 'local' then '' 
					        when E.Place_Holder='Y' then ''
							when E.Base_Salary=0 then ''
							when S.Status_Id='002' then ''
							when S.Status_Id='E0T' then ''
					        else ' Base Salary=$'+convert(varchar(20),convert(int,round(E.Base_Salary,0)))
						end
  from #header     H,
       FS_EMPLOYEE E,
	   _STATUS     S
 where H.Employee_Id = E.Employee_Id
   and E.Status_Id   = S.Status_Id
 union
select 'Id'          = 'ALLEMPLOYEE',
       'CSS_Class1'  = 'local',
       'CSS_Class2'  = '',       
       'Sort_By'     = '02TOTAL ALL EMPLOYEES EXCLUDING FOREIGN CHART STRING',
       'Deletable'   = 'false', --case when H.Place_Holder='Y' and H.Employee_Class = 'local' then 'true' else 'false' end              
	   'Description' = ''
 order by 4

-----------------------------------------------------------------------------------
-- return result set 4: generic chart list
-----------------------------------------------------------------------------------
select 'Id'          = C.Id,
       'Name'        = C.Name,
       'Description' = C.Description,
       'Title'       = C.Title,
       'CSS_Class1'  = C.CSS_Class1,
       'CSS_Class2'  = C.CSS_Class2,
       'Sort_By'     = C.Sort_By
  from #chart C
 union
select 'Id'          = 'T3#####',
       'Name'        = 'TOTAL',
       'Description' = 'TOTAL',
       'Title'       = '',
       'CSS_Class1'  = 'total',
       'CSS_Class2'  = 'normal',
       'Sort_By'     = 'TOTAL02'
 union
select 'Id'          = 'T2#####',
       'Name'        = 'TOTAL SALARY',
       'Description' = 'TOTAL SALARY',
       'Title'       = '',
       'CSS_Class1'  = 'total',
       'CSS_Class2'  = 'normal',
       'Sort_By'     = 'TOTAL SALARY02'
 order by 
       Description



-----------------------------------------------------------------------------------
-- return result set 5: generic list of earncodes
-----------------------------------------------------------------------------------
-- select distinct -- REMOVED FOR SQL
select
       'Id'          = H.Earncode_Id,
       'Name'        = H.Earncode_Code,       
       'Description' = H.Earncode_Code,
       'Title'       = '',
       'CSS_Class1'  = '',
       'CSS_Class2'  = '',
       'Sort_By'     = H.Earncode_Code
  from #header H       
 union
select 'Id'          = '###',
       'Name'        = '',
       'Description' = '',
       'Title'       = '',
       'CSS_Class1'  = '',
       'CSS_Class2'  = '',
       'Sort_By'     = ''
 order by 
       H.Earncode_Code

-----------------------------------------------------------------------------------
-- return result set 6: column list
-----------------------------------------------------------------------------------
select 'Display_Order' = Display_Order,
       'Id'            = Col_Id,
       'Disabled'      = Disabled,
       'Description'   = Description,
       'Type_Id'       = Type_Id_Budgetx,
       'Period_Id'     = dbo.GetFiscalYearId(Fiscal_Year_Offset)
  from V_AMOUNTCOL
 where Type_Id = '604'
 order by
       Display_Order

-----------------------------------------------------------------------------------
-- return result set 7: payroll header
-----------------------------------------------------------------------------------
--select distinct 
select 'Payroll_Id'    = Payroll_Id,
       'Employee_Id'   = Employee_Id,
       'Chart_Id'      = Chart_Id,
       'Earncode_Id'   = Earncode_Id,       
       'Row_Type'      = Row_Type,
       'Chart_Class'   = Chart_Class,
       'Deletable'     = Deletable,
       'Disabled'      = Disabled
  --     Display_Order,
--       Employee_Name,
  --     Chart_Desc

  from ( -- select distinct -- REMOVED FOR SQL
         select 
                'Payroll_Id'    = H.Payroll_Id,
                'Employee_Id'   = H.Employee_Id,
                'Chart_Id'      = H.Chart_Id,
                'Earncode_Id'   = H.Earncode_Id,       
                'Row_Type'      = convert(varchar(40),'detail '+case when H.Chart_Status_Id = '002' then ' inactive ' else '' end),
                'Chart_Class'   = H.Chart_Class,
                'Deletable'     = 'false',
                'Disabled'      = H.Disabled,
                'Display_Order' = '01',
                'Employee_Name' = H.Employee_Name,
                'Chart_Desc'    = H.Chart_Desc
           from #header    H
          union
         select 'Payroll_Id'    = 'T2#####',      -- salary total by employee
                'Employee_Id'   = H.Employee_Id,
                'Chart_Id'      = 'T2#####',
                'Earncode_Id'   = '###',
                'Row_Type'      = 'total',
                'Chart_Class'   = 'normal',
                'Deletable'     = 'false',
                'Disabled'      = 'true',
                'Display_Order' = '03',                
                'Employee_Name' = H.Employee_Name,
                'Chart_Desc'    = H.Chart_Desc
           from #header    H 
          union
         select 'Payroll_Id'    = 'T3#####',      -- grand total by employee
                'Employee_Id'   = H.Employee_Id,
                'Chart_Id'      = 'T3#####',
                'Earncode_Id'   = '###',
                'Row_Type'      = 'total',
                'Chart_Class'   = 'normal',
                'Deletable'     = 'false',
                'Disabled'      = 'true',
                'Display_Order' = '02',                
                'Employee_Name' = H.Employee_Name,
                'Chart_Desc'    = H.Chart_Desc
           from #header    H 
          union
         select 'Payroll_Id'    = 'T2#####',      
                'Employee_Id'   = 'ALLEMPLOYEE',
                'Chart_Id'      = H.Chart_Id,
                'Earncode_Id'   = '###',
                'Row_Type'      = 'detail',
                'Chart_Class'   = H.Chart_Class,
                'Deletable'     = 'false',
                'Disabled'      = 'true',
                'Display_Order' = '11',                
                'Employee_Name' = '',
                'Chart_Desc'    = H.Chart_Desc
           from #header    H 
          where H.Chart_Class = 'local'           
          union
         select 'Payroll_Id'    = 'T2#####',
                'Employee_Id'   = 'ALLEMPLOYEE',
                'Chart_Id'      = 'T2#####',
                'Earncode_Id'   = '###',
                'Row_Type'      = 'total',
                'Chart_Class'   = 'normal',
                'Deletable'     = 'false',
                'Disabled'      = 'true',
                'Display_Order' = '13',                
                'Employee_Name' = '',
                'Chart_Desc'    = ''
          union
         select 'Payroll_Id'    = 'T3#####',
                'Employee_Id'   = 'ALLEMPLOYEE',
                'Chart_Id'      = 'T3#####',
                'Earncode_Id'   = '###',
                'Row_Type'      = 'total',
                'Chart_Class'   = 'normal',
                'Deletable'     = 'false',
                'Disabled'      = 'true',
                'Display_Order' = '12',                
                'Employee_Name' = '',
                'Chart_Desc'    = ''
       ) S                
 order by 
       Display_Order,
       Employee_Name,
       Chart_Desc
       


-----------------------------------------------------------------------------------
-- return result set 8: payroll detail
-----------------------------------------------------------------------------------
select 'Payroll_Id'    = S.Payroll_Id,
       'Display_Order' = S.Display_Order,
       'Employee_Id'   = S.Employee_Id,
       'Chart_Id'      = S.Chart_Id,
       'Earncode_Id'   = S.Earncode_Id,
       'Type_Id'       = S.Type_Id,
       'Period_Id'     = S.Period_Id,
--     'Amount'        = case when S.Amount is null then 0 else S.Amount end,
       'Amount'        = S.Amount,
       -- extensions
       'AmountStr'     = case when S.Amount is null then 'null' else convert(char(15),Amount) end,
--     'Disabled'      = S.Disabled,
       'Disabled'      = case 
                           when S.Disabled  = 'true'                   then 'true'
--                         when H.Disabled  = 'true'                   then 'true'
                           when S.Col_Id = '60405' and @lockout0 = 'Y' then 'true' 
                           when S.Col_Id = '60406' and @lockout1 = 'Y' then 'true'                            
                           when S.Col_Id = '60407' and @lockout2 = 'Y' then 'true'    
                           when S.Col_Id = '60408' and @lockout3 = 'Y' then 'true' 
                                                                       else S.Disabled
                         end,                                                                       
       'Id'            = S.Id       
  from ( select Payroll_Id,   -- CHG0045226: replaced 'select *' in first select
                Chart_Class,
                Display_Order,
                Employee_Id,
                Chart_Id,
                ACCOUNT,
                Earncode_Id,
                Type_Id,
                Period_Id,
                Amount,
                Id,
                Col_Id,
                Disabled
           from #detail
          union
         select 'Payroll_Id'    = 'T2#####',
                'Chart_Class'   = 'local',
                'Display_Order' = max(D.Display_Order), 
                'Employee_Id'   = D.Employee_Id,
                'Chart_Id'      = 'T2#####',
                'ACCOUNT'       = '#####',
                'Earncode_Id'   = '###',
                'Type_Id'       = D.Type_Id,
                'Period_Id'     = max(D.Period_Id),
                'Amount'        = sum(D.Amount),
--              'Amount'        = sum(case when D.Amount is null then 0 else D.Amount end),                
                'Id'            = D.Employee_Id+'T2#####'+'###'+D.Col_Id,
                'Col_Id'        = D.Col_Id,
                'Disabled'      = 'true'
           from #detail D
          where D.ACCOUNT not in ('59010','59020')
          group by
                D.Employee_Id,
                D.Type_Id,
                D.Period_Id,
                D.Col_Id
         having sum(D.Amount) is not null
          union                
         select 'Payroll_Id'    = 'T3#####',
                'Chart_Class'   = 'local',         
                'Display_Order' = max(D.Display_Order), 
                'Employee_Id'   = D.Employee_Id,
                'Chart_Id'      = 'T3#####',
                'ACCOUNT'       = '#####',
                'Earncode_Id'   = '###',
                'Type_Id'       = D.Type_Id,
                'Period_Id'     = max(D.Period_Id),
                'Amount'        = sum(D.Amount),
--              'Amount'        = sum(case when D.Amount is null then 0 else D.Amount end),                
                'Id'            = D.Employee_Id+'T3#####'+'###'+D.Col_Id,
                'Col_Id'        = D.Col_Id,
                'Disabled'      = 'true'
           from #detail D
          group by
                D.Employee_Id,
                D.Type_Id,
                D.Period_Id,
                D.Col_Id
         having sum(D.Amount) is not null
          union                
         select 'Payroll_Id'    = 'T2#####',
                'Chart_Class'   = 'local',         
                'Display_Order' = max(D.Display_Order), 
                'Employee_Id'   = 'ALLEMPLOYEE',
                'Chart_Id'      = D.Chart_Id,
                'ACCOUNT'       = '#####',
                'Earncode_Id'   = '###',
                'Type_Id'       = '###',
                'Period_Id'     = max(D.Period_Id),
                'Amount'        = sum(D.Amount),
                'Id'            = 'ALLEMPLOYEE'+D.Chart_Id+'###'+D.Col_Id,
                'Col_Id'        = D.Col_Id,
                'Disabled'      = 'true'
           from #detail D
          where D.Chart_Class = 'local'
--          and D.ACCOUNT not in ('59010','59020')           
          group by
                D.Chart_Id,
                D.Type_Id,
                D.Period_Id,
                D.Col_Id
         having sum(D.Amount) is not null
          union                
         select 'Payroll_Id'    = 'T2#####',
                'Chart_Class'   = 'local',         
                'Display_Order' = max(D.Display_Order), 
                'Employee_Id'   = 'ALLEMPLOYEE',
                'Chart_Id'      = 'T2#####',
                'ACCOUNT'       = '#####',
                'Earncode_Id'   = '###',
                'Type_Id'       = '###',
                'Period_Id'     = max(D.Period_Id),
                'Amount'        = sum(D.Amount),
                'Id'            = 'ALLEMPLOYEE'+'T2#####'+'###'+D.Col_Id,
                'Col_Id'        = D.Col_Id,
                'Disabled'      = 'true'
           from #detail D
          where D.ACCOUNT not in ('59010','59020')                      
            and D.Chart_Class = 'local'          
          group by
                D.Type_Id,
                D.Period_Id,
                D.Col_Id
         having sum(D.Amount) is not null
          union                
         select 'Payroll_Id'    = 'T3#####',
                'Chart_Class'   = 'local',         
                'Display_Order' = max(D.Display_Order), 
                'Employee_Id'   = 'ALLEMPLOYEE',
                'Chart_Id'      = 'T3#####',
                'ACCOUNT'       = '#####',
                'Earncode_Id'   = '###',
                'Type_Id'       = '###',
                'Period_Id'     = max(D.Period_Id),
                'Amount'        = sum(D.Amount),
                'Id'            = 'ALLEMPLOYEE'+'T3#####'+'###'+D.Col_Id,
                'Col_Id'        = D.Col_Id,
                'Disabled'      = 'true'
           from #detail D
          where D.Chart_Class = 'local'           
          group by
                D.Type_Id,
                D.Period_Id,
                D.Col_Id
         having sum(D.Amount) is not null
         
        ) S                
 order by
       Employee_Id,
       Chart_Id,
       Earncode_Id,
       Display_Order

cleanup:
drop table #detail
drop table #header
drop table #chart


endproc:
if @errno > 0
begin
  RAISERROR(@errmsg, 16, 1)
end

return




-----------------------------------------------------------------------------------
-- type R is the review screen or pre-apply 
-----------------------------------------------------------------------------------
typeR:
delete #chart
  from #chart                 T,
       FS_CHART               C,
       PS_ZCU_CF_ACCT_TBL_EXT A
 where T.Chart_Id    = C.Chart_Id
   and C.ACCOUNT     = A.ACCOUNT
   and A.Payroll_Flag not in ('Y','V')



select 'Employee_Id' = 'R01########',
       'Description' = '1. PROPOSED DIRECT ACTIVITY'
  into #emp
 union         
select 'Employee_Id' = 'R02########',
       'Description' = '2. CURRENT DIRECT ACTIVITY'
 union         
select 'Employee_Id' = 'R03########',
       'Description' = '3. CHANGE TO ESTIMATE'


-----------------------------------------------------------------------------------
-- return result set 3: generic employee list
-----------------------------------------------------------------------------------
select 'Id'          = E.Employee_Id,
       'CSS_Class1'  = 'local',
       'CSS_Class2'  = '',
       'Sort_By'     = '02'+E.Description,
       'Deletable'   = 'false', --case when H.Place_Holder='Y' and H.Employee_Class = 'local' then 'true' else 'false' end    
	   'Description' = ''          
  from #emp E       
 order by E.Description
 

-----------------------------------------------------------------------------------
-- return result set 4: generic chart list 
-----------------------------------------------------------------------------------
-- select distinct -- REMOVED FOR SQL
select
       'Chart_Id'   = C.Id,
       'Period_Id'  = P.Period_Id,
       'Type_Id'    = T.Type_Id,
--     'Budget_PW'  = isnull(dbo.sumPayrollBudgetByChartId2(C.Id,T.Type_Id,P.Period_Id),0)              
--     'Budget_DA'  = isnull(dbo.sumBudgetByChartId        (C.Id,T.Type_Id,P.Period_Id,'#'),0),
       'Budget_PWx' = dbo.sumPayrollBudgetByChartId2(C.Id,T.Type_Id,P.Period_Id),
       'Budget_DAx' = dbo.sumBudgetByChartId        (C.Id,T.Type_Id,P.Period_Id,'#'),
       'Budget_PW'  = convert(bigint,null),       
       'Budget_DA'  = convert(bigint,null),
       'Included'   = 'N'
  into #diff       
  from #chart  C,
       _PERIOD P,
       _TYPE   T
 where P.Period_Id in (@periodid0,@periodid1,@periodid2,@periodid3)
   and T.Type_Id   in ('051','999')


update #diff
   set Budget_DA = isnull(Budget_DAx,0),
       Budget_PW = isnull(Budget_PWx,0)

if @apply0 = 'N'
begin
  delete #diff where Budget_DA = Budget_PW
end
else begin
  --update #diff set Included = 'Y' where Budget_PWx is not null and Budget_DAx is null
  update #diff
     set Included = 'Y'
    from #diff             D,
         FS_PAYROLL_HEADER H,
         FS_PAYROLL_BUDGET B
   where D.Chart_Id   = H.Chart_Id
     and H.Payroll_Id = B.Payroll_Id         
     and B.Period_Id  = D.Period_Id
     and B.Transaction_Id101 = '#0000002'
  
  update #diff set Included = 'Y' where Included = 'N' and Budget_PW != Budget_DA  
  update #diff set Included = 'N' where Type_Id   != dbo.getTypeIdBudget(Period_Id,@quarter)

  delete #diff where Included = 'N'
end

/*
if not exists (select 1 from #diff)
begin
  select @errno  = 51001
  select @errmsg = 'No changes to apply. (code 72021)'

  goto endproc
end
*/
delete #header where Chart_Class = 'foreign'
delete #chart  where CSS_Class2  = 'foreign'




/*
select top 2000 Chart_Id
  into #top           
  from ( select distinct
                C.Chart_Id
           from #diff C) S
  order by 
        Chart_Id


delete #diff where Chart_Id not in (select Chart_Id from #top)
drop table #top
*/           

-- select distinct -- REMOVED FOR SQL
select
       C.* 
  from #chart  C,
       #diff   D
 where C.Id = D.Chart_Id
-- and Budget_DA != Budget_PW
 order by C.Name   


-----------------------------------------------------------------------------------
-- return result set 5: generic list of eancodes
-----------------------------------------------------------------------------------
select 'Id'          = '###',
       'Name'        = '',
       'Description' = '',
       'Title'       = '',
       'CSS_Class1'  = '',
       'CSS_Class2'  = '',
       'Sort_By'     = ''

-----------------------------------------------------------------------------------
-- return result set 6: column list
-----------------------------------------------------------------------------------
select 'Display_Order' = Display_Order,
       'Id'            = Col_Id,
       'Disabled'      = Disabled,
       'Description'   = Description,
       'Type_Id'       = Type_Id_Budgetx,
       'Period_Id'     = dbo.GetFiscalYearId(Fiscal_Year_Offset)
  from V_AMOUNTCOL
 where Type_Id = '604'
-- and Type_Id_Budgetx in ('051','999')
 order by
       Display_Order

-----------------------------------------------------------------------------------
-- return result set 7: column list
-----------------------------------------------------------------------------------
-- select distinct -- REMOVED FOR SQL
select 
       'Payroll_Id'    = '#######',
       'Employee_Id'   = E.Employee_Id,
       'Chart_Id'      = C.Chart_Id,
       'Earncode_Id'   = '###',
       'Row_Type'      = 'detail',
       'Chart_Class'   = 'local',
       'Deletable'     = 'false',
       'Disabled'      = 'true'
  from #emp    E,
       #chart  C,
       #diff   D
 where C.Id        = D.Chart_Id
-- and D.Budget_DA != Budget_PW
 order by 
       E.Employee_Id,
       C.Description


-----------------------------------------------------------------------------------
-- return result set 8: detail list
-----------------------------------------------------------------------------------
select 'Payroll_Id'    = '#######',
       'Display_Order' = S.Display_Order,
       'Employee_Id'   = S.Employee_Id,
       'Chart_Id'      = S.Chart_Id,
       'Earncode_Id'   = '###',
       'Type_Id'       = S.Type_Id,
       'Period_Id'     = S.Period_Id,
       'Amount'        = convert(bigint,S.Amount),
       'AmountStr'     = case when S.Amount is null then 'null' else convert(char(15),Amount) end,
       'Disabled'      = 'true',
       'Id'            = S.Employee_Id+S.Chart_Id+'###'+S.Col_Id
  from ( select 'Display_Order' = K.Display_Order,
                'Employee_Id'   = E.Employee_Id,
                'Chart_Id'      = C.Chart_Id,
                'Type_Id'       = K.Type_Id_Budgetx,
                'Period_Id'     = D.Period_Id,
                'Amount'        = case
                                    when E.Employee_Id = 'R01########' then D.Budget_PW
                                    when E.Employee_Id = 'R02########' then D.Budget_DAx
                                    when E.Employee_Id = 'R03########' then D.Budget_PW-D.Budget_DA                           
                                                                       else 0
                                  end,
                'Col_Id'        = K.Col_Id                                                              
           from V_AMOUNTCOL K,
                #emp       E,
                #chart     C,
                #diff      D
          where K.Type_Id        = '604'  
            and K.Flag1          = 'B'
            and C.Id             = D.Chart_Id
--          and D.Budget_DA     != Budget_PW
            and K.Type_Id_Budgetx = D.Type_Id
            and D.Period_Id      = dbo.GetFiscalYearId(K.Fiscal_Year_Offset) 
       ) S            
   
 order by 
       S.Employee_Id,
       S.Display_Order



drop table #diff
drop table #emp

goto cleanup
return

-----------------------------------------------------------------------------------
-- type B is the batch
-----------------------------------------------------------------------------------
typeB:
begin

  if @earncodeid = '###'
  begin
  
    select @earncodeid = '%'
    
  end

  delete #detail

    from FS_CHART               C,
         PS_ZCU_CF_ACCT_TBL_EXT A

   where C.Chart_Id     = #detail.Chart_Id
     and A.ACCOUNT      = C.ACCOUNT
     and A.Payroll_Flag not in ('Y','V')


  if @entrytype = '2'
  begin
  
    delete #detail
    
      from FS_CHART               C,
           PS_ZCU_CF_ACCT_TBL_EXT A
      
     where C.Chart_Id     = #detail.Chart_Id
       and A.ACCOUNT      = C.ACCOUNT
       and A.Payroll_Flag != 'Y'
  
  end 


  declare @creatorUNI  char(08)
  declare @today       varchar(20)

  select @creatorUNI    = dbo.GetUserCode(@userid)
  select @today         = dbo.ttoc(getDate(),901)


/************* For Reference:

  create table #grandTableBTGPW
  (
    Column00 varchar(08),      -- row format
    Column01 bigint NULL,      -- Posted BudYR0
    Column02 bigint NULL,      -- Posted BudYR1
    Column03 bigint NULL,      -- Posted BudYR2
    Column04 bigint NULL,      -- Posted BudYR3

    Column05 bigint NULL,      -- Not applied Payroll BudYR0
    Column06 bigint NULL,      -- Not applied Payroll BudYR1
    Column07 bigint NULL,      -- Not applied Payroll BudYR2
    Column08 bigint NULL,      -- Not applied Payroll BudYR3

    Column09 char(7) NULL,     -- Chart Id

    Column10 varchar(11) NULL, -- Employee ID
    Column11 varchar(20) NULL, -- Emp_Name
    Column12 varchar(20) NULL, -- Employee Record Status
    Column13 varchar(10) NULL, -- PROJECT_ID
    Column14 varchar(30) NULL, -- DESCR 
    Column15 varchar(10) NULL, -- ACCOUNT
    Column16 varchar(30) NULL, -- DESCR 
    Column17 varchar(10) NULL, -- BUSINESS_UNIT
    Column18 varchar(30) NULL, -- DESCR
    Column19 varchar(10) NULL, -- DEPTID
    Column20 varchar(30) NULL, -- DESCR
    Column21 varchar(10) NULL, -- FUND_CODE
    Column22 varchar(30) NULL, -- DESCR
    Column23 varchar(10) NULL, -- BUSINESS_UNIT_PC
    Column24 varchar(10) NULL, -- ACTIVITY_ID
    Column25 varchar(30) NULL, -- DESCR
    Column26 varchar(10) NULL, -- PROGRAM_CODE (Initiative)
    Column27 varchar(30) NULL, -- DESCR
    Column28 varchar(10) NULL, -- CHARTFIELD1 (Segment)
    Column29 varchar(30) NULL, -- DESCR
    Column30 varchar(10) NULL, -- CHARTFIELD2 (Site)
    Column31 varchar(30) NULL, -- DESCR
    Column32 varchar(10) NULL, -- CLASS_FLD (Function)
    Column33 varchar(30) NULL, -- DESCR
    Column34 varchar(10) NULL, -- Earncode_Code
    Column35 varchar(10) NULL, -- HR Admin Department
    Column36 varchar(10) NULL, -- DESCR

    Column37 bigint NULL,      -- Base Salary
    Column38 varchar(30) NULL, -- EAdmin_Position_Description
    Column39 char(01)    NULL, -- FT/PT Status

    Column40 bigint NULL,      -- Prior FY Original Budget

    Column41 bigint NULL,      -- Current Year OB
    Column42 bigint NULL,      -- Prior FY Salary #071   
    Column43 bigint NULL,      -- YTD Salary
    Column44 bigint NULL,      -- Encumbered Salary #072 (PAC)
    Column45 bigint NULL,      -- Total Salary #073 (PAC)
    Column46 bigint NULL,      -- FY0 CE - Total Salary (variance)

-- (CHG0045226)
    Column47 varchar(10) NULL, -- Salary Encumbrance Start Date  
    Column48 varchar(10) NULL, -- Salary Encumbrance End Date       

    Column49 bigint NULL,      -- Prior FY Fringe #061  
    Column50 bigint NULL,      -- YTD Fringe        
    Column51 bigint NULL,      -- Encumbered Fringe 
    Column52 bigint NULL,      -- Total Fringe
    
    Column53 varchar(20) NULL, -- ICR Phase 1 Rate

    Column54 varchar(20) NULL, -- Fringe Rate
    Column55 char(06)    NULL, -- Deduction Code

    Column56 char(07) NULL,    -- Division
    Column57 char(07) NULL,    -- Academic Dept
    Column58 char(07) NULL,    -- Sector Rollup
    Column59 char(07) NULL,    -- School Admin Unit

    Column60 varchar(10) NULL, -- View Only
    Column61 varchar(10) NULL, -- @creatorUNI
    Column62 varchar(20) NULL, -- @today
    Chart_Id char(07)          -- Chart_Id
  )

****************************/

  declare @budget1type      char(3)
  select @budget1type       = '051'
  if dbo.getFiscalQuarter() = 'Q4'
  begin

    update #detail
       set Type_Id          = '999'
     where Col_Id           = '60406'

    select @budget1type     = '999'

  end   


  select 
     'Row_Format'  = 'XXXXXXXX',   -- row format
    
    -- Payroll amounts (Posted & unPosted):
    'Column01'  = sum(case when D.Period_Id = @periodid0 and D.Type_Id = '999' then convert(bigint,D.Amount) else convert(bigint,NULL) end),
    'Column02'  = sum(case when D.Period_Id = @periodid1 and D.Type_Id = @budget1type then convert(bigint,D.Amount) else convert(bigint,NULL) end),  -- need to check this logic for quarter4
    'Column03'  = sum(case when D.Period_Id = @periodid2 and D.Type_Id = '051' then convert(bigint,D.Amount) else convert(bigint,NULL) end),
    'Column04'  = sum(case when D.Period_Id = @periodid3 and D.Type_Id = '051' then convert(bigint,D.Amount) else convert(bigint,NULL) end),

    -- Unapplied budget amounts: 
    'Column05'  = convert(bigint,dbo.sumUnappliedPRBudgetByPRId(D.Payroll_Id, @periodid0)),
    'Column06'  = convert(bigint,dbo.sumUnappliedPRBudgetByPRId(D.Payroll_Id, @periodid1)),
    'Column07'  = convert(bigint,dbo.sumUnappliedPRBudgetByPRId(D.Payroll_Id, @periodid2)),
    'Column08'  = convert(bigint,dbo.sumUnappliedPRBudgetByPRId(D.Payroll_Id, @periodid3)),

--    'Column09' D.Chart_Id,
    'Column10'  = D.Employee_Id,
    'Column11'  = max(E.Name),

--(CHG0053987)
    'Column12'  = space(15),                 -- Employee Record Status (Description2)
    
    'Column13'  = max(C.PROJECT_ID),
    'Column14'  = convert(varchar(30),NULL), -- DESCR
    'Column15'  = max(C.ACCOUNT),
    'Column16'  = convert(varchar(30),NULL), -- DESCR
    'Column17'  = max(C.BUSINESS_UNIT),
    'Column18'  = convert(varchar(30),NULL), -- DESCR
    'Column19'  = max(C.DEPTID),
    'Column20'  = convert(varchar(30),NULL), -- DESCR
    'Column21'  = max(C.FUND_CODE),
    'Column22'  = convert(varchar(30),NULL), -- DESCR
    'Column23'  = max(C.BUSINESS_UNIT_PC),
    'Column24'  = max(C.ACTIVITY_ID),
    'Column25'  = convert(varchar(30),NULL), -- DESCR
    'Column26'  = max(C.PROGRAM_CODE),
    'Column27'  = convert(varchar(30),NULL), -- DESCR
    'Column28'  = max(C.CHARTFIELD1),        -- (Segment)
    'Column29'  = convert(varchar(30),NULL), -- DESCR
    'Column30'  = max(case when C.CHARTFIELD2 like '#%' then '' else C.CHARTFIELD2 end),-- (Site)
    'Column31'  = convert(varchar(30),NULL), -- DESCR                  
    'Column32'  = max(C.CLASS_FLD),          -- (Function)
    'Column33'  = convert(varchar(30),NULL), -- DESCR
    'Column34'  = max(X.Code),
    'Column35'  = max(E.ADMINDEPTID),        --HR Admin Department,
    'Column36'  = convert(varchar(30),NULL), -- DESCR 
    'Column37'  = max(convert(integer,E.Base_Salary)),-- Base Salary,
    'Column38'  = max(P.Position_Title),
    'Column39'  = max(E.FTPT_Position_Status_Code),   -- FT/PT Status,

    'Column40'  = convert(int,dbo.sumPayrollBudgetByPayrollId2(D.Payroll_Id,'051',@periodidp1)), -- Prior FY Original Budget

    'Column41'  = sum(case when D.Period_Id = @periodid0 and D.Type_Id = '051' then convert(bigint,D.Amount) else convert(bigint,NULL) end),         
    'Column42'  = sum(case when D.Col_Id = '60414' then convert(bigint,D.Amount) else convert(bigint,NULL) end), -- Prior FY Salary #071
    'Column43'  = sum(case when D.Col_Id = '60401' then convert(bigint,D.Amount) else convert(bigint,NULL) end), -- YTD Salary
    'Column44'  = sum(case when D.Col_Id = '60402' then convert(bigint,D.Amount) else convert(bigint,NULL) end), -- Encumbered Salary #072 (PAC)
    'Column45'  = sum(case when D.Col_Id = '60403' then convert(bigint,D.Amount) else convert(bigint,NULL) end), -- Total Salary #073 (PAC)
    'Column46'  = convert(bigint,NULL),      -- FY0 CE - Total Salary (variance)

-- (CHG0045226)
    'Column47'  = max(D.Enc_Start_Dt),       -- Salary Encumbrance Start Date 
    'Column48'  = max(D.Enc_End_Dt),         -- Salary Encumbrance End Date 

    'Column49'  = sum(case when D.Col_Id = '60415' then convert(bigint,D.Amount) else convert(bigint,NULL) end), -- Prior FY Fringe #061
    'Column50'  = sum(case when D.Col_Id = '60411' then convert(bigint,D.Amount) else convert(bigint,NULL) end), -- YTD Fringe
    'Column51'  = sum(case when D.Col_Id = '60412' then convert(bigint,D.Amount) else convert(bigint,NULL) end), -- Encumbered Fringe
    'Column52'  = sum(case when D.Col_Id = '60413' then convert(bigint,D.Amount) else convert(bigint,NULL) end), -- Total Fringe #074
    'Column53'  = convert(varchar(20),NULL), -- ICR Phase 1 Rate

    'Column54'  = convert(varchar(20),NULL), -- Fringe Rate
    'Column55'  = dbo.getDEDCD(D.Payroll_Id,'021'),   -- Deduction Code
    
    'Column56'  = convert(char(07),NULL),    -- Division
    'Column57'  = convert(char(07),NULL),    -- Academic Dept
    'Column58'  = convert(char(07),NULL),    -- Sector Rollup
    'Column59'  = convert(char(07),NULL),    -- School Admin Unit

    'Column60'  = max(case 
                        when C.Status_Id = '005'  then 'Y'
                        when C.Status_Id = '007'  then 'Y'
                        when dbo.canEditAccount(C.ACCOUNT,'104') = 'Y' 
                             and dbo.isValidEarnCodeAccount(X.Code,C.ACCOUNT,'N') = 'Y' 
                                                  then 'N'
                                                  else 'Y' 
                      end),                  -- View Only,
--    'Column61'  = @creatorUNI,
--    'Column62 '  = @today,
    'Chart_Id'  = D.Chart_Id,
    'Payroll_Id'= D.Payroll_Id,
    'Alloc_Type'= '###'
    
  into #grandTableBTGPW
  from  
    #detail                 D,
    FS_CHART                C,
    FS_EMPLOYEE             E left join CU_PAF_ORIGINAL P on (rtrim(E.PS_Employee_ID) = P.PS_Employee_ID and E.Employee_Record_Number = P.Employee_Record_Number),
    FS_EARNCODE             X
    
  where  D.Chart_Id     = C.Chart_Id
    and  D.Earncode_Id  = X.Earncode_Id
    and  X.Earncode_Id  like rtrim(@earncodeid)
    and  D.Employee_Id  = E.Employee_Id
 group by 
    D.Payroll_Id,
    D.Employee_Id,
    D.Chart_Id,
    D.Earncode_Id



  -----------------------------------------------------------------------------
  -- (CHG0053987) update the Employee Record Status in each row
  -----------------------------------------------------------------------------
  update #grandTableBTGPW
     set Column12 = rtrim(st.Description2)

    from #grandTableBTGPW   gt1,
         FS_EMPLOYEE        fe,
         _STATUS            st
  
   where gt1.Column10   = fe.Employee_Id      
     and fe.Status_Id   = st.Status_Id
     and 'FS_EMPLOYEE'  = st.Table_Name
  
  
  -----------------------------------------------------------------------------
  -- update the Alloc_Type in each row
  -----------------------------------------------------------------------------
  update #grandTableBTGPW
     set Alloc_Type   = case
                          when dbo.isStringWithinRange('415',pa.ZCU_RATE_BASE) = 'Y' then '###'  -- NOFA
                          when rtrim(pr.PROJECT_TYPE) = 'SPIND'                      then '###'  -- SPIND is not eligible
                          when dbo.isStringWithinRange('426',gt1.Column21) = 'Y'     then '252' 
                                                                                     else '251' 
                        end

    from #grandTableBTGPW         gt1,
         V_PS_ZCU_PRJ_ACT_TBL_EXT pa,
         V_PS_ZCU_CF_PROJ_TBL_EXT pr

   where gt1.Column13   = pa.PROJECT_ID      
     and gt1.Column24   = pa.ACTIVITY_ID     
     and pa.PROJECT_ID  = pr.PROJECT_ID      


  -----------------------------------------------------------------------------
  -- update the rate in each row
  -----------------------------------------------------------------------------
  select S.*,
         dbo.getRate2(S.Alloc_Type,@periodid0,S.BUSINESS_UNIT_PC,S.PROJECT_ID,S.ACTIVITY_ID) as Rate
    into #rate    
    from ( select distinct 
            C.BUSINESS_UNIT_PC,
            C.PROJECT_ID,
            C.ACTIVITY_ID,
            G.Alloc_Type
             from #grandTableBTGPW G,
                  FS_CHART          C
            where G.Alloc_Type != '###'
              and G.Chart_Id    = C.Chart_Id
         ) S


  update #grandTableBTGPW
     set Column53 = convert(varchar(20),R.Rate)
    from #rate   R
   where '###'             != #grandTableBTGPW.Alloc_Type
     and R.BUSINESS_UNIT_PC = #grandTableBTGPW.Column23
     and R.PROJECT_ID       = #grandTableBTGPW.Column13
     and R.ACTIVITY_ID      = #grandTableBTGPW.Column24


  drop table #rate



  -----------------------------------------------------------------------------
  -- update the fringe rate & deduction code in each row -- CHG0041510
  -----------------------------------------------------------------------------
  update #grandTableBTGPW
     set Column54 = convert(varchar(20),r.Rate)
    from FS_RATE  r
   where #grandTableBTGPW.Column55 != '######'
     and #grandTableBTGPW.Column55  = r.Code
     and @periodid0                 = r.Period_Id
     and '298'                      = r.Type_Id



  update #grandTableBTGPW
     set Column55 = case
                      when Column55 ='######'
                      then convert(char(6),NULL)
                      else Column55
                    end

  -----------------------------------------------------------------------------
  -- update the departmental heirarchy fields -- CHG0042674
  -- (Do level 4 in a separate update to improve performance.)
  -----------------------------------------------------------------------------
    update #grandTableBTGPW
     set Column56 = t2.DEPTID,  -- Division
         Column57 = t3.DEPTID,  -- Academic Dept
         Column58 = t4.DEPTID   -- Sector Rollup

    from FS_DEPTTREE t1,
         FS_DEPTTREE t2,
         FS_DEPTTREE t3,
         FS_DEPTTREE t4

   where 8                          = t1.TREE_LEVEL
     and #grandTableBTGPW.Column19  = t1.DEPTID
     and 7                          = t2.TREE_LEVEL
     and t1.DEPTID0                 = t2.DEPTID
     and 6                          = t3.TREE_LEVEL
     and t2.DEPTID0                 = t3.DEPTID
     and 5                          = t4.TREE_LEVEL
     and t3.DEPTID0                 = t4.DEPTID

/*
  select count(*) from #grandTableBTGPW
  drop table #header
  drop table #detail
  drop table #grandTableBTGPW  
  return
*/

    update #grandTableBTGPW
     set Column59 = t5.DEPTID   -- School Admin Unit

    from FS_DEPTTREE t4,
         FS_DEPTTREE t5

   where 5                          = t4.TREE_LEVEL
     and #grandTableBTGPW.Column58  = t4.DEPTID
     and 4                          = t5.TREE_LEVEL
     and t4.DEPTID0                 = t5.DEPTID

  -----------------------------------------------------------------------------
  -- update the chartfield descriptions in each row
  -----------------------------------------------------------------------------
  
  update #grandTableBTGPW set Column14 = P.DESCR  from #grandTableBTGPW G,PS_ZCU_CF_PROJ_TBL_EXT P  where G.Column13 = P.PROJECT_ID         
  update #grandTableBTGPW set Column16 = A.DESCR  from #grandTableBTGPW G,PS_ZCU_CF_ACCT_TBL_EXT A  where G.Column15 = A.ACCOUNT
  update #grandTableBTGPW set Column18 = B.DESCR  from #grandTableBTGPW G,PS_ZCU_CF_BU_TBL_EXT   B  where G.Column17 = B.BUSINESS_UNIT
  update #grandTableBTGPW set Column20 = D.DESCR  from #grandTableBTGPW G,PS_ZCU_CF_DEPT_TBL_EXT D  where G.Column19 = D.DEPTID
  
  update #grandTableBTGPW set Column22 = F.DESCR  from #grandTableBTGPW G,PS_ZCU_CF_FUND_TBL_EXT F  where G.Column21 = F.FUND_CODE
  update #grandTableBTGPW set Column25 = PA.DESCR from #grandTableBTGPW G,PS_ZCU_PRJ_ACT_TBL_EXT PA where G.Column13 = PA.PROJECT_ID and G.Column23 = PA.ACTIVITY_ID
  update #grandTableBTGPW set Column27 = I.DESCR  from #grandTableBTGPW G,PS_ZCU_CF_INIT_TBL_EXT I  where G.Column26 = I.PROGRAM_CODE
  update #grandTableBTGPW set Column29 = S.DESCR  from #grandTableBTGPW G,PS_ZCU_CF_SEG_TBL_EXT  S  where G.Column28 = S.CHARTFIELD1
  
  update #grandTableBTGPW set Column31 = S.DESCR  from #grandTableBTGPW G,PS_ZCU_CF_SITE_TBL_EXT S  where G.Column30 = S.CHARTFIELD2
  update #grandTableBTGPW set Column33 = F.DESCR  from #grandTableBTGPW G,PS_ZCU_CF_FUNC_TBL_EXT F  where G.Column32 = F.CLASS_FLD
  update #grandTableBTGPW set Column36 = D.DESCR  from #grandTableBTGPW G,PS_ZCU_CF_DEPT_TBL_EXT D  where G.Column35 = D.DEPTID


  update #grandTableBTGPW
     set Column46   = isnull(Column45,0) - isnull(Column01,0)   -- Variance

  -- row format
  update #grandTableBTGPW
     set Row_Format = case 
                        when C.Status_Id = '002'          then 'IN'
                        when H.Chart_Class = 'foreign'    then 'NR'
                        when H.Employee_Class = 'foreign' then 'BR' 
                        else G.Row_Format 
                      end,
         Column37   = case 
                        when H.Employee_Class = 'foreign' then NULL 
                        else G.Column37 
                      end
    from #grandTableBTGPW    G,
         #header        H,
         FS_CHART       C
   where H.Employee_Id  = G.Column10
     and H.Chart_Id     = G.Chart_Id
     and C.Chart_Id     = G.Chart_Id

    
  -----------------------------------------------------------------------------
  -- result set: payroll batch download
  -----------------------------------------------------------------------------
  select 
    'Column00'  = Row_Format,
    Column01,
    Column02,
    Column03,
    Column04,
    Column05,
    Column06,
    Column07,
    Column08,
    'Column09'  = Chart_Id,
    Column10,
    Column11,
    Column12,
    Column13,
    Column14,
    Column15,
    Column16,
    Column17,
    Column18,
    Column19,
    Column20,
    Column21,
    Column22,
    Column23,
    Column24,
    Column25,
    Column26,
    Column27,
    Column28,
    Column29,
    Column30,
    Column31,
    Column32,
    Column33,
    Column34,
    Column35,
    Column36,
    Column37,
    Column38,
    Column39,
    Column40,
    Column41,
    Column42,
    Column43,
    Column44,
    Column45,
    Column46,
    Column47,
    Column48,
    Column49,
    Column50,
    Column51,
    Column52,
    Column53,
    Column54,
    Column55,
    Column56,
    Column57,
    Column58,
    Column59,
    Column60,
    'Column61'  = @creatorUNI,
    'Column62'  = @today
  from
    #grandTableBTGPW   
 order by
    Column11,
    Column09,
    Column34
    
--  drop table #grandTableBTGPW

end


goto cleanup