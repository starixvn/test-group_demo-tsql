CREATE PROCEDURE [dbo].[SpmDbServer_UpdateStatus]
	@DbServerId INT
	,@IsActive BIT = 0
	,@ModifiedBy INT = NULL
	
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
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
	EXEC @OldData = [dbo].[fncGetDataForWriteLogStatus] @ObjectId = @DbServerId, @ObjectType = 2

	IF NOT EXISTS (SELECT 1 FROM [dbo].[SpmDbServer] WITH(NOLOCK) 
	         WHERE [DbServerId] = @DbServerId)
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = 'The Db Server is not exist.'
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
	     FROM [dbo].[SpmDbServer] AS db WITH (NOLOCK)
		INNER JOIN [dbo].[SpmMachine] AS mc WITH (NOLOCK) ON db.MachineId = mc.MachineId
	     WHERE db.DbServerId = @DbServerId AND mc.[IsActive] = 1))
	BEGIN
	     SELECT @ErrCode = 100
	           ,@ErrMsg = 'You can not activate this DB server because Machine is not exist or deactivate.'
	     RETURN
	END
	
	UPDATE [dbo].[SpmDbServer] WITH(ROWLOCK,UPDLOCK)
	SET [IsActive] = @IsActive
		,[ModifiedBy] = @ModifiedBy
		,[ModifiedDate] = GETDATE()	
	WHERE [DbServerId] = @DbServerId

	EXEC @Data = [dbo].[fncGetDataForWriteLogStatus] @ObjectId = @DbServerId, @ObjectType = 2
	EXEC dbo.SpmLog_Insert @UserId = @ModifiedBy, @SpName = 'SpmDbServer_UpdateStatus', @ObjectId = @DbServerId, @ObjectTypeId = 2, @Data = @Data, @OldData = @OldData
END
