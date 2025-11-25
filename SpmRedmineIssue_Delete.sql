CREATE PROCEDURE [dbo].[SpmRedmineIssue_Delete]
	@IssueId			     INT
	,@StoredProcedureId		INT
     ,@ModifiedBy		     INT = NULL
	
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20150529@Aaron.Cao
Task: Delete stored procedure.
DB: SPM
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	-- todo: check condition.

	DELETE 
	FROM dbo.SpmSpIssue 
	WHERE StoredProcedureId = @StoredProcedureId AND IssueId = @IssueId
END

