CREATE PROCEDURE [dbo].[SpmStoredProcedure_Update]
	@StoredProcedureId		INT
	,@Name			     VARCHAR(300)
	,@AliasServerId	     INT
	,@DatabaseId			INT
	,@Type			     INT
	,@CallByWeb			BIT = NULL
	,@CallByExecRef		BIT = NULL
	,@Description			NVARCHAR(2000) = NULL
	,@IsActive			BIT = 0
	,@ModifiedBy			INT = NULL

	,@NestedSps		     NVARCHAR(500) = NULL
	,@Issues				VARCHAR(MAX) = NULL
	,@Functions		     VARCHAR(MAX) = NULL
	,@EnvironmentIds		VARCHAR(50) = NULL
	,@TagIds                 NVARCHAR(MAX) = NULL

	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20150508@Quinn.Vo
Task: Update stored procedure.
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
	DECLARE @Data VARCHAR(MAX), @OldData VARCHAR(MAX)
	DECLARE @ObjectTypeId INT = 8
	DECLARE @DocHandler INT

	IF(EXISTS(SELECT 1 FROM dbo.SpmStoredProcedure WITH (NOLOCK) 
		WHERE StoredProcedureId <> @StoredProcedureId 
			AND Name = @Name 
			AND AliasServerId = @AliasServerId 
			AND DatabaseId = @DatabaseId 
			AND IsDeleted = 0))
	BEGIN
		SELECT @ErrCode = 1, 
			@ErrMsg = 'Stored Procedure already exists.'
		RETURN
	END

	IF (@IsActive = 1 AND (EXISTS (SELECT 1
			 FROM [dbo].[SpmAliasServer] AS asv WITH (NOLOCK)
			 WHERE asv.AliasServerId = @AliasServerId
				AND asv.IsActive = 0)
		OR EXISTS (SELECT 1 FROM [dbo].[SpmDatabase] AS db WITH (NOLOCK)
			WHERE db.DatabaseId = @DatabaseId
				AND db.IsActive = 0)))
	BEGIN
	     SELECT @ErrCode = 100
	           ,@ErrMsg = 'You can not activate this Stored Procedure because Alias Server or Database are been deactivate.'
	     RETURN
	END

	IF OBJECT_ID('tempdb..#Functions') IS NOT NULL
	BEGIN
		DROP TABLE #Functions
	END 
	CREATE TABLE #Functions(FunctionId INT, SystemId INT, ProductId INT NULL)

	EXEC sp_xml_preparedocument @DocHandler OUTPUT, @Functions
	INSERT INTO #Functions(SystemId, ProductId, FunctionId)
	SELECT SystemId, ProductId, FunctionId
	FROM OPENXML(@DocHandler, '/ROOT/Function', 1) 
	WITH (SystemId INT, ProductId INT, FunctionId INT) AS Data
	EXEC sp_xml_removedocument @DocHandler

	IF (@IsActive = 1 AND (EXISTS (SELECT 1
			 FROM [dbo].[SpmSystem] AS st WITH (NOLOCK)
			 INNER JOIN #Functions AS sfn ON sfn.SystemId = st.SystemId
			 WHERE st.IsActive = 0)
		OR EXISTS (SELECT 1 FROM [dbo].[SpmProduct] AS pr WITH (NOLOCK)
			INNER JOIN #Functions AS sfn ON sfn.ProductId = pr.ProductId
			 WHERE pr.IsActive = 0)
		OR EXISTS (SELECT 1 FROM [dbo].[SpmFunction] AS fn WITH (NOLOCK)
			INNER JOIN #Functions AS sfn ON sfn.FunctionId = fn.FunctionId
			 WHERE fn.IsActive = 0)))
	BEGIN
	   SELECT @ErrCode = 100
	       ,@ErrMsg = 'You can not activate this Stored Procedure because System/Product/Function are been deactivate.'
	   RETURN
	END
	DROP TABLE #Functions

	EXEC @OldData = [dbo].[fncGetDataForWriteLog] @ObjectId = @StoredProcedureId, @ObjectType = @ObjectTypeId
	SET XACT_ABORT ON
	BEGIN TRAN
	BEGIN TRY	     
	   UPDATE dbo.SpmStoredProcedure WITH (ROWLOCK, UPDLOCK)
	   SET Name = @Name,
		  AliasServerId = @AliasServerId,
		  DatabaseId = @DatabaseId,
		  SpTypeId = @Type,
		  CallByWeb = @CallByWeb,
		  CallByExecRef = @CallByExecRef,
		  IsActive = @IsActive,
		  [Description] = @Description,
		  ModifiedBy = @ModifiedBy,
		  ModifiedDate = GETDATE()
	   WHERE StoredProcedureId = @StoredProcedureId
		
	   EXECUTE [dbo].[SpmStoredProcedure_InsertIssue] @StoredProcedureId, @Issues, @ModifiedBy

	   EXECUTE [dbo].[SpmStoredProcedure_InsertNestedSp] @StoredProcedureId, @NestedSps

	   EXECUTE [dbo].[SpmStoredProcedure_InsertFunction] @StoredProcedureId, @Functions, @ModifiedBy

        EXECUTE [dbo].[SpmTag_InsertDetail] @StoredProcedureId, @TagIds, @ObjectTypeId

	   EXEC @Data = [dbo].[fncGetDataForWriteLog] @ObjectId = @StoredProcedureId, @ObjectType = @ObjectTypeId
		
	   EXEC dbo.SpmLog_Insert @UserId = @ModifiedBy, @SpName = 'SpmStoredProcedure_Update', @ObjectId = @StoredProcedureId, @ObjectTypeId = @ObjectTypeId, @Data = @Data, @OldData = @OldData

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


