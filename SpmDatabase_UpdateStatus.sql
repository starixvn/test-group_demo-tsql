CREATE PROCEDURE [dbo].[SpmDatabase_UpdateStatus]	
	@DatabaseId INT,
	@IsActive BIT=0
	,@ModifiedDate DATETIME=NULL
	,@ModifiedBy INT=NULL
	
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20150327@Aaron.Cao
Task: Edit Database. 
DB: SPM
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;	

	DECLARE @Data NVARCHAR(MAX), @OldData NVARCHAR(MAX)
	EXEC @OldData = [dbo].[fncGetDataForWriteLogStatus] @ObjectId = @DatabaseId, @ObjectType = 3

     IF @IsActive = 0 AND EXISTS(SELECT 1
	     FROM [dbo].[SpmAliasServer] AS alias WITH (NOLOCK)
	     INNER JOIN [dbo].[SpmAliasServerDatabase] AS aliasDb WITH (NOLOCK)
	           ON alias.[AliasServerId] = aliasDb.[AliasServerId]
	                 AND aliasDb.[DatabaseId] = @DatabaseId
	                 AND alias.[IsDeleted] = 0
					 AND alias.IsActive = 1)
	BEGIN
	     SELECT @ErrCode = 100
	           ,@ErrMsg = 'You can not deactivate this Database because it is being used by one or more Alias Server.'
	     RETURN
	END
     
	SET @ModifiedDate = GETDATE()
	UPDATE [dbo].[SpmDatabase] WITH(ROWLOCK,UPDLOCK)
	SET [IsActive] = @IsActive
		,[ModifiedBy] = @ModifiedBy
		,[ModifiedDate] = @ModifiedDate	
	WHERE [DatabaseId] = @DatabaseId

	EXEC @Data = [dbo].[fncGetDataForWriteLogStatus] @ObjectId = @DatabaseId, @ObjectType = 3
	EXEC dbo.SpmLog_Insert @UserId = @ModifiedBy, @SpName = 'SpmDatabase_UpdateStatus', @ObjectId = @DatabaseId, @ObjectTypeId = 3, @Data = @Data, @OldData = @OldData
END

