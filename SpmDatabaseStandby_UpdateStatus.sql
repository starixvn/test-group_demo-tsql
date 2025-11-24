CREATE PROCEDURE [dbo].[SpmDatabaseStandby_UpdateStatus]	
	@StandbyId INT
	,@IsActive BIT=0	
	,@ModifiedBy INT=NULL	
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20181024@Larry.Tran
Task: Activate or deactivate Standby Database. 
DB: SPM
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;	
	
	DECLARE @Data NVARCHAR(MAX), @OldData NVARCHAR(MAX)
    DECLARE @LogObjectType INT = 13
	
	EXEC @OldData = [dbo].[fncGetDataForWriteLogStatus] @ObjectId = @StandbyId, @ObjectType = @LogObjectType

	UPDATE dbo.SpmDatabaseStandby WITH(UPDLOCK,ROWLOCK)	
	SET [IsActive] = @IsActive		
		,[ModifiedBy] = @ModifiedBy
		,[ModifiedDate] = GETDATE()
	WHERE StandbyId = @StandbyId

	EXEC @Data = [dbo].[fncGetDataForWriteLogStatus] @ObjectId = @StandbyId, @ObjectType = @LogObjectType
	EXEC dbo.SpmLog_Insert @UserId = @ModifiedBy, @SpName = 'SpmDatabaseStandby_UpdateStatus', @ObjectId = @StandbyId, @ObjectTypeId = @LogObjectType, @Data = @Data, @OldData = @OldData
END