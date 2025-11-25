CREATE PROCEDURE [dbo].[SpmRedmineIssue_Get]
    @IssueIds NVARCHAR(MAX) = NULL
AS
/*
Created: 20150529@Aaron.Cao
Task: Get an Issue info.
DB: SPM
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
    SET NOCOUNT ON;

    CREATE TABLE #Issues(IssueId INT)
	IF ISNULL(@IssueIds, '') <> ''
	BEGIN
		INSERT INTO #Issues (IssueId)
		SELECT DISTINCT CAST(val AS INT) FROM fnc_strSplit (@IssueIds, ',')
	END	

	-- Issue Sp
    SELECT iss.[IssueId],   
	   sp.[StoredProcedureId],
	   sp.[Name],
	   sp.[IsActive],
	   sp.[CallByWeb],
	   sp.[CallByExecRef],
	   spi.[Description],
	   spi.[ActionName],	   
	   spi.[Status] AS StatusId,
	   alias.[AliasServerId],
	   alias.[Name],
	   db.[DatabaseId],
	   db.[Name],
	   sp.[SpTypeId],
	   ty.[Name],
	   spi.[DeveloperId] AS UserId,
	   e.[NickName],
	   spi.[VersionId],
	   vs.[Name]	   
    FROM #Issues AS iss
		INNER JOIN dbo.[SpmSpIssue] AS spi WITH (NOLOCK)
			ON iss.[IssueId] = spi.[IssueId]
		INNER JOIN [dbo].[SpmStoredProcedure] AS sp WITH (NOLOCK) 
			ON sp.[StoredProcedureId] = spi.[StoredProcedureId] AND sp.IsDeleted = 0
		INNER JOIN [dbo].[SpmAliasServer] AS alias WITH (NOLOCK)
			ON sp.[AliasServerId] = alias.[AliasServerId] AND alias.IsDeleted = 0
		INNER JOIN [dbo].[SpmDatabase] AS db WITH (NOLOCK)
			ON sp.[DatabaseId] = db.[DatabaseId] AND db.IsDeleted = 0
		LEFT JOIN [dbo].[LookupData] AS ty WITH (NOLOCK)
			ON sp.[SpTypeId] = ty.[Value] 
			AND ty.[LookupId] = 2 -- sp type
		LEFT JOIN [dbo].[LookupData] AS vs WITH (NOLOCK) 
			ON spi.[VersionId] = vs.[Value]
				AND vs.[LookupId] = 3 -- sp version
		LEFT JOIN [dbo].[Employee] AS e WITH (NOLOCK) 
			ON spi.[DeveloperId] = e.[EmployeeId]

    --Nested Sp
    SELECT DISTINCT rl.[StoredProcedureId],
        rl.[NestedSpId], 
        nsp.[Name] as NestedSpName,
	   alias.AliasServerId,
	   alias.Name,
	   db.DatabaseId,
	   db.Name
    FROM #Issues AS iss WITH (NOLOCK)
    INNER JOIN dbo.SpmSpIssue AS spi WITH(NOLOCK)
	   ON spi.IssueId = iss.IssueId
    INNER JOIN [dbo].[SpmSpRelation] AS rl WITH (NOLOCK)
        ON rl.StoredProcedureId = spi.StoredProcedureId
    INNER JOIN [dbo].[SpmStoredProcedure] AS sp WITH (NOLOCK)
        ON rl.[StoredProcedureId] = sp.[StoredProcedureId] AND sp.IsDeleted = 0
    INNER JOIN [dbo].[SpmStoredProcedure] AS nsp WITH (NOLOCK)
        ON rl.[NestedSpId] = nsp.[StoredProcedureId] AND nsp.IsDeleted = 0
    INNER JOIN [dbo].[SpmAliasServer] AS alias WITH (NOLOCK)
	   ON nsp.[AliasServerId] = alias.[AliasServerId] AND alias.IsDeleted = 0
    INNER JOIN [dbo].[SpmDatabase] AS db WITH (NOLOCK)
	   ON nsp.[DatabaseId] = db.[DatabaseId] AND db.IsDeleted = 0
    
    -- System / Product / Function
    SELECT DISTINCT sp.StoredProcedureId,
	   s.SystemId,
	   s.Name,
	   p.ProductId,
	   p.Name,
	   f.FunctionId,
	   f.Name
    FROM #Issues AS iss
	   INNER JOIN dbo.SpmSpIssue AS spi WITH(NOLOCK)
		  ON iss.IssueId = spi.IssueId
	   INNER JOIN dbo.SpmStoredProcedure AS sp WITH(NOLOCK)
		  ON spi.StoredProcedureId = sp.StoredProcedureId AND sp.IsDeleted = 0
	   INNER JOIN dbo.SpmSpFunction AS spf WITH(NOLOCK)
		  ON spf.StoredProcedureId = sp.StoredProcedureId
	   INNER JOIN dbo.SpmSystem AS s WITH(NOLOCK)
		  ON s.SystemId = spf.SystemId AND s.IsDeleted = 0
	   LEFT JOIN dbo.SpmFunction AS f WITH(NOLOCK)
		  ON f.FunctionId = spf.FunctionId AND f.IsDeleted = 0
	   LEFT JOIN dbo.SpmProduct AS p WITH(NOLOCK)
		  ON p.ProductId = spf.ProductId AND p.IsDeleted = 0  
END

