CREATE PROCEDURE [dbo].[SpmStoredProcedure_Insert]
	@Name				VARCHAR(300)
	,@AliasServerId		INT
	,@DatabaseId			INT
	,@Type				INT
	,@CallByWeb			BIT = NULL
	,@CallByExecRef		BIT = NULL
	,@Description			NVARCHAR(200) = NULL
	,@IsActive			BIT = 0
	,@CreatedBy			INT = NULL

	,@NestedSps			NVARCHAR(MAX) = NULL
	,@Issues				VARCHAR(MAX) = NULL
	,@Functions			VARCHAR(MAX) = NULL
	,@TagIds                 NVARCHAR(MAX) = NULL

	,@StoredProcedureId		INT = 0 OUTPUT
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20150420@Quinn.Vo
Task: Insert stored procedure.
DB: SPM
Original: 

Revisions:  
Param's Explanation:
- @IssueIds: <ROOT>
				<Issue IssueId="1" DeveloperId="1" ActionName="A" Status="1" VersionId="1" Description='Test'><Issue/>
			 </ROOT>
- @NestedSps: 1,2
- @Functions: <ROOT>
					<Function FunctionId="1" SystemId="1" ProductId="1"><Function/>
			  </ROOT>
- @EnvironmentIds: '1,2'
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @DocHandler INT
	DECLARE @Data VARCHAR(MAX)
	DECLARE @ObjectTypeId INT = 8

	IF(EXISTS(SELECT 1 FROM dbo.SpmStoredProcedure WITH (NOLOCK) 
	   WHERE Name = @Name AND AliasServerId = @AliasServerId AND DatabaseId = @DatabaseId AND IsDeleted = 0))
	BEGIN
	   SELECT @ErrCode = 1, 
		  @ErrMsg = 'Stored Procedure already exists.'
	   RETURN
	END

	SET XACT_ABORT ON
	BEGIN TRAN
	BEGIN TRY
	   INSERT INTO dbo.SpmStoredProcedure(
		  Name,
		  AliasServerId,
		  DatabaseId,
		  SpTypeId,
		  CallByWeb,
		  CallByExecRef,
		  IsActive,
		  [Description],
		  ModifiedBy,
		  ModifiedDate
		  )
	   VALUES
	   (
		  @Name,
		  @AliasServerId,
		  @DatabaseId,
		  @Type,
		  @CallByWeb,
		  @CallByExecRef,
		  @IsActive,
		  @Description,
		  @CreatedBy,
		  GETDATE()
	   )

	   SELECT @StoredProcedureId = CAST(SCOPE_IDENTITY() AS INT)
		
	   EXECUTE [dbo].[SpmStoredProcedure_InsertIssue] @StoredProcedureId, @Issues, @CreatedBy

	   EXECUTE [dbo].[SpmStoredProcedure_InsertNestedSp] @StoredProcedureId, @NestedSps

	   EXECUTE [dbo].[SpmStoredProcedure_InsertFunction] @StoredProcedureId, @Functions, @CreatedBy

	   EXECUTE [dbo].[SpmTag_InsertDetail] @StoredProcedureId, @TagIds,@ObjectTypeId

	   EXEC @Data = [dbo].[fncGetDataForWriteLog] @ObjectId = @StoredProcedureId, @ObjectType = @ObjectTypeId

	   EXEC dbo.SpmLog_Insert @UserId = @CreatedBy, @SpName = 'SpmStoredProcedure_Insert', @ObjectId = @StoredProcedureId, @ObjectTypeId = @ObjectTypeId, @Data = @Data, @OldData = NULL
		
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

