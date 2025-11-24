CREATE PROCEDURE [dbo].[SpmDbServer_GetById]
	@DbServerId INT	
AS
/*
Created: 20150325@Tim.Trinh
Task: Get Db Server info from SPM.
DB: SPM
Original: 

Revisions:
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT 
        s.[DbServerId],
        s.Name, 
        s.Description
	FROM [dbo].[SpmDbServer] AS s WITH(NOLOCK)	
	WHERE s.IsDeleted = 0
        AND s.DbServerId = @DbServerId	
END