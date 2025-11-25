CREATE PROCEDURE [dbo].[SpmStoredProcedure_GetById]
	@StoredProcedureId	INT = NULL
AS
/*
Created: 20150508@Quinn.Vo
Task: Get sp info by id .
DB: SPM
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @StoredProcedures IntId

	INSERT INTO @StoredProcedures (Id) VALUES(@StoredProcedureId)

	EXECUTE [dbo].[SpmStoredProcedure_GetDetail] @StoredProcedures
END

