CREATE PROCEDURE [dbo].[SpmAliasServer_Get]
	@DbServerIds VARCHAR(MAX)=NULL,
	@DatabaseIds VARCHAR(MAX)=NULL,
	@IsActive BIT=NULL 
AS
/*
Created: 20150318@Josh.Phan
Task: Get Alias Server.
DB: SPM
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
    SET NOCOUNT ON;	

    DECLARE @LookupEnvironmentId INT = 1
    
    CREATE TABLE #DBServer (
	   DBServerId  SMALLINT)

    IF ISNULL(@DbServerIds,'') <> ''
    BEGIN
	   INSERT INTO #DBServer (
		  DBServerId )
	   SELECT DISTINCT val FROM fnc_strSplit (@DbServerIds, ',')
    END	
	
    CREATE TABLE #Database (
	   DatabaseId  SMALLINT)

    IF ISNULL(@DatabaseIds,'') <> ''
    BEGIN
	   INSERT INTO #Database (
		  DatabaseId )
	   SELECT DISTINCT val FROM fnc_strSplit (@DatabaseIds, ',')
    END    

    CREATE TABLE #tblAliasServer (
	   AliasServerId  INT,
	   Name VARCHAR(100),
	   [Description] NVARCHAR(2000),
	   IsActive BIT,
	   ModifiedBy INT,
	   ModifiedDate DATETIME
    )	
    
    INSERT INTO #tblAliasServer
    (
        AliasServerId,
        Name,
        [Description],
        IsActive,
        ModifiedBy,
        ModifiedDate
    )    
    SELECT DISTINCT
	   ali.[AliasServerId]
	   ,ali.[Name]
	   ,ali.[Description]
	   ,ali.[IsActive]
	   ,ali.[ModifiedBy]
	   ,ali.[ModifiedDate]
    FROM [dbo].[SpmAliasServer] AS ali WITH (NOLOCK)
	   LEFT JOIN [dbo].[SpmAliasServerEnvironment] AS aev WITH (NOLOCK) 
		  ON ali.[AliasServerId] = aev.[AliasServerId]
	   LEFT JOIN dbo.SpmDbServer AS ds WITH(NOLOCK)
		  ON ds.DbServerId = aev.DbServerId
			 AND ds.IsDeleted = 0
	   INNER JOIN dbo.SpmAliasServerDatabase AS aliasDb WITH(NOLOCK)
		  ON aliasDb.AliasServerId = ali.AliasServerId
	   INNER JOIN dbo.SpmDatabase AS db WITH(NOLOCK)
		  ON db.DatabaseId = aliasDb.DatabaseId
			 AND db.IsDeleted = 0
    WHERE ali.IsDeleted = 0
	   AND (
		  @IsActive IS NULL 
		  OR ali.[IsActive] = @IsActive
	   )
	   AND (
		  ISNULL(@DbServerIds,'') = '' 
		  OR ds.DbServerId IN (SELECT DBServerId FROM #DBServer)
	   )
	   AND (
		  ISNULL(@DatabaseIds,'') = '' 
		  OR db.DatabaseId IN (SELECT DatabaseId FROM #Database)
	   )	   
    ORDER BY ali.[Name]
    
    SELECT AliasServerId,
        Name,
        [Description],
        IsActive,
        ModifiedBy,
        ModifiedDate
    FROM #tblAliasServer
    	
    SELECT alias.[AliasServerId]
	   ,aev.[EnvironmentId] 
	   ,aev.[DbServerId]	
	   ,dbSer.[Name] AS DbServerName
    FROM #tblAliasServer AS alias
	   INNER JOIN [dbo].[SpmAliasServerEnvironment] AS aev WITH (NOLOCK)
		  ON alias.[AliasServerId] = aev.[AliasServerId]
	   INNER JOIN [dbo].[SpmDbServer] AS dbSer WITH (NOLOCK) 
		  ON aev.[DbServerId] = dbSer.[DbServerId]
			 AND dbSer.IsDeleted = 0
	
    SELECT 
	   alDb.[AliasServerId]
	   ,alDb.[DatabaseId]
	   ,db.[Name]
    FROM [dbo].[SpmAliasServerDatabase] AS alDb WITH (NOLOCK)
	   INNER JOIN #tblAliasServer AS alias 
		  ON alDb.[AliasServerId] = alias.[AliasServerId]
	   INNER JOIN [dbo].[SpmDatabase] AS db WITH (NOLOCK) 
		  ON alDb.[DatabaseId] = db.[DatabaseId]

    SELECT 
	    ad.[AliasServerId]
        ,db.DatabaseId
        ,db.Name AS DatabaseName
	   ,ad.EnvironmentId
       ,ld.Name AS EnvironmentName	  
    FROM dbo.SpmAliasServerNoDeployment AS ad WITH (NOLOCK)
	   INNER JOIN #tblAliasServer AS alias 
		  ON ad.[AliasServerId] = alias.[AliasServerId]	
        INNER JOIN dbo.LookupData AS ld WITH(NOLOCK) ON ad.EnvironmentId = ld.[Value] AND ld.LookupId = @LookupEnvironmentId
        INNER JOIN dbo.SpmDatabase AS db WITH(NOLOCK) ON ad.DatabaseId = db.DatabaseId
    ORDER BY db.Name,
        ad.EnvironmentId
END

