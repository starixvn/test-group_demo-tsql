CREATE PROCEDURE [dbo].[SpmDatabaseStandby_Delete]
	@StandbyId INT
	,@ModifiedBy INT = NULL
	,@ErrCode INT=0 OUTPUT
	,@ErrMsg NVARCHAR(200)='' OUTPUT
AS
/*
Created: 20181024@Larry.Tran
Task: Delete Standby Database. 
DB: SPM
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @OldData NVARCHAR(MAX)
    DECLARE @LogObjectType INT = 13
	
	EXEC @OldData = [dbo].[fncGetDataForWriteLog] @ObjectId = @StandbyId, @ObjectType = @LogObjectType
	
	UPDATE [dbo].SpmDatabaseStandby WITH(UPDLOCK,ROWLOCK)
	SET IsDeleted = 1, 
		ModifiedBy = @ModifiedBy, 
		ModifiedDate = GETDATE()
	WHERE StandbyId = @StandbyId
	
	EXEC dbo.SpmLog_Insert @UserId = @ModifiedBy, @SpName = 'SpmDatabaseStandby_Delete', @ObjectId = @StandbyId, @ObjectTypeId = @LogObjectType, @Data = NULL, @OldData = @OldData
END