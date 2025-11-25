CREATE PROCEDURE [dbo].[SpmStoredProcedure_InsertNestedSp]
	@StoredProcedureId INT
	,@NestedSps NVARCHAR(500) = NULL
AS
/*
Created: 20150420@Quinn.Vo
Task: Insert stored procedure issue.
DB: SPM
Original: 

Revisions:  
Param's Explanation:
- @NestedSpIds: 1,2,3
*/
BEGIN
	SET NOCOUNT ON;
	
	IF OBJECT_ID('tempdb..#NestedSps') IS NOT NULL
	BEGIN
		DROP TABLE #NestedSps
	END 
	CREATE TABLE #NestedSps(NestedSpId INT)

	INSERT INTO #NestedSps
	SELECT val FROM dbo.fnc_strSplit(@NestedSps,',')
	
	--Delete old Nested Sp
	DELETE spre
	FROM dbo.SpmSpRelation AS spre WITH (NOLOCK)	
	WHERE spre.StoredProcedureId = @StoredProcedureId	

	--Insert New Nested Sp
	INSERT INTO dbo.SpmSpRelation(StoredProcedureId, NestedSpId)
	SELECT @StoredProcedureId, nes.NestedSpId
	FROM #NestedSps AS nes

	DROP TABLE #NestedSps
END

