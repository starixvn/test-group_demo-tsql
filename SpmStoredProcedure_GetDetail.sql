CREATE PROCEDURE [dbo].[SpmStoredProcedure_GetDetail]
	@StoredProcedures IntId READONLY,
	@PageIndex              INT = 0,
	@ItemsPerPage           INT = NULL,
	@SearchKey              VARCHAR(500) = NULL,
	@TotalItem              INT = NULL OUT
AS
/*
Created: 20150519@Quinn.Vo
Task: Get sps info by list stored procedure.
DB: SPM
Original: 

Revisions:
    - Larry Tran: added ModifiedDate in the select statement [General info]  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;		

	SET @SearchKey = '%' + RTRIM(LTRIM(@SearchKey)) + '%'

	-- General info
	CREATE TABLE #generalInfo (
	    StoredProcedureId INT,
		SpName VARCHAR(100),
		IsActive BIT,
		CallByWeb BIT,
		CallByExecRef BIT,
		[Description] NVARCHAR(2000),
		ModifiedDate DATETIME,
		AliasServerId INT,
		AssName VARCHAR(100),
		DatabaseId INT,
		DbName VARCHAR(100),
		SpTypeId INT,
		TyName NVARCHAR(100)
	)

	INSERT INTO #generalInfo
	SELECT
	    sp.StoredProcedureId,
		sp.Name,
		sp.IsActive,
		sp.CallByWeb,
		sp.CallByExecRef,
		sp.[Description],
		sp.ModifiedDate,
		ass.AliasServerId,
		ass.Name,
		db.DatabaseId,
		db.Name,
		sp.SpTypeId,
		ty.Name
	FROM @StoredProcedures AS spt 
	INNER JOIN dbo.SpmStoredProcedure AS sp WITH (NOLOCK) ON spt.Id = sp.StoredProcedureId AND sp.IsDeleted = 0
	INNER JOIN dbo.SpmAliasServer AS ass WITH (NOLOCK) ON sp.AliasServerId = ass.AliasServerId AND ass.IsDeleted = 0
	INNER JOIN dbo.SpmDatabase AS db WITH (NOLOCK) ON sp.DatabaseId = db.DatabaseId AND db.IsDeleted = 0
	INNER JOIN dbo.LookupData AS ty WITH (NOLOCK) ON sp.SpTypeId = ty.Value AND ty.LookupId = 2 -- 2: is sp type
	WHERE (IsNull(@SearchKey, '') = '') OR
	      (sp.Name LIKE @SearchKey) OR
		  (ass.Name LIKE @SearchKey) OR
		  (db.Name LIKE @SearchKey)

	--
	IF (@ItemsPerPage IS NULL)
	BEGIN
		SELECT
			gen.StoredProcedureId,
			gen.SpName AS Name,
			gen.IsActive ,
			gen.CallByWeb ,
			gen.CallByExecRef ,
			gen.[Description] ,
			gen.ModifiedDate ,
			gen.AliasServerId ,
			gen.AssName AS Name,
			gen.DatabaseId ,
			gen.DbName AS Name,
			gen.SpTypeId ,
			gen.TyName AS Name
		FROM #generalInfo AS gen
		ORDER BY gen.SpName
	END
	ELSE
	BEGIN
		SELECT
			gen.StoredProcedureId,
			gen.SpName AS Name,
			gen.IsActive ,
			gen.CallByWeb ,
			gen.CallByExecRef ,
			gen.[Description] ,
			gen.ModifiedDate ,
			gen.AliasServerId ,
			gen.AssName AS Name,
			gen.DatabaseId ,
			gen.DbName AS Name,
			gen.SpTypeId ,
			gen.TyName AS Name
		FROM #generalInfo AS gen
		ORDER BY gen.SpName
		OFFSET @PageIndex * @ItemsPerPage ROWS
		FETCH NEXT @ItemsPerPage ROWS ONLY
	END

	SET @TotalItem = (SELECT COUNT(*) AS count FROM #generalInfo)
	
	-- Redmine info
	SELECT spi.StoredProcedureId,
		spi.IssueId,
		spi.ActionName,
		spi.[Description],
		spi.ModifiedDate,
		spi.[Status] AS StatusId,
		spi.VersionId,
		vs.Name AS Name,
		spi.DeveloperId AS UserId,
		e.NickName
	FROM @StoredProcedures AS sp
	INNER JOIN dbo.SpmStoredProcedure AS spt WITH (NOLOCK) ON sp.Id = spt.StoredProcedureId AND spt.IsDeleted = 0
	INNER JOIN dbo.SpmSpIssue AS spi WITH (NOLOCK) ON sp.Id = spi.StoredProcedureId
	LEFT JOIN dbo.LookupData AS vs WITH (NOLOCK) ON spi.VersionId = vs.Value AND vs.LookupId = 3 -- 3: is sp version
	LEFT JOIN dbo.Employee AS e WITH (NOLOCK) ON spi.DeveloperId = e.EmployeeId
	ORDER BY spi.ModifiedDate DESC

	-- Nested sp
	SELECT rl.StoredProcedureId, 		
		rl.NestedSpId, 
		nsp.Name as NestedSpName, 
		ass.AliasServerId, 
		ass.Name as Name, 
		db.DatabaseId, 
		db.Name as Name
	FROM @StoredProcedures AS sp
	INNER JOIN dbo.SpmStoredProcedure AS spt WITH (NOLOCK) ON sp.Id = spt.StoredProcedureId AND spt.IsDeleted = 0
	INNER JOIN dbo.SpmSpRelation AS rl WITH (NOLOCK) ON sp.Id = rl.StoredProcedureId 
	INNER JOIN dbo.SpmStoredProcedure AS nsp WITH (NOLOCK) ON rl.NestedSpId = nsp.StoredProcedureId AND nsp.IsDeleted = 0
	INNER JOIN dbo.SpmAliasServer AS ass WITH (NOLOCK) ON nsp.AliasServerId = ass.AliasServerId AND ass.IsDeleted = 0
	INNER JOIN dbo.SpmDatabase AS db WITH (NOLOCK) ON nsp.DatabaseId = db.DatabaseId AND db.IsDeleted = 0	

	-- system, product, function
	SELECT spf.StoredProcedureId,
		fn.FunctionId,
		fn.Name,
		sy.SystemId,
		sy.Name,
		pr.ProductId,
		pr.Name
	FROM @StoredProcedures AS sp 
	INNER JOIN dbo.SpmStoredProcedure AS spt WITH (NOLOCK) ON sp.Id = spt.StoredProcedureId AND spt.IsDeleted = 0
	INNER JOIN dbo.SpmSpFunction AS spf WITH (NOLOCK) ON sp.Id = spf.StoredProcedureId		
	INNER JOIN dbo.SpmSystem AS sy WITH (NOLOCK) ON spf.SystemId = sy.SystemId AND sy.IsDeleted = 0
	LEFT JOIN dbo.SpmFunction AS fn WITH (NOLOCK) ON spf.FunctionId = fn.FunctionId AND fn.IsDeleted = 0  
	LEFT JOIN dbo.SpmProduct AS pr WITH (NOLOCK) ON spf.ProductId = pr.ProductId AND pr.IsDeleted = 0

	-- tag
	SELECT DISTINCT sp.[Id] AS StoredProcedureId, tag.[TagId], tag.[Name]
     FROM @StoredProcedures AS sp
	INNER JOIN dbo.SpmStoredProcedure AS spt WITH (NOLOCK) ON sp.Id = spt.StoredProcedureId AND spt.IsDeleted = 0
     INNER JOIN [dbo].[SpmTagDetail] AS td WITH(NOLOCK) 
	   ON sp.[Id] = td.[ObjectId] AND td.[Type] = 8
	INNER JOIN [dbo].[SpmTag] AS tag WITH(NOLOCK) 
	   ON td.[TagId] = tag.[TagId] AND tag.IsDeleted = 0	 
      ORDER BY sp.[Id], tag.[Name]
	
END

