CREATE PROCEDURE [dbo].[SpmStoredProcedure_InsertIssue]
	@StoredProcedureId		INT
	,@Issues				VARCHAR(MAX) = NULL
     ,@ModifiedBy			INT = NULL
AS
/*
Created: 20150420@Quinn.Vo
Task: Insert stored procedure issue.
DB: SPM
Original: 

Revisions:  
Param's Explanation:
- @IssueIds: <ROOT>
				<Issue IssueId="1" DeveloperId="1" ActionName="A" Status="1" VersionId="1" Description='Test'><Issue/>
			 </ROOT>
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @DocHandler INT
	IF OBJECT_ID('tempdb..#Issues') IS NOT NULL
	BEGIN
		DROP TABLE #Issues
	END 
	CREATE TABLE #Issues(IssueId INT, DeveloperId INT, ActionName VARCHAR(10), VersionId INT, [Status] INT, [Description] NVARCHAR(300))

	EXEC sp_xml_preparedocument @DocHandler OUTPUT, @Issues
	INSERT INTO #Issues(IssueId, DeveloperId, ActionName, VersionId, [Status], [Description])
	SELECT IssueId, DeveloperId, ActionName, VersionId, Status, Description 
	FROM OPENXML(@DocHandler, '/ROOT/Issue', 1) 
	WITH (IssueId INT, DeveloperId INT, ActionName VARCHAR(10), VersionId INT, Status INT, Description NVARCHAR(300)) AS Data
	EXEC sp_xml_removedocument @DocHandler

	DELETE spi
	FROM dbo.SpmSpIssue AS spi WITH (NOLOCK)
	LEFT JOIN #Issues AS iss ON spi.IssueId = iss.IssueId AND spi.StoredProcedureId = @StoredProcedureId
	WHERE spi.StoredProcedureId = @StoredProcedureId
	AND iss.IssueId IS NULL

	UPDATE spi
	SET spi.DeveloperId = iss.DeveloperId,
		spi.ActionName = iss.ActionName,
		spi.VersionId = iss.VersionId,
		spi.[Description] = iss.[Description],
		spi.[Status] = iss.[Status]          
	FROM dbo.SpmSpIssue AS spi WITH (NOLOCK)
	INNER JOIN #Issues AS iss ON spi.IssueId = iss.IssueId AND spi.StoredProcedureId = @StoredProcedureId

	DELETE iss
	FROM dbo.SpmSpIssue AS spi WITH (NOLOCK)
	INNER JOIN #Issues AS iss ON spi.IssueId = iss.IssueId AND spi.StoredProcedureId = @StoredProcedureId

	INSERT INTO dbo.SpmSpIssue(StoredProcedureId, IssueId, DeveloperId, ActionName, VersionId, [Status], [Description],ModifiedBy,ModifiedDate)
	SELECT @StoredProcedureId, iss.IssueId, iss.DeveloperId, iss.ActionName, iss.VersionId, iss.[Status], iss.[Description],@ModifiedBy, GETDATE()
	FROM #Issues AS iss

	DROP TABLE #Issues
END


