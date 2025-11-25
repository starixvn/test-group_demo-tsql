CREATE PROCEDURE [dbo].[SpmStoredProcedure_Delete]
	@StoredProcedureId		INT
     ,@ModifiedBy		     INT = NULL
	
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20150506@Quinn.Vo
Task: Delete stored procedure.
DB: SPM
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @OldData VARCHAR(MAX)
	DECLARE @ObjectTypeId INT = 8
	
	EXEC @OldData = [dbo].[fncGetDataForWriteLog] @ObjectId = @StoredProcedureId, @ObjectType = @ObjectTypeId

	SET XACT_ABORT ON
	BEGIN TRAN
	BEGIN TRY
		IF EXISTS (SELECT 1 FROM [dbo].[SpmSpIssue] WITH (NOLOCK) WHERE StoredProcedureId = @StoredProcedureId)
		BEGIN
			UPDATE [dbo].[SpmStoredProcedure] WITH (UPDLOCK, ROWLOCK)
			SET IsDeleted = 1,
				ModifiedBy = @ModifiedBy,
				ModifiedDate = GETDATE()
			WHERE StoredProcedureId = @StoredProcedureId
		END
		ELSE
		BEGIN
			DELETE FROM [dbo].[SpmStoredProcedure] WHERE StoredProcedureId = @StoredProcedureId
			DELETE FROM [dbo].[SpmSpRelation] WHERE StoredProcedureId = @StoredProcedureId
			DELETE FROM [dbo].[SpmSpFunction] WHERE StoredProcedureId = @StoredProcedureId
			DELETE FROM [dbo].[SpmTagDetail] WHERE [ObjectId] = @StoredProcedureId AND [Type] = @ObjectTypeId
		END

		EXEC dbo.SpmLog_Insert @UserId = @ModifiedBy, @SpName = 'SpmStoredProcedure_Delete', @ObjectId = @StoredProcedureId, @ObjectTypeId = @ObjectTypeId, @Data = NULL, @OldData = @OldData
		COMMIT
	END TRY
	BEGIN CATCH
	     IF @@TRANCOUNT > 0
          BEGIN
              ROLLBACK
              SELECT @ErrCode = 100
                  ,@ErrMsg = ERROR_MESSAGE()
          END
	END CATCH   
END


