CREATE PROCEDURE [dbo].[SpmAliasServer_UpdateStatus]	
	@AliasServerId INT,
	@IsActive BIT=0	
	,@ModifiedBy INT=NULL
	
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20150318@Josh.Phan
Task: Activate or deactivate Alias Server. 
DB: SPM
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;	
	
	DECLARE @Data NVARCHAR(MAX), @OldData NVARCHAR(MAX)

	IF @IsActive = 0 AND EXISTS(SELECT 1
	     FROM [dbo].[SpmStoredProcedure] AS st WITH (NOLOCK)
	     WHERE st.AliasServerId = @AliasServerId
	        AND st.[IsDeleted] = 0
			AND st.IsActive = 1)
	BEGIN
	     SELECT @ErrCode = 100
	           ,@ErrMsg = 'You can not deactivate this Alias because it is being used by one or more Stored Procedure.'
	     RETURN
	END

	IF (@IsActive = 1 AND (EXISTS (SELECT 1
			 FROM [dbo].[SpmDbServer] AS sv WITH (NOLOCK)
			 INNER JOIN [dbo].[SpmAliasServerEnvironment] AS aev WITH (NOLOCK) ON sv.DbServerId = aev.DbServerId
			 WHERE aev.AliasServerId = @AliasServerId
				AND sv.IsActive = 0)
		OR EXISTS (SELECT 1 FROM [dbo].[SpmDatabase] AS db WITH (NOLOCK)
			INNER JOIN [dbo].[SpmAliasServerDatabase] AS adb WITH (NOLOCK) ON db.DatabaseId = adb.DatabaseId
			WHERE adb.AliasServerId = @AliasServerId
				AND db.IsActive = 0)))
	BEGIN
	     SELECT @ErrCode = 100
	           ,@ErrMsg = 'You can not activate this Alias because DB Server or Database are been deactivate.'
	     RETURN
	END

	EXEC @OldData = [dbo].[fncGetDataForWriteLogStatus] @ObjectId = @AliasServerId, @ObjectType = 4

	UPDATE [dbo].[SpmAliasServer] WITH(ROWLOCK,UPDLOCK)
	SET [IsActive] = @IsActive		
		,[ModifiedBy] = @ModifiedBy
		,[ModifiedDate] = GETDATE()
	WHERE [AliasServerId] = @AliasServerId

	EXEC @Data = [dbo].[fncGetDataForWriteLogStatus] @ObjectId = @AliasServerId, @ObjectType = 4
	EXEC dbo.SpmLog_Insert @UserId = @ModifiedBy, @SpName = 'SpmAliasServer_UpdateStatus', @ObjectId = @AliasServerId, @ObjectTypeId = 4, @Data = @Data, @OldData = @OldData
END

