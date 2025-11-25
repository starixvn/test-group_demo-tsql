CREATE PROCEDURE [dbo].[SpmStoredProcedure_UpdateStatus]	
	@StoredProcedureId		INT
	,@IsActive				BIT = 0
	,@ModifiedBy			INT = NULL
	
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20150511@Quinn.Vo
Task: Update active/deactive for stored procedure. 
DB: SPM
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;	
	DECLARE @Data NVARCHAR(MAX), @OldData NVARCHAR(MAX)
	
	IF (@IsActive = 1 AND (EXISTS (SELECT 1
			 FROM [dbo].[SpmAliasServer] AS asv WITH (NOLOCK)
			 INNER JOIN [dbo].[SpmStoredProcedure] AS st WITH (NOLOCK) ON asv.AliasServerId = st.AliasServerId
			 WHERE st.StoredProcedureId = @StoredProcedureId
				AND asv.IsActive = 0)
		OR EXISTS (SELECT 1 FROM [dbo].[SpmDatabase] AS db WITH (NOLOCK)
			INNER JOIN [dbo].[SpmStoredProcedure] AS st WITH (NOLOCK) ON db.DatabaseId = st.DatabaseId
			WHERE st.StoredProcedureId = @StoredProcedureId
				AND db.IsActive = 0)))
	BEGIN
	     SELECT @ErrCode = 100
	           ,@ErrMsg = 'You can not activate this Stored Procedure because Alias Server or Database are been deactivate.'
	     RETURN
	END

	IF (@IsActive = 1 AND (EXISTS (SELECT 1
			 FROM [dbo].[SpmSystem] AS st WITH (NOLOCK)
			 INNER JOIN [dbo].[SpmSpFunction] AS sfn WITH (NOLOCK) ON sfn.SystemId = st.SystemId
			 WHERE sfn.StoredProcedureId = @StoredProcedureId
				AND st.IsActive = 0)
		OR EXISTS (SELECT 1 FROM [dbo].[SpmProduct] AS pr WITH (NOLOCK)
			INNER JOIN [dbo].[SpmSpFunction] AS sfn WITH (NOLOCK) ON sfn.ProductId = pr.ProductId
			 WHERE sfn.StoredProcedureId = @StoredProcedureId
				AND pr.IsActive = 0)
		OR EXISTS (SELECT 1 FROM [dbo].[SpmFunction] AS fn WITH (NOLOCK)
			INNER JOIN [dbo].[SpmSpFunction] AS sfn WITH (NOLOCK) ON sfn.FunctionId = fn.FunctionId
			 WHERE sfn.StoredProcedureId = @StoredProcedureId
				AND fn.IsActive = 0)))
	BEGIN
	     SELECT @ErrCode = 100
	           ,@ErrMsg = 'You can not activate this Stored Procedure because System/Product/Function are been deactivate.'
	     RETURN
	END

	EXEC @OldData = [dbo].[fncGetDataForWriteLogStatus] @ObjectId = @StoredProcedureId, @ObjectType = 8

	UPDATE dbo.SpmStoredProcedure WITH(ROWLOCK,UPDLOCK)
	SET [IsActive] = @IsActive
		,[ModifiedBy] = @ModifiedBy
		,[ModifiedDate] = GETDATE()	
	WHERE StoredProcedureId = @StoredProcedureId

	EXEC @Data = [dbo].[fncGetDataForWriteLogStatus] @ObjectId = @StoredProcedureId, @ObjectType = 8
	EXEC dbo.SpmLog_Insert @UserId = @ModifiedBy, @SpName = 'SpmStoredProcedure_UpdateStatus', @ObjectId = @StoredProcedureId, @ObjectTypeId = 8, @Data = @Data, @OldData = @OldData
END

