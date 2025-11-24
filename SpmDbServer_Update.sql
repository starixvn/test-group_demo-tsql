CREATE PROCEDURE [dbo].[SpmDbServer_Update]
	@DbServerId INT
	,@Name VARCHAR(100)
	,@MachineId INT
	,@IsPrimary BIT = 0
	,@IsActive BIT = 0	
	,@Description NVARCHAR(200) = NULL
	,@ModifiedBy INT = NULL
	
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(500) = '' OUTPUT
AS
/*
Created: 20150327@Tim.Trinh
Task: Edit Db Server. 
DB: SPM
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @Data NVARCHAR(MAX), @OldData NVARCHAR(MAX)

	IF EXISTS(SELECT 1 
		FROM [dbo].[SpmDbServer] WITH (NOLOCK)
		WHERE [DbServerId] <> @DbServerId
			AND [Name] = @Name AND IsDeleted = 0)
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = 'Database Server ''' + @Name + ''' has already existed.'
		RETURN
	END
	
	IF @IsActive = 0 AND EXISTS(SELECT 1
	     FROM [dbo].[SpmAliasServer] AS alias WITH (NOLOCK)
	     INNER JOIN [dbo].[SpmAliasServerEnvironment] AS aliasEv WITH (NOLOCK)
	           ON alias.[AliasServerId] = aliasEv.[AliasServerId]
	                 AND aliasEv.[DbServerId] = @DbServerId
	                 AND alias.[IsDeleted] = 0
					 AND alias.IsActive = 1)
	BEGIN
	     SELECT @ErrCode = 100
	           ,@ErrMsg = 'You can not deactivate this DB server because it is being used by one or more Alias Server.'
	     RETURN
	END
	
	IF (@IsActive = 1 AND NOT EXISTS(SELECT 1
	     FROM [dbo].[SpmMachine] WITH(NOLOCK)
	     WHERE [MachineId] = @MachineId AND [IsActive] = 1))
	BEGIN
	     SELECT @ErrCode = 100
	           ,@ErrMsg = 'You can not activate this DB server because Machine is not exist or deactivate.'
	     RETURN
	END
	
	EXEC @OldData = [dbo].[fncGetDataForWriteLog] @ObjectId = @DbServerId, @ObjectType = 2

	SET XACT_ABORT ON
	BEGIN TRAN
	BEGIN TRY		
		-- update SpmDbServer
		UPDATE [dbo].[SpmDbServer] WITH(ROWLOCK,UPDLOCK)
		SET [Name] = @Name
			,[MachineId] = @MachineId
			,[Description] = @Description
			,[IsActive] = @IsActive
			,[IsPrimary] = @IsPrimary
			,[ModifiedBy] = @ModifiedBy
			,[ModifiedDate] = GETDATE()
		WHERE [DbServerId] = @DbServerId
		
		EXEC @Data = [dbo].[fncGetDataForWriteLog] @ObjectId = @DbServerId, @ObjectType = 2
		EXEC dbo.SpmLog_Insert @UserId = @ModifiedBy, @SpName = 'SpmDbServer_Update', @ObjectId = @DbServerId, @ObjectTypeId = 2, @Data = @Data, @OldData = @OldData

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
