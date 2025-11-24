CREATE PROCEDURE [dbo].[SpmDbServer_Delete]	
	@DbServerId INT
	,@ModifiedBy INT = NULL
	
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20150330@Tim.Trinh
Task: Delete Db Server. 
DB: SPM
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @OldData NVARCHAR(MAX)

	IF NOT EXISTS( SELECT 1 
		FROM [dbo].[SpmDbServer] WITH (NOLOCK)
		WHERE [DbServerId] = @DbServerId)		
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = 'The Db Server is not exist.'
		RETURN
	END
	
	IF EXISTS ( 
            SELECT TOP 1 1
		    FROM [dbo].[SpmAliasServer] AS als WITH (NOLOCK)
		    INNER JOIN [dbo].[SpmAliasServerEnvironment] AS aev WITH(NOLOCK) 
		          ON als.AliasServerId = aev.AliasServerId
		    WHERE DbServerId = @DbServerId AND als.IsDeleted = 0
        )
        OR EXISTS(
            SELECT TOP 1 1 
            FROM dbo.SpmDatabaseStandby AS sb WITH(NOLOCK)
                INNER JOIN dbo.SpmDatabaseStandbyRelation AS sr WITH(NOLOCK) ON sb.StandbyId = sr.StandbyId
            WHERE sb.IsDeleted = 0 AND sr.DbServerId = @DbServerId
        )
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = 'Cannot remove this Database Server because it is being used.'
		RETURN
	END
	
	EXEC @OldData = [dbo].[fncGetDataForWriteLog] @ObjectId = @DbServerId, @ObjectType = 2

	IF EXISTS ( SELECT 1
		FROM [dbo].[SpmAliasServer] AS als WITH (NOLOCK)
		INNER JOIN [dbo].[SpmAliasServerEnvironment] AS aev WITH(NOLOCK) 
		      ON als.AliasServerId = aev.AliasServerId
		WHERE DbServerId = @DbServerId AND als.IsDeleted = 1)
	BEGIN
		UPDATE [dbo].[SpmDbServer] 
		SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedDate = GETDATE()
		WHERE [DbServerId] = @DbServerId
	END
	ELSE
	BEGIN
		DELETE [dbo].[SpmDbServer]
		WHERE [DbServerId] = @DbServerId
	END
	
	SELECT @ErrCode = 0, @ErrMsg = ''	
	EXEC dbo.SpmLog_Insert @UserId = @ModifiedBy, @SpName = 'SpmDbServer_Delete', @ObjectId = @DbServerId, @ObjectTypeId = 2, @Data = NULL, @OldData = @OldData
END
