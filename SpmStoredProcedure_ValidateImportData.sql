CREATE PROC [dbo].[SpmStoredProcedure_ValidateImportData]
    @Data dbo.ImportDataTableType READONLY,
    @ErrCode INT = 0 OUTPUT,
    @ErrMsg VARCHAR(MAX) = '' OUTPUT
AS
/*
Created: 20160923@Larry.Tran
Task: Validate data before importing stored procedure from excel file.
DB: SPM
Original: 

Revisions:  
Param's Explanation:
- @Data: <ROOT>
		  <SP IssueId="1" SPName="" AliasServer="" Database="" Type="" Developer='' Action='' Status='' 
                Version='' CallByWeb='' CallByExecRef='' Description=''></SP>
	   </ROOT>
*/
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @InvalidAliasServer VARCHAR(1000) = ''
    DECLARE @InvalidDatabase VARCHAR(1000) = ''
    DECLARE @InvalidType VARCHAR(500) = ''
    DECLARE @SpType INT = 2
    DECLARE @InvalidDeveloper VARCHAR(500) = ''
    DECLARE @InvalidAction VARCHAR(500) = ''   
    DECLARE @InvalidStatus VARCHAR(500) = ''
    DECLARE @SpStatus INT = 6
    DECLARE @InvalidVersion VARCHAR(500) = ''
    DECLARE @SpVersion INT = 3
    DECLARE @NewLine CHAR(5) = '<br/>'

    IF EXISTS(SELECT TOP 1 1 FROM @Data WHERE ISNULL(IssueId,'') = '')
    BEGIN
        SET @ErrMsg = @ErrMsg + '<li>IssueId is required.</li>'
    END

    IF EXISTS(SELECT TOP 1 1 FROM @Data WHERE ISNULL(SPName,'') = '')
    BEGIN
        SET @ErrMsg = @ErrMsg + '<li>SPName is required.</li>'
    END

    IF EXISTS(SELECT TOP 1 1 FROM @Data WHERE ISNULL(AliasServer,'') = '')
    BEGIN
        SET @ErrMsg = @ErrMsg + '<li>Alias server is required.</li>'
    END

    IF EXISTS(SELECT TOP 1 1 FROM @Data WHERE ISNULL([Database],'') = '')
    BEGIN
        SET @ErrMsg = @ErrMsg + '<li>Database is required.</li>'
    END

    IF EXISTS(SELECT TOP 1 1 FROM @Data WHERE ISNULL([Type],'') = '')
    BEGIN
        SET @ErrMsg = @ErrMsg + '<li>Type is required.</li>'
    END

    IF EXISTS(SELECT TOP 1 1 FROM @Data WHERE ISNULL(Developer,'') = '')
    BEGIN
        SET @ErrMsg = @ErrMsg + '<li>Developer is required.</li>'
    END
    
    IF EXISTS(SELECT TOP 1 1 FROM @Data WHERE ISNULL([Action],'') = '')
    BEGIN
        SET @ErrMsg = @ErrMsg + '<li>Action is required.</li>'
    END

    IF EXISTS(SELECT TOP 1 1 FROM @Data WHERE ISNULL([Status],'') = '')
    BEGIN
        SET @ErrMsg = @ErrMsg + '<li>Status is required.</li>'
    END

    IF EXISTS(SELECT TOP 1 1 FROM @Data WHERE ISNULL([Version],'') = '')
    BEGIN
        SET @ErrMsg = @ErrMsg + '<li>Version is required.</li>'
    END

    SELECT @InvalidAliasServer = STUFF((
                                    SELECT ', ' + ts.AliasServer
                                    FROM @Data As ts
                                        LEFT JOIN dbo.SpmAliasServer AS s WITH(NOLOCK) ON ts.AliasServer = s.Name
                                    WHERE s.AliasServerId IS NULL
                                    GROUP BY ts.AliasServer
                                    FOR XML PATH('')), 1, 1, '')
    
    SELECT @InvalidDatabase = STUFF((
                                    SELECT ', ' + [Database]
                                    FROM @Data As ts
                                        LEFT JOIN dbo.SpmDatabase AS db WITH(NOLOCK) ON ts.[Database] = db.Name
                                    WHERE db.DatabaseId IS NULL
                                    GROUP BY [Database]
                                    FOR XML PATH('')), 1, 1, '')

    SELECT @InvalidType = STUFF((
                                SELECT ', ' + [Type]
                                FROM @Data As ts
                                    LEFT JOIN dbo.LookupData AS ld WITH(NOLOCK) ON ts.[Type] = ld.Name AND ld.LookupId = @SpType
                                WHERE ld.Id IS NULL
                                GROUP BY [Type]
                                FOR XML PATH('')), 1, 1, '')

    SELECT @InvalidDeveloper = STUFF((
                                SELECT ', ' + ts.Developer
                                FROM @Data As ts
                                    LEFT JOIN dbo.Employee AS e WITH(NOLOCK) ON ts.Developer = e.NickName AND e.IsDeleted = 0 AND e.[Enabled] = 1
                                WHERE e.EmployeeId IS NULL
                                GROUP BY Developer
                                FOR XML PATH('')), 1, 1, '')
    
    SELECT @InvalidAction = STUFF((
                                SELECT ', ' + ts.[Action]
                                FROM @Data As ts                                   
                                WHERE ts.[Action] NOT IN ('None','A','E','D','Review')
                                GROUP BY [Action]
                                FOR XML PATH('')), 1, 1, '')

    SELECT @InvalidStatus = STUFF((
                                SELECT ', ' + ts.[Status]
                                FROM @Data As ts
                                    LEFT JOIN dbo.LookupData AS ld WITH(NOLOCK) ON ts.[Status] = ld.Name AND ld.LookupId = @SpStatus
                                WHERE ld.Id IS NULL
                                GROUP BY [Status]
                                FOR XML PATH('')), 1, 1, '')

    SELECT @InvalidVersion = STUFF((
                                SELECT ', ' + ts.[Version]
                                FROM @Data As ts
                                    LEFT JOIN dbo.LookupData AS ld WITH(NOLOCK) ON ts.[Version] = ld.Name AND ld.LookupId = @SpVersion
                                WHERE ld.Id IS NULL
                                GROUP BY [Version]
                                FOR XML PATH('')), 1, 1, '')

    IF @InvalidAliasServer <> ''
    BEGIN
        SET @ErrMsg = @ErrMsg + '<li>' +'Nonexistent alias servers are ' + @InvalidAliasServer + '. ' + '</li>'
    END

    IF @InvalidDatabase <> ''
    BEGIN
        SET @ErrMsg = @ErrMsg + '<li>' + 'Nonexistent databases are ' + @InvalidDatabase + '. ' + '</li>'
    END

    IF @InvalidType <> ''
    BEGIN
        SET @ErrMsg = @ErrMsg + '<li>' + 'Nonexistent types are ' + @InvalidType + '. ' + '</li>'
    END

    IF @InvalidDeveloper <> ''
    BEGIN
        SET @ErrMsg = @ErrMsg + '<li>' + 'Nonexistent developers are ' + @InvalidDeveloper + '. ' + '</li>'
    END

    IF @InvalidAction <> ''
    BEGIN
        SET @ErrMsg = @ErrMsg + '<li>' + 'Nonexistent actions are ' + @InvalidAction + '. ' + '</li>'
    END

    IF @InvalidStatus <> ''
    BEGIN
        SET @ErrMsg = @ErrMsg + '<li>' + 'Nonexistent statuses are ' + @InvalidStatus + '. ' + '</li>'
    END

    IF @InvalidVersion <> ''
    BEGIN
        SET @ErrMsg = @ErrMsg + '<li>' + 'Nonexistent versions are ' + @InvalidVersion + '. ' + '</li>'
    END

    IF @ErrMsg <> ''
    BEGIN
        SET @ErrCode = 100
        SET @ErrMsg = 'There are some errors as below. ' + @NewLine + '<ul>' + @ErrMsg + '</ul>'
    END    
END

