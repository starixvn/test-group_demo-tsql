CREATE FUNCTION [dbo].[fnGetDbServerName]
(
	@AliasServerId INT,
	@EnvironmentId INT
)
RETURNS VARCHAR(100)
AS
BEGIN
    DECLARE @DbServerName VARCHAR(100)

    SELECT @DbServerName = dbServer.Name 
    FROM dbo.SpmAliasServerEnvironment AS aev WITH(NOLOCK)
	   INNER JOIN dbo.SpmDbServer AS dbServer WITH(NOLOCK)
		  ON aev.DbServerId = dbServer.DbServerId
    WHERE dbServer.IsActive =1
	   AND aev.AliasServerId = @AliasServerId 
	   AND aev.EnvironmentId = @EnvironmentId
	
	RETURN @DbServerName
END

