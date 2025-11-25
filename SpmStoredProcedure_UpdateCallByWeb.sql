CREATE PROCEDURE [dbo].[SpmStoredProcedure_UpdateCallByWeb]	
	@StoredProcedureId		INT
	,@IsCallByWeb			BIT = 0
	,@ModifiedBy			INT = NULL
	
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20150511@Quinn.Vo
Task: Update is call by web or no for stored procedure. 
DB: SPM
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;	
	DECLARE @Data NVARCHAR(MAX), @OldData NVARCHAR(MAX)
	EXEC @OldData = [dbo].[fncGetDataForWriteLogCallByWeb] @StoredProcedureId = @StoredProcedureId

	UPDATE dbo.SpmStoredProcedure WITH(ROWLOCK,UPDLOCK)
	SET CallByWeb = @IsCallByWeb
		,[ModifiedBy] = @ModifiedBy
		,[ModifiedDate] = GETDATE()	
	WHERE StoredProcedureId = @StoredProcedureId

	EXEC @Data = [dbo].[fncGetDataForWriteLogCallByWeb] @StoredProcedureId = @StoredProcedureId
	EXEC dbo.SpmLog_Insert @UserId = @ModifiedBy, @SpName = 'SpmStoredProcedure_UpdateCallByWeb', @ObjectId = @StoredProcedureId, @ObjectTypeId = 8, @Data = @Data, @OldData = @OldData
END

