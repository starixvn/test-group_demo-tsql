--EXEC SpmStoredProcedure_GetDependencies 368,1009,1018,2
CREATE PROC [dbo].[SpmStoredProcedure_GetDependencies]
    @StoredProcedureId INT,
    @AliasServerId INT,
    @DatabaseId INT,
    @DependencyType TINYINT
AS
/*
Created: 20150820@Larry.Tran
Task: Get the dependencies of SP.
DB: SPM
Original: 

Revisions:  
Param's Explanation:
    - @DependencyType:
	   1 - Being Called By SPs
	   2 - Calling SPs
*/
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @BeingCalled TINYINT = 1
    DECLARE @Calling TINYINT = 2

    CREATE TABLE #tblDependencies(
	   ParentId INT,
	   StoredProcedureId INT,
	   SpName VARCHAR(100),
	   CallByWeb BIT,
	   AliasServerId INT,
	   AliasServerName VARCHAR(100),
	   DatabaseId INT,
	   DatabaseName VARCHAR(100)
    )

    IF @DependencyType = @BeingCalled
    BEGIN
	   --Recursive nested sp
	   WITH Dependencies(
		  ParentId,
		  StoredProcedureId,
		  SpName,
		  CallByWeb,
		  AliasServerId,
		  AliasServerName,
		  DatabaseId,
		  DatabaseName
	   ) AS (
		  (SELECT 
			 NULL AS ParentId,
			 sp.StoredProcedureId,
			 sp.Name AS SpName,
			 sp.CallByWeb,
			 alias.AliasServerId,
			 alias.Name AS AliasServerName,
			 db.DatabaseId,
			 db.Name AS DatabaseName
		  FROM dbo.SpmStoredProcedure AS sp WITH(NOLOCK)
			 INNER JOIN dbo.SpmAliasServer AS alias WITH(NOLOCK)
				ON alias.AliasServerId = sp.AliasServerId
				    AND alias.IsDeleted = 0
				    AND alias.IsActive = 1
			 INNER JOIN dbo.SpmDatabase AS db WITH(NOLOCK)
				ON db.DatabaseId = sp.DatabaseId
				    AND db.IsDeleted = 0
				    AND db.IsActive = 1
		  WHERE sp.IsDeleted = 0
			 AND sp.IsActive = 1
			 AND sp.StoredProcedureId = @StoredProcedureId
			 AND sp.AliasServerId = @AliasServerId
			 AND sp.DatabaseId = @DatabaseId
		  )
		  UNION ALL
		  (SELECT 
			 sp.StoredProcedureId AS ParentId,
			 nestedSp.StoredProcedureId,
			 nestedSp.Name AS SpName,
			 nestedSp.CallByWeb,
			 alias.AliasServerId,
			 alias.Name AS AliasServerName,
			 db.DatabaseId,
			 db.Name AS DatabaseName
		  FROM Dependencies AS sp
			 INNER JOIN dbo.SpmSpRelation AS r WITH(NOLOCK)
				ON r.NestedSpId = sp.StoredProcedureId
			 INNER JOIN dbo.SpmStoredProcedure AS nestedSp WITH(NOLOCK)
				ON nestedSp.StoredProcedureId = r.StoredProcedureId
				    AND nestedSp.IsDeleted = 0
				    AND nestedSp.IsActive = 1
			 INNER JOIN dbo.SpmAliasServer AS alias WITH(NOLOCK)
				ON alias.AliasServerId = nestedSp.AliasServerId
				    AND alias.IsDeleted = 0
				    AND alias.IsActive = 1
			 INNER JOIN dbo.SpmDatabase AS db WITH(NOLOCK)
				ON db.DatabaseId = nestedSp.DatabaseId
				    AND db.IsDeleted = 0
				    AND db.IsActive = 1
		  )							  
	   )
	   INSERT INTO #tblDependencies	   
	   SELECT ParentId,
		  StoredProcedureId,
		  SpName AS Name,
		  CallByWeb,
		  AliasServerId,
		  AliasServerName AS Name,
		  DatabaseId,
		  DatabaseName AS Name
	   FROM Dependencies	   
    END
    ELSE IF @DependencyType = @Calling
    BEGIN
	   --Recursive nested sp
	   WITH Dependencies(
		  ParentId,
		  StoredProcedureId,
		  SpName,
		  CallByWeb,
		  AliasServerId,
		  AliasServerName,
		  DatabaseId,
		  DatabaseName
	   ) AS (
		  (SELECT 
			 NULL AS ParentId,
			 sp.StoredProcedureId,
			 sp.Name AS SpName,
			 sp.CallByWeb,
			 alias.AliasServerId,
			 alias.Name AS AliasServerName,
			 db.DatabaseId,
			 db.Name AS DatabaseName
		  FROM dbo.SpmStoredProcedure AS sp WITH(NOLOCK)
			 INNER JOIN dbo.SpmAliasServer AS alias WITH(NOLOCK)
				ON alias.AliasServerId = sp.AliasServerId
				    AND alias.IsDeleted = 0
				    AND alias.IsActive = 1
			 INNER JOIN dbo.SpmDatabase AS db WITH(NOLOCK)
				ON db.DatabaseId = sp.DatabaseId
				    AND db.IsDeleted = 0
				    AND db.IsActive = 1
		  WHERE sp.IsDeleted = 0
			 AND sp.IsActive = 1
			 AND sp.StoredProcedureId = @StoredProcedureId
			 AND sp.AliasServerId = @AliasServerId
			 AND sp.DatabaseId = @DatabaseId
		  )
		  UNION ALL
		  (SELECT 
			 sp.StoredProcedureId AS ParentId,
			 nestedSp.StoredProcedureId,
			 nestedSp.Name AS SpName,
			 nestedSp.CallByWeb,
			 alias.AliasServerId,
			 alias.Name AS AliasServerName,
			 db.DatabaseId,
			 db.Name AS DatabaseName
		  FROM Dependencies AS sp
			 INNER JOIN dbo.SpmSpRelation AS r WITH(NOLOCK)
				ON r.StoredProcedureId = sp.StoredProcedureId
			 INNER JOIN dbo.SpmStoredProcedure AS nestedSp WITH(NOLOCK)
				ON nestedSp.StoredProcedureId = r.NestedSpId
				    AND nestedSp.IsDeleted = 0
				    AND nestedSp.IsActive = 1
			 INNER JOIN dbo.SpmAliasServer AS alias WITH(NOLOCK)
				ON alias.AliasServerId = nestedSp.AliasServerId
				    AND alias.IsDeleted = 0
				    AND alias.IsActive = 1
			 INNER JOIN dbo.SpmDatabase AS db WITH(NOLOCK)
				ON db.DatabaseId = nestedSp.DatabaseId
				    AND db.IsDeleted = 0
				    AND db.IsActive = 1
		  )							  
	   )
	   INSERT INTO #tblDependencies
	   SELECT ParentId,
		  StoredProcedureId,
		  SpName AS Name,
		  CallByWeb,
		  AliasServerId,
		  AliasServerName AS Name,
		  DatabaseId,
		  DatabaseName AS Name
	   FROM Dependencies AS d
    END

    --Dependencies
    SELECT ParentId,
	   StoredProcedureId,
	   SpName AS Name,
	   CallByWeb,
	   AliasServerId,
	   AliasServerName AS Name,
	   DatabaseId,
	   DatabaseName AS Name
    FROM #tblDependencies

    --System Functions
    SELECT
	   sp.StoredProcedureId,
	   s.SystemId,
	   s.Name,
	   s.[Description],
	   ISNULL(fg.FunctionGroupId,0) AS FunctionGroupId,
	   ISNULL(fg.Name,'None Group') AS Name,
	   f.FunctionId,
	   f.Name,
	   f.[Description]	   		 
    FROM dbo.SpmSystem AS s WITH (NOLOCK) 	   
        INNER JOIN dbo.SpmSpFunction AS sf WITH (NOLOCK)
		    ON sf.SystemId = s.SystemId
	    INNER JOIN dbo.SpmStoredProcedure AS sp WITH (NOLOCK)
		    ON sp.StoredProcedureId = sf.StoredProcedureId AND sp.IsActive = 1 AND sp.IsDeleted = 0
	    LEFT JOIN dbo.SpmFunction AS f WITH (NOLOCK) 
		    ON f.FunctionId = sf.FunctionId AND f.IsActive = 1 AND f.IsDeleted = 0
	    LEFT JOIN dbo.SpmFunctionGroup AS fg WITH(NOLOCK)
		    ON fg.FunctionGroupId = f.FunctionGroupId AND fg.IsActive = 1 AND fg.IsDeleted = 0	   
	    INNER JOIN #tblDependencies AS depend
		    ON depend.StoredProcedureId = sp.StoredProcedureId	  
    WHERE
	   s.IsActive = 1
	   AND s.IsDeleted = 0
    GROUP BY
	   sp.StoredProcedureId,
	   s.SystemId,
	   s.Name,
	   s.[Description],
	   ISNULL(fg.FunctionGroupId,0),
	   ISNULL(fg.Name,'None Group'),
	   f.FunctionId,
	   f.Name,
	   f.[Description]    
END
