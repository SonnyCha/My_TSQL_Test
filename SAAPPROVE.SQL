if exists (select 1 from sys.objects where name = 'SAApprove')
begin 
  drop procedure SAApprove
end 
go
Create  proc [dbo].[SAApprove] /*#*******************************************************************************
SECApproveBatch_W

Purpose: This procedure allows a user to give all approvals they have access for
         to a requested user

Called by: 
Calls:  

Parameters: 
Syntax:  

Tables used: 
  
Views   used:         
Tables updated: 

Results:

Written by: Ross A Huttner
Write date: 12/13/06


Comments:       This was original a copy of PURApproveFinal_W which had the same multi-dept approval
                logic. 
Revision History :
07/21/07 - rah - moved in the code to allow for multiple prelim approvals
07/26/07 - rah - fixed problem where prelim approvals were not updating last mod name/date (put in production 7/31)
08/03/07 - rah - moved the 7/26 modification so it is unconditional and after the insert into approval
                 for some reason it still was not updating in production. moving it and making it unconditional
                 will ensure that if a record goes into approval then the fields will be updated, and the fields
                 will not be updated if no approval was done

8/23/2012 - CHG0031853 User must have access to assign access for this node/dept.
2/07/2016 cc3887 CHG0051402 - check for legacy sec permission for legacy access request
9/12/2017 cc3887 CHG0057438 - move SAApplyRequestedUserLegacy here
*********************************************************************************#*/
@fs_user_id	char(4),
@reqUserId    	varchar(08)   = null,
@notes1       	varchar(255)  = null,
@notes2       	varchar(255)  = null

as

declare @errno          int, 
        @errmsg         varchar(255),
        @dept           char(10), 
        @homedept       char(10),
        @has_rite       char(1),
        @aprv_type      char(1),
        @pending_count  int,
        @pass           int,
        @DeptNum        char(10),
        @numapproved    int,
        @numprocessed   int,
        @ApvlStatCd     char(1),
        @ModuleCd       char(3),
		@ModuleId       char(2),
		@legacyModuleId char(2),
        @loginOK        char(1),
        @usertypex      char(3),
        @date           smalldatetime,
        @nextstat       char(1),
        @createdept     char(10),
        @mode           char(1),
        @locked         char(1),
        @userId         varchar(8)

select  @ModuleCd = 'SEC',
		@ModuleId = 'SA',
		@legacyModuleId = 'L5',
		@date     = getdate()

-- Convert FS_USER_ID to UNI.
select @userId = dbo.GetUserCode (@fs_user_id) 
       
----------------------------------------------------------------------
-- make sure the admin has the requested user locked
-- passing 0 for the locked parameter will check to see if the user
-- has the record locked and if not, it will raise an error
-- note: since the client needs to call getrequesteduser with the lock
--       parameter set to Y, the batch shold be locked at this point
--       if not, do not continue to approve/reject
--       other operations like delete and release do not need 
--       to call getrequesteduser first so they need to explicitly 
--       attempt to lock first. this sp does not
----------------------------------------------------------------------

-- get admin info
exec SAGetAdminInfo @userId, @usertypex output, @homedept output
if @usertypex = 'UDF'
begin
   select    @errno  = 50000, 
             @errmsg = 'You must be a DAF/FFE Security Administrator to use this module.'
   RAISERROR(@errmsg, 16, 1)
   return
end

if datalength(ltrim(rtrim(@reqUserId))) in (0, null)
begin
  select @errno  = 31003,
         @errmsg = 'Requested User''s Id must not be blank.'
  RAISERROR(@errmsg, 16, 1)
  return 
end

-- Make sure the batch exists and has the proper approval status code
select @aprv_type  = Approval_Status_Code,
       @dept       = Department_Number, 
       @createdept = Created_By_Department
  from REQUESTED_USER
 where CADB_User_ID = @reqUserId 

if @@rowcount = 0 
begin
  select @errno = 50403,
         @errmsg = 'Requested user ' + @reqUserId + ' does not exist.'
  RAISERROR(@errmsg, 16, 1)
  return
end

if @aprv_type not in ('F', 'C', 'S', 'A')  --534108 added A  --JR REVISIT
begin
  select @errno  = 50404,
         @errmsg = 'Requested user ' + @reqUserId + ' does not have the proper status code to be approved.'
  RAISERROR(@errmsg, 16, 1)
  return
end

exec SAApproveLegacy @userId, @reqUserId, @dept, @notes1, @notes2

----------------------------------------------------------------------------------------
select @errmsg = ' ',
       @errno  = 0

