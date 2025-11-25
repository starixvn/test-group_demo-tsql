CREATE PROCEDURE [dbo].[SpmStoredProcedure_InsertFunction]
	@StoredProcedureId		INT
	,@Functions				NVARCHAR(MAX) = NULL
	,@ModifiedBy			INT = NULL
AS
/*
Created: 20150420@Quinn.Vo
Task: Insert stored procedure function.
DB: SPM
Original: 

Revisions:  
Param's Explanation:
- @Functions: <ROOT>
					<Function FunctionId="1" SystemId="1" ProductId="1"><Function/>
			  </ROOT>
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @DocHandler INT
	
	CREATE TABLE #Functions(FunctionId INT, SystemId INT, ProductId INT NULL)

	EXEC sp_xml_preparedocument @DocHandler OUTPUT, @Functions
	INSERT INTO #Functions(SystemId, ProductId, FunctionId)
	SELECT 
        SystemId, 
        (CASE WHEN ISNULL(ProductId, 0) = 0 THEN -1 ELSE ProductId END) AS ProductId, 
        (CASE WHEN ISNULL(FunctionId, 0) = 0 THEN -1 ELSE FunctionId END) AS FunctionId
	FROM OPENXML(@DocHandler, '/ROOT/Function', 1) 
	WITH (SystemId INT, ProductId INT, FunctionId INT) AS Data
	EXEC sp_xml_removedocument @DocHandler

	DELETE spf
	FROM dbo.SpmSpFunction AS spf WITH (NOLOCK)
	LEFT JOIN #Functions AS fn ON spf.FunctionId = fn.FunctionId 
		AND fn.SystemId = spf.SystemId
		AND fn.ProductId = spf.ProductId
	WHERE spf.StoredProcedureId = @StoredProcedureId
	AND fn.FunctionId IS NULL

	DELETE fn
	FROM dbo.SpmSpFunction AS spf WITH (NOLOCK)
	INNER JOIN #Functions AS fn ON spf.FunctionId = fn.FunctionId 
		AND fn.SystemId = spf.SystemId
		AND fn.ProductId = spf.ProductId
		AND spf.StoredProcedureId = @StoredProcedureId

	INSERT INTO dbo.SpmSpFunction(StoredProcedureId, FunctionId, SystemId, ProductId, ModifiedBy, ModifiedDate)
	SELECT 
		@StoredProcedureId, 
		fn.FunctionId, 
		fn.SystemId, 
		fn.ProductId, 
		@ModifiedBy, 
		GETDATE()
	FROM #Functions AS fn
END

