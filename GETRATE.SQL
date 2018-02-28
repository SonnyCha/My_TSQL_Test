if exists (select 1 from sys.objects where name = 'GetRate')
begin 
  drop function GetRate
end 
go
CREATE FUNCTION dbo.GetRate
( 
  @typeid        char(3),
  @periodid      char(3),
  @chartidtarget char(7),
  @chartidoffset char(7)
)

returns numeric(9,6)

as
begin
  declare @rate        numeric(9,6)
  declare @busunitid   char(05),
          @deptid      char(10),
          @fundid      char(05),
          @busunitpcid char(05),
          @projectid   char(15),
          @activityid  char(15),
          @programid   char(05),
          @chartfld1id char(10),
          @chartfld2id char(10),
          @classid     char(05),
          @accountid   char(10)

  select @rate = 0.00

  select @busunitid    = BUSINESS_UNIT, 
         @deptid       = DEPTID, 
         @fundid       = FUND_CODE, 
         @busunitpcid  = BUSINESS_UNIT_PC, 
         @projectid    = PROJECT_ID, 
         @activityid   = ACTIVITY_ID, 
         @programid    = PROGRAM_CODE, 
         @chartfld1id  = CHARTFIELD1, 
         @chartfld2id  = CHARTFIELD2, 
         @classid      = CLASS_FLD, 
         @accountid    = ACCOUNT
	from dbo.FS_CHART
   where Chart_Id      = @chartidtarget

   if @typeid = '251'
   begin
    select @deptid = DEPTID 
      from V_PS_ZCU_CF_PROJ_TBL_EXT
     where PROJECT_ID = @projectid
   end
   
  select @rate = Rate
    from FS_RATE
   where Type_Id          = @typeid
     and Period_Id        in ('#####',@periodid)
     and BUSINESS_UNIT    in ('#####',@busunitid)
     and DEPTID           in ('#####',@deptid)
     and FUND_CODE        in ('#####',@fundid)
     and BUSINESS_UNIT_PC in ('#####',@busunitpcid)
     and PROJECT_ID       in ('#####',@projectid)
     and ACTIVITY_ID      in ('#####',@activityid)
     and PROGRAM_CODE     in ('#####',@programid)   
     and CHARTFIELD1      in ('#####',@chartfld1id)
     and CHARTFIELD2      in ('#####',@chartfld2id)
     and CLASS_FLD        in ('#####',@classid)
     and ACCOUNT          in ('#####',@accountid)

  return @rate
end