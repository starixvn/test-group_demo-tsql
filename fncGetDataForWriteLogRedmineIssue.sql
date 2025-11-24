CREATE FUNCTION [dbo].[fncGetDataForWriteLogRedmineIssue]
(
	@IssueIds IntId READONLY
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Data NVARCHAR(MAX), @StoredProcedures NVARCHAR(MAX), @Issues NVARCHAR(200)
    SELECT @StoredProcedures = '', @Issues =''

    SELECT @Issues = '<iss>' + CAST(Id AS VARCHAR(10)) + '</iss>' FROM @IssueIds	

    SELECT @StoredProcedures = @StoredProcedures
	   + '<sp><iss>' + CAST(iss.IssueId AS VARCHAR(10)) + '</iss>'
	   + '<id>' + CAST(sp.StoredProcedureId AS VARCHAR(10)) + '</id>'
	   + '<n>' + sp.Name + '</n>'
	   + '<al>' + al.Name + '</al>'
	   + '<db>' + db.Name + '</db>'
	   + '<ty>' + CAST(sp.SpTypeId AS VARCHAR(10)) + '</ty>'
	   + '<cbw>' + CAST(sp.CallByWeb AS VARCHAR(10)) + '</cbw>'
	   + '<cbe>' + CAST(sp.CallByExecRef AS VARCHAR(10))  + '</cbe>'
	   + '<de>' + e.NickName + '</de>'
	   + '<a>' + iss.ActionName + '</a>'
	   + '<s>' + CAST(iss.[Status] AS VARCHAR(10)) + '</s>' 
	   + '<v>' + CAST(iss.VersionId AS VARCHAR(10)) + '</v>'
	   + '<d>' + iss.[Description] + '</d>'
	   + '</sp>'
    FROM [dbo].[SpmSpIssue] AS iss WITH (NOLOCK)
    INNER JOIN [dbo].[SpmStoredProcedure] AS sp WITH (NOLOCK) ON iss.StoredProcedureId = sp.StoredProcedureId
    INNER JOIN [dbo].[SpmAliasServer] AS al WITH (NOLOCK) ON sp.AliasServerId = al.AliasServerId
    INNER JOIN [dbo].[SpmDatabase] AS db WITH (NOLOCK) ON sp.DatabaseId = db.DatabaseId
    INNER JOIN [dbo].[Employee] AS e WITH (NOLOCK) ON iss.DeveloperId = e.EmployeeId
    INNER JOIN @IssueIds AS rediss ON iss.IssueId = rediss.Id
    WHERE sp.IsDeleted = 0
		
    SELECT @Data = '<r><red>' + @Issues + '</red><sps>' + @StoredProcedures + '</sps></r>'

    RETURN @Data
END

