CREATE PROCEDURE [dbo].[SpmDbServer_Insert]
	@DbServerId INT OUTPUT
	,@Name VARCHAR(100)
	,@MachineId INT
	,@IsPrimary BIT = 0
	,@IsActive BIT = 0	
	,@Description NVARCHAR(200) = NULL
	,@CreatedBy INT
	
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(500) = '' OUTPUT
AS
/*
Created: 20150325@Tim.Trinh
Task: Insert new Db Server. 
DB: SPM
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @Data NVARCHAR(MAX)

	IF EXISTS( SELECT 1 
		FROM [dbo].[SpmDbServer] WITH (NOLOCK)
		WHERE [Name] = @Name AND IsDeleted = 0)		
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = 'Database Server ''' + @Name + ''' has already existed.'
		RETURN
	END
	
	IF NOT EXISTS ( SELECT TOP 1 1
		FROM [dbo].[SpmMachine] WITH(NOLOCK)
		WHERE [MachineId] = @MachineId AND IsDeleted = 0)
	BEGIN
		SELECT @ErrCode = 100,
			@ErrMsg = 'The Machine is not exist.'
		RETURN
	END
	
	SET XACT_ABORT ON
	BEGIN TRAN
	BEGIN TRY	
		INSERT INTO [dbo].[SpmDbServer]
			([Name]
			,[MachineId]
			,[Description]
			,[IsActive]
			,[IsPrimary]
			,[ModifiedBy]
			,[ModifiedDate]) 
			VALUES
			(@Name
			,@MachineId
			,@Description
			,@IsActive
			,@IsPrimary
			,@CreatedBy
			,GETDATE())
	
		SELECT @DbServerId = CAST(SCOPE_IDENTITY() AS INT)	
		
		EXEC @Data = [dbo].[fncGetDataForWriteLog] @ObjectId = @DbServerId, @ObjectType = 2
		EXEC dbo.SpmLog_Insert @UserId = @CreatedBy, @SpName = 'SpmDbServer_Insert', @ObjectId = @DbServerId, @ObjectTypeId = 2, @Data = @Data, @OldData = NULL

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
