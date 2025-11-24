CREATE PROCEDURE [dbo].[SpmAliasServer_Delete]	
	 @AliasServerId INT
	,@ModifiedBy INT=NULL
	
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20150318@Josh.Phan
Task: Delete Alias Server. 
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
	   FROM [dbo].[SpmStoredProcedure] AS sp WITH(NOLOCK) 
	   WHERE AliasServerId = @AliasServerId 
		  AND sp.IsDeleted = 0
    )
    BEGIN
	   SELECT @ErrCode = 100
		  ,@ErrMsg = 'Cannot delete this Alias Server because it is being used.'
	   RETURN
    END

    EXEC @OldData = [dbo].[fncGetDataForWriteLog] @ObjectId = @AliasServerId, @ObjectType = 4

    SET XACT_ABORT ON
    BEGIN TRAN
    BEGIN TRY
	   IF EXISTS (
		  SELECT TOP 1 1 
		  FROM [dbo].[SpmStoredProcedure] AS sp WITH(NOLOCK) 
		  WHERE AliasServerId = @AliasServerId 
			 AND sp.IsDeleted = 1
	   )
	   BEGIN
		  UPDATE [dbo].[SpmAliasServer] WITH (UPDLOCK, ROWLOCK)
		  SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedDate = GETDATE()
		  WHERE [AliasServerId] = @AliasServerId
	   END
	   ELSE
	   BEGIN
		  DELETE FROM [dbo].[SpmAliasServer] WHERE [AliasServerId] = @AliasServerId
		  DELETE FROM [dbo].[SpmAliasServerDatabase] WHERE [AliasServerId] = @AliasServerId
		  DELETE FROM [dbo].[SpmAliasServerEnvironment] WHERE [AliasServerId] = @AliasServerId
          DELETE dbo.SpmAliasServerNoDeployment WHERE [AliasServerId] = @AliasServerId		  
	   END
	   
	   EXEC dbo.SpmLog_Insert @UserId = @ModifiedBy, @SpName = 'SpmAliasServer_Delete', @ObjectId = @AliasServerId, @ObjectTypeId = 4, @Data = NULL, @OldData = @OldData
	   
	   SELECT @ErrCode = 0, @ErrMsg = ''
	   
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

