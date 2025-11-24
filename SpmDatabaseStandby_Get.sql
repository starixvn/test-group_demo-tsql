CREATE PROCEDURE [dbo].[SpmDatabaseStandby_Get]
    @AliasServerId INT = NULL,
    @DbServerId INT = NULL,
    @DatabaseId INT = NULL,    
	@IsActive BIT = NULL,
    @IncludeEnvironmentName BIT = 1
AS
/*
Created: 20181015@Larry
Task: Get standby database info from NDict.
DB: NDict
Original: 

Revisions:  
20250917@Alex: Added @IncludeEnvironmentName parameter to control whether to include environment name in DB server name

Param's Explanation:
- @AliasServerId: Filter by Alias Server ID
- @DbServerId: Filter by Database Server ID
- @DatabaseId: Filter by Database ID
- @IsActive: Filter by active status
- @IncludeEnvironmentName: If 1 (default), includes environment name in DB server name format "ServerName (EnvironmentName)". If 0, returns only "ServerName".

*/
BEGIN
	SET NOCOUNT ON;

    DECLARE @LookupEnvironmentId INT = 1

    CREATE TABLE #tblStandbyDb(
        StandbyId INT, 
        IsActive BIT,
        AliasServerId INT, 
        AliasServerName VARCHAR(100),
        DbServerId INT, 
        DbServerName VARCHAR(100),
        EnvironmentId INT,
        DatabaseId INT, 
        DatabaseName VARCHAR(100)
    )

    INSERT INTO #tblStandbyDb
    SELECT
        sb.StandbyId, 
        sb.IsActive,
        al.AliasServerId, 
        al.Name,
        ds.DbServerId, 
        CASE WHEN @IncludeEnvironmentName = 1 THEN ds.Name + ' (' + ld.Name + ')' ELSE ds.Name END,
        sb.EnvironmentId,
        db.DatabaseId, 
        db.Name
    FROM dbo.SpmDatabaseStandby AS sb WITH(NOLOCK)
        INNER JOIN dbo.SpmAliasServer AS al WITH(NOLOCK) ON sb.AliasServerId = al.AliasServerId AND al.IsDeleted = 0
        INNER JOIN dbo.SpmAliasServerEnvironment AS ae WITH(NOLOCK) ON ae.AliasServerId = al.AliasServerId AND ae.EnvironmentId = sb.EnvironmentId
        INNER JOIN dbo.SpmDbServer AS ds WITH(NOLOCK) ON ae.DbServerId = ds.DbServerId AND ds.IsDeleted = 0
        INNER JOIN dbo.SpmDatabase AS db WITH(NOLOCK) ON sb.DatabaseId = db.DatabaseId AND db.IsDeleted = 0        
        INNER JOIN dbo.LookupData AS ld WITH(NOLOCK) ON ld.[Value] = ae.EnvironmentId AND ld.LookupId = @LookupEnvironmentId        
    WHERE
        sb.IsDeleted = 0 AND
        (@IsActive IS NULL OR sb.[IsActive] = @IsActive) AND
        (@AliasServerId IS NULL OR al.[AliasServerId] = @AliasServerId) AND
        (@DbServerId IS NULL OR ds.DbServerId = @DbServerId) AND
        (@DatabaseId IS NULL OR db.DatabaseId = @DatabaseId)    

    SELECT
        sb.StandbyId, 
        sb.IsActive, 
        sb.AliasServerId, 
        sb.AliasServerName AS Name, 
        sb.DbServerId, 
        sb.DbServerName AS Name,
        sb.EnvironmentId, 
        sb.DatabaseId, 
        sb.DatabaseName AS Name
    FROM #tblStandbyDb AS sb
    ORDER BY sb.AliasServerName, 
        sb.DbServerName, 
        sb.DatabaseName

    SELECT
        sr.StandbyId, 
        sr.DbServerId,
        ds.Name, 
        sr.DatabaseId,
        db.Name
    FROM #tblStandbyDb AS sb
        INNER JOIN dbo.SpmDatabaseStandbyRelation AS sr WITH(NOLOCK) ON sb.StandbyId = sr.StandbyId
        INNER JOIN dbo.SpmDbServer AS ds WITH(NOLOCK) ON sr.DbServerId = ds.DbServerId AND ds.IsDeleted = 0
        INNER JOIN dbo.SpmDatabase AS db WITH(NOLOCK) ON sr.DatabaseId = db.DatabaseId AND db.IsDeleted = 0
    ORDER BY ds.Name,
        db.Name
END