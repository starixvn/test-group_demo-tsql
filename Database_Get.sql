CREATE PROCEDURE [dbo].[Database_Get]
AS
/*
Created: 20150416@Quinn.Vo
Task: Get database info from SPM.
DB: SPM
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	SELECT 
		db.DatabaseId AS Id, 
		db.Name,
		db.[Description],
		db.[ExecutionUser],		
		'' AS UserId,
		'' AS [Password],
		asv.AliasServerId AS ServerId,
		asv.Name,
		asv.[Description]
	FROM dbo.SpmDatabase AS db WITH (NOLOCK)
	INNER JOIN dbo.SpmAliasServerDatabase AS adt ON db.DatabaseId = adt.DatabaseId
	INNER JOIN dbo.SpmAliasServer AS asv WITH (NOLOCK) ON adt.AliasServerId = asv.AliasServerId
	WHERE db.IsActive = 1 
		AND asv.IsActive = 1
END