BEGIN TRANSACTION

  select @pass         = 1,
         @numapproved  = 0,
         @numprocessed = 0
  
  while (@pass <= 2)
  begin
    -- if @pending_count is 1 then the final approval for the owner can be done
    select @pending_count     = count(*)
      from PENDING_APPROVAL
     where Module_Code        = @ModuleCd
       and Batch_Identifier   = @reqUserId
       and Approval_Type_Code <> 'P'
	   and Module_Id          <> @legacyModuleId

    if @pending_count = 1 
    begin
      select @pass = 2
    end

    if @pass = 2 and @pending_count > 1
    begin
      begin 
        if exists (select 1
                       from APPLICATION_ACCESS_CACHE
                     where CADB_User_ID      = @userId
                       and Module_Code       = @ModuleCd
                       and Department_Number = @dept
                       and Access_Codes  like '%F%' )
            select @has_rite = 'Y'
        else 
            select @has_rite = 'N'
        end
     
		if @has_rite = 'Y'
		  begin
			select @errno  = 50405
			select @errmsg = @errmsg + @reqUserId + ' can not be approved until all foreign departments have been given approval'
		  end
      -- setting these to be equal so the test at the bottom will not fire
		select @numapproved  = 0
		select @numprocessed = 0
		break
      end

    declare approvals CURSOR LOCAL FORWARD_ONLY DYNAMIC FOR
     select pa.Approval_Department_Number,
            pa.Approval_Type_Code
       from PENDING_APPROVAL pa
      where pa.Batch_Identifier  = @reqUserId
        and pa.Module_Code       = @ModuleCd
		and pa.Module_Id         <> @legacyModuleId
        for read only
     
     
    open approvals
    while (1=1)
    begin
      fetch approvals into @DeptNum, @ApvlStatCd
      if @@FETCH_STATUS <> 0 break	  
      -- dont want to process the owner record if there are other approvals pending
      if @DeptNum    = @dept
		and @ApvlStatCd = 'F'
        and @pass       = 1
		begin  
          continue
        end
	  select @numprocessed = @numprocessed + 1
      ---------------------------------------------------------------------------
      -- Preliminary Department Approval
      ---------------------------------------------------------------------------
      if @ApvlStatCd = 'P'
        begin
        -- see if the user has Preliminary approval rights for the dept
--        exec FFECheckUserAccess @userId, @ModuleCd, @DeptNum, 'P', @has_rite output         
          if exists (select 1
                       from APPLICATION_ACCESS_CACHE
                       where CADB_User_ID      = @userId
                         and Module_Code       = @ModuleCd
                         and Department_Number = @DeptNum --@dept
                         and Access_Codes  like '%P%')
            begin
              select @has_rite = 'Y'
            end
          else 
		    begin
              select @has_rite = 'N'
            end 
          if @has_rite = 'N' 
            begin  
              select @numprocessed = @numprocessed - 1  -- final approvers dont process this and it throws off the count
              continue
            end
        end   --if @ApvlStatCd = 'P'

        ---------------------------------------------------------------------------
        -- Final Department Approval
        ---------------------------------------------------------------------------
		if @ApvlStatCd = 'F'
		  begin
        -- see if the user has Final approval rights for the dept

        -- 551848 need to make sure the user has approval for the department group. this cant be checked in FFECheckUserAccess_W
        -- also the check for FFECheckUserAccess_W can only be done if @dept is 001-999
        --if @DeptNum between '001' and '999'
        --begin
         -- exec FFECheckUserAccess @userId, @ModuleCd, @DeptNum, 'F', @has_rite output         
        -- end
        -- else begin
			if exists (select 1
                         from APPLICATION_ACCESS_CACHE
                         where CADB_User_ID     = @userId
                           and Module_Code      = @ModuleCd
                           and Department_Number = @DeptNum --@dept
                           and Access_Codes  like '%F%')
              begin
                select @has_rite = 'Y'
              end
            else 
			  begin
                select @has_rite = 'N'
              end
            if @has_rite = 'N' and @usertypex <> 'SUP'
              begin  
                continue
              end
          end   --if @ApvlStatCd = 'F'

        ---------------------------------------------------------------------------
        -- Secondary Super User Approval
        ---------------------------------------------------------------------------
        if @ApvlStatCd = 'S'
          begin
          -- make sure the user is a superuser
            if @usertypex <> 'SUP'
              begin
			    rollback transaction
                select @errno  = 50406,
                       @errmsg = 'You must be a Super User to do this approval'
                RAISERROR(@errmsg, 16, 1)
                return
              end
        
          -- make sure this super user did not already give an approval for this requested user
          if exists (select 1
                       from APPROVAL
                       where Module_Code             = @ModuleCd
                         and Batch_Identifier        = @reqUserId
                         and Approver_CADB_Handle_ID = @userId
						 and Module_Id               <> @legacyModuleId
                         and Approval_Type_Code      = 'F')
            begin
		      rollback transaction
              select @errno  = 50407,
                 @errmsg = 'You have alredy approved this requested user. A different Super User must approve it to complete it'
              RAISERROR(@errmsg, 16, 1)
              return
            end

		  end --if @ApvlStatCd = 'S'
   
        ---------------------------------------------------------------------------
        -- process the approval
        ---------------------------------------------------------------------------
        set rowcount 1
        insert into APPROVAL (Department_Number,
                              Batch_Identifier,
                              Approval_Type_Code,
                              Module_Code,
                              Approver_CADB_Handle_ID,
                              Approval_Date,
                              Approval_Round_Number,
                              Approval_Memo_Text,
                              Prior_Approval_ID,
							  Module_Id
                             )
                    select Approval_Department_Number, 
                           Batch_Identifier, 
                           @ApvlStatCd,  
                           @ModuleCd, 
                           @userId, 
                           @date, 
                           Approval_Round_Number,
                           @notes1+@notes2,
                           Prior_Approval_ID,
						   Module_Id
                      from PENDING_APPROVAL
                      where Batch_Identifier           = @reqUserId  
                        and Approval_Department_Number = @DeptNum
                        and Approval_Type_Code         = @ApvlStatCd
                        and Module_Code                = @ModuleCd
						and Module_Id                  <> @legacyModuleId
        set rowcount 0

      -- rah 8/3/07
      -- update requested user to show this approver as the last modifier
      -- this was originally done below when the status code was updated,
      -- but it was discovered that it was not updated when preliminary approval
      -- was given because the update was in the if @pending_count = 0 code
      -- and that is false when prelim was given
        update REQUESTED_USER
          set Last_Edit_Date           = @date,
              Last_Modification_By     = @userId
          where CADB_User_ID           = @reqUserId 

      -- rah 6/21/07 - dont want to delete Prelim records in pending approval table if
      -- explicit prelim approval was given. this will allow multiple prelim approvals to be given
      -- added the @ApvlStatCd               <> 'P' condition to prevent it
      -- the P record will be deleted when final is given for that dept, which should be at the end
        delete from PENDING_APPROVAL
          where Batch_Identifier           = @reqUserId  
            and Approval_Department_Number = @DeptNum
            and Approval_Type_Code        in (@ApvlStatCd, 'P')
            and Module_Code                = @ModuleCd
            and @ApvlStatCd               <> 'P'
			and Module_Id                 <> @legacyModuleId
     
        select @numapproved = @numapproved + 1    
    end --while (1=1)
     
    close approvals
    deallocate approvals
    select @pass = @pass + 1
  end -- (@pass <= 2)

  exec FFESaveNotes  @userId, @reqUserId, @ModuleCd, 'F', @notes1
  exec FFESaveNotes  @userId, @reqUserId, @ModuleCd, 'F', @notes2 

  --SET APPROVAL STATUS CODE, only change if there are no more pending approval records
  select @pending_count = count(*)
    from PENDING_APPROVAL
    where Module_Code        = @ModuleCd
      and Batch_Identifier   = @reqUserId
      and Approval_Type_Code <> 'P'
	  and Module_Id          <> @legacyModuleId
     
  if @pending_count = 0
    begin
      -- default the next status to completly done. if it needs additional approvals
      -- then the rest of the code will change it
      select @nextstat = 'Y'

	  -- if the superuser privilege is being granted, then create a pending approval record
      -- for a secondary superuser approval
      if @aprv_type = 'F' and exists (select 1 
                                        from REQUESTED_PRIVILEGES
                                        where CADB_User_ID = @reqUserId 
                                          and Privilege_ID = 'SUPUSER'
                                          and Old_Value    = 'N')
        begin
          select @nextstat = 'S'
        end        
    
      if @nextstat <> 'Y'
        begin    
          insert into PENDING_APPROVAL (Approval_Department_Number,
                                        Batch_Identifier,
                                        Approval_Type_Code,
                                        Module_Code,
                                        Originating_Department_Number,
                                        Release_Date,
                                        Approval_Round_Number,
                                        Previous_Approvals_Count,
										Module_Id)
							values ('000',
                                   @reqUserId,
                                   @nextstat,
                                   @ModuleCd,
                                   @createdept,
                                   @date,
                                   0,
                                   0,
								   @ModuleId
                                  )
        end                    

      -- update the status code on requested user
      update REQUESTED_USER
        set Approval_Status_Code  = @nextstat,
            Last_Edit_Date        = @date,
            Last_Modification_By  = @userId
        where CADB_User_ID          = @reqUserId 
     
    end 

COMMIT TRANSACTION

-- call the sp to activate the changes and write to the audit file
-- it will contain the logic to determine if those actions should actually be done
-- this can not be called inside the transaction because there are temp tables involved
-- and you cant create a temp table in an open transaction

exec SAApplyRequestedUserLegacy @userId, @reqUserId 
exec SAApplyRequestedUser @userId, @reqUserId  

if @numapproved <> @numprocessed
begin
  if @numapproved <> 0
    begin
    select @errno  = 50406, 
           @errmsg = @errmsg + 'Only those departments you have authority for have been approved'
    end
  else 
    begin
    select @errno  = 50407, 
           @errmsg = @errmsg + 'You do not have not have sufficient authority to approve this requested user'
    end
end

endproc:
if @errno > 0
  begin
    RAISERROR(@errmsg, 16, 1)
    return
  end             