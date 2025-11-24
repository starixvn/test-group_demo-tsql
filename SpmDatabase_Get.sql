CREATE PROCEDURE [dbo].[SpmDatabase_Get]
     @AliasServerId INT = NULL
	,@IsActive BIT = NULL
    ,@DatabaseId INT = NULL
AS
/*
Created: 20150326@Aaron.Cao
Task: Get database info from SPM.
DB: SPM
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;
	SELECT DISTINCT db.[DatabaseId]
	     ,db.[Name]
		 ,db.[ExecutionUser]
	     ,db.[Description]
	     ,db.[IsActive]
	FROM [dbo].[SpmDatabase] AS db WITH (NOLOCK)
	LEFT JOIN [dbo].[SpmAliasServerDatabase] AS aliasDb WITH (NOLOCK)
	     ON db.[DatabaseId] = aliasDb.[DatabaseId]
	LEFT JOIN [dbo].[SpmAliasServer] AS alias WITH (NOLOCK)
	     ON aliasDb.[AliasServerId] = alias.[AliasServerId]
	WHERE db.[IsDeleted] = 0
	    AND (@AliasServerId IS NULL OR alias.[IsDeleted] = 0)
		AND (@IsActive IS NULL OR db.[IsActive] = @IsActive)
		AND (@AliasServerId IS NULL OR aliasDb.[AliasServerId] = @AliasServerId)
        AND (@DatabaseId IS NULL OR db.DatabaseId = @DatabaseId)
	ORDER BY db.[Name]
END
