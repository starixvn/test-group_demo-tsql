CREATE PROCEDURE [dbo].[SpmSpIssue_ChangeVersion]
	@SpInfo SpInfo READONLY,
    @RedmineIds VARCHAR(1000),
    @Version VARCHAR(50),
    @ModifiedBy INT    
AS
BEGIN	
	SET NOCOUNT ON;

    DECLARE @Original INT = 1
    DECLARE @SpVersion INT = 3
    DECLARE @VersionId INT = ISNULL((
        SELECT TOP 1 ld.[Value]
        FROM dbo.LookupData AS ld WITH(NOLOCK)
        WHERE 
            ld.LookupId = @SpVersion AND
            ld.Name = @Version            
    ), @Original)
    DECLARE @tblScript AS TABLE(SpId INT)
    DECLARE @tblRedmine AS TABLE(RedmineId INT)

    INSERT INTO @tblScript
    SELECT DISTINCT
        sp.StoredProcedureId
    FROM @SpInfo i        
        INNER JOIN dbo.SpmAliasServer AS al WITH(NOLOCK) ON i.[ServerAlias] = al.Name
        INNER JOIN dbo.SpmDatabase AS db WITH(NOLOCK) ON i.[Database] = db.Name
        INNER JOIN dbo.SpmStoredProcedure AS sp WITH(NOLOCK) 
            ON i.[SpName] = sp.Name AND
                sp.AliasServerId = al.AliasServerId AND
                sp.DatabaseId = db.DatabaseId
    
    INSERT INTO @tblRedmine
    SELECT DISTINCT val FROM dbo.fnc_strSplit(@RedmineIds,',')

    UPDATE iss WITH(UPDLOCK,ROWLOCK)
    SET        
        iss.VersionId = @VersionId,
        iss.ModifiedBy = @ModifiedBy,
        iss.ModifiedDate = GETDATE()
    FROM dbo.SpmSpIssue AS iss
        INNER JOIN @tblScript AS ts ON iss.StoredProcedureId = ts.SpId
        INNER JOIN @tblRedmine AS tr ON iss.IssueId = tr.RedmineId
    WHERE
        iss.VersionId <> @VersionId
END