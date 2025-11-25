CREATE PROCEDURE [dbo].[GetSPsExecutionCounts]
	@From DATETIME = NULL, 
	@To DATETIME = NULL,
    @Server VARCHAR(100) = NULL,
    @Database VARCHAR(100) = NULL
AS
BEGIN	
	SET NOCOUNT ON;

    SELECT TOP 50
        sp.Name AS SPName,
        al.Name AS ServerAlias,
        db.Name AS DBName,
        ds.Name AS ServerName
    FROM dbo.SpmStoredProcedure AS sp WITH(NOLOCK)
        INNER JOIN dbo.SpmAliasServer AS al WITH(NOLOCK) ON sp.AliasServerId = al.AliasServerId
        INNER JOIN dbo.SpmDatabase AS db WITH(NOLOCK) ON sp.DatabaseId = db.DatabaseId       
        INNER JOIN dbo.SpmAliasServerEnvironment AS ae WITH(NOLOCK) ON ae.AliasServerId = al.AliasServerId AND ae.EnvironmentId = 4
        INNER JOIN dbo.SpmDbServer AS ds WITH(NOLOCK) ON ds.DbServerId = ae.DbServerId
END