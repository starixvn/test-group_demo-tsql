CREATE PROCEDURE [dbo].[SpmDbServer_GetByAliasServerId] 
    @AliasServerId INT
AS
BEGIN	
	SET NOCOUNT ON;

    DECLARE @EnvironmentLookupId INT = 1

    SELECT
        ds.DbServerId, 
        ds.Name + ' (' + ld.Name + ')' AS Name,
        ae.EnvironmentId
    FROM dbo.SpmDbServer AS ds WITH(NOLOCK)
        INNER JOIN dbo.SpmAliasServerEnvironment AS ae WITH(NOLOCK) ON ds.DbServerId = ae.DbServerId        
        INNER JOIN dbo.LookupData AS ld WITH(NOLOCK) ON ld.[Value] = ae.EnvironmentId AND ld.LookupId = @EnvironmentLookupId
    WHERE ae.AliasServerId = @AliasServerId AND
        ds.IsDeleted = 0
END