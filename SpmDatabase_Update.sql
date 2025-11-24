CREATE PROCEDURE [dbo].[SpmDatabase_Update]	
	 @DatabaseId INT
	,@Name VARCHAR(100)
	,@IsActive BIT=0
	,@Description NVARCHAR(2000)=NULL
	,@ExecutionUser VARCHAR(100)=NULL
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

	IF EXISTS( 
		SELECT 1 
		FROM [dbo].[SpmDatabase] WITH (NOLOCK)
		WHERE [DatabaseId] <> @DatabaseId AND [Name] = @Name AND IsDeleted = 0)
		
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = 'The Database ''' + @Name + ''' has already existed. Please try again.'
		RETURN
	END
	
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

	EXEC @OldData = [dbo].[fncGetDataForWriteLog] @ObjectId = @DatabaseId, @ObjectType = 3

	SET @ModifiedDate = GETDATE()
	UPDATE [dbo].[SpmDatabase] WITH(ROWLOCK,UPDLOCK)
	SET  [Name] = @Name
		,[IsActive] = @IsActive
		,[Description] = @Description
		,[ExecutionUser] = LTRIM(RTRIM(@ExecutionUser))
		,[ModifiedBy] = @ModifiedBy
		,[ModifiedDate] = @ModifiedDate
	WHERE [DatabaseId] = @DatabaseId

	EXEC @Data = [dbo].[fncGetDataForWriteLog] @ObjectId = @DatabaseId, @ObjectType = 3
	EXEC dbo.SpmLog_Insert @UserId = @ModifiedBy, @SpName = 'SpmDatabase_Update', @ObjectId = @DatabaseId, @ObjectTypeId = 3, @Data = @Data, @OldData = @OldData
END

