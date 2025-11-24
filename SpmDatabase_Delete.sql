CREATE PROCEDURE [dbo].[SpmDatabase_Delete]	
	 @DatabaseId INT
	 ,@ModifiedBy INT = NULL

	,@ErrCode INT=0 OUTPUT
	,@ErrMsg NVARCHAR(200)='' OUTPUT
AS
/*
Created: 20150327@Aaron.Cao
Task: Delete Database. 
DB: SPM
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @OldData NVARCHAR(MAX)

	IF EXISTS( 
		    SELECT TOP 1 1 
		    FROM [dbo].[SpmAliasServer] AS als WITH (NOLOCK) 
		    INNER JOIN [dbo].[SpmAliasServerDatabase] AS asd WITH (NOLOCK) ON als.AliasServerId = asd.AliasServerId AND als.IsDeleted = 0
		    WHERE [DatabaseId] = @DatabaseId
        )
        OR EXISTS(
            SELECT TOP 1 1 
            FROM dbo.SpmDatabaseStandby AS sb WITH(NOLOCK)
                INNER JOIN dbo.SpmDatabaseStandbyRelation AS sr WITH(NOLOCK) ON sb.StandbyId = sr.StandbyId
            WHERE sb.IsDeleted = 0 AND sr.DatabaseId = @DatabaseId
        )
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = 'Cannot delete this Database because it is being used.'
		RETURN
	END
	
	EXEC @OldData = [dbo].[fncGetDataForWriteLog] @ObjectId = @DatabaseId, @ObjectType = 3

	IF EXISTS( 
		SELECT 1 
		FROM [dbo].[SpmAliasServer] AS als WITH (NOLOCK) 
		INNER JOIN [dbo].[SpmAliasServerDatabase] AS asd WITH (NOLOCK) ON als.AliasServerId = asd.AliasServerId AND als.IsDeleted = 1
		WHERE [DatabaseId] = @DatabaseId)
	BEGIN
		UPDATE [dbo].[SpmDatabase] 
		SET IsDeleted = 1, 
			ModifiedBy = @ModifiedBy, 
			ModifiedDate = GETDATE()
		WHERE [DatabaseId] = @DatabaseId
	END
	ELSE
	BEGIN
		DELETE FROM [dbo].[SpmDatabase] WHERE [DatabaseId] = @DatabaseId
	END

	EXEC dbo.SpmLog_Insert @UserId = @ModifiedBy, @SpName = 'SpmDatabase_Delete', @ObjectId = @DatabaseId, @ObjectTypeId = 3, @Data = NULL, @OldData = @OldData
END
