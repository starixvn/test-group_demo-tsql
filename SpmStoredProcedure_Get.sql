CREATE PROCEDURE [dbo].[SpmStoredProcedure_Get]
	@Name					VARCHAR(300) = NULL,
	@AliasServerId			INT = NULL,
	@DatabaseId				INT = NULL,
	@SpTypeId				INT = NULL,
	@IssueIds				VARCHAR(255) = NULL,
	@SystemId				INT = NULL,
	@ProductId				VARCHAR(MAX) = NULL,
	@FunctionId				VARCHAR(MAX) = NULL,
	@OrphanSps			    BIT = 0,
	@PageIndex              INT = 0,
	@ItemsPerPage           INT = NULL,
	@SearchKey              VARCHAR(500) = NULL,
	@TotalItem              INT = NULL OUT
AS
/*
Created: 20150421@Quinn.Vo
Task: Get sp info.
DB: SPM
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;	
	
	CREATE TABLE #Issues (IssueId  VARCHAR(10))

	IF ISNULL(@IssueIds, '') <> ''
	BEGIN
		INSERT INTO #Issues (IssueId)
		SELECT DISTINCT CAST(val AS VARCHAR(10)) FROM fnc_strSplit (@IssueIds, ',')
	END		

	CREATE TABLE #StoredProcedures (StoredProcedureId  INT)

	DECLARE @StoredProcedures IntId
	
	INSERT INTO @StoredProcedures (Id)
	SELECT DISTINCT sp.StoredProcedureId
	FROM dbo.SpmStoredProcedure AS sp WITH (NOLOCK)
		INNER JOIN dbo.SpmAliasServer AS ass WITH (NOLOCK) ON sp.AliasServerId = ass.AliasServerId
		INNER JOIN dbo.SpmDatabase AS db WITH (NOLOCK) ON sp.DatabaseId = db.DatabaseId
		LEFT JOIN dbo.SpmSpIssue AS spi WITH (NOLOCK) ON sp.StoredProcedureId = spi.StoredProcedureId
		LEFT JOIN dbo.SpmSpFunction AS spf WITH (NOLOCK) ON sp.StoredProcedureId = spf.StoredProcedureId		
	WHERE sp.IsDeleted = 0
		AND ass.IsDeleted = 0
		AND db.IsDeleted = 0
		AND (@Name IS NULL OR sp.Name LIKE '%' + @Name + '%')
		AND (@AliasServerId IS NULL OR sp.AliasServerId = @AliasServerId)
		AND (@DatabaseId IS NULL OR sp.DatabaseId = @DatabaseId)
		AND (@SpTypeId IS NULL OR sp.SpTypeId = @SpTypeId)
		AND (ISNULL(@IssueIds, '') = '' OR CAST(spi.IssueId AS VARCHAR(10)) IN (SELECT IssueId FROM #Issues))
		AND (
            (
                @OrphanSps = 0 
                AND (@SystemId IS NULL OR spf.SystemId = @SystemId)
		        AND ( 
			        ISNULL(@FunctionId,'') = '' 
			        OR spf.FunctionId IN (SELECT val FROM fnc_strSplit(@FunctionId,','))
		        )
		        AND (
			        ISNULL(@ProductId,'') = '' 
			        OR spf.ProductId IN (SELECT val FROM fnc_strSplit(@ProductId,','))
		        )
            ) OR (@OrphanSps = 1 AND spf.StoredProcedureId IS NULL)
        )

	EXECUTE [dbo].[SpmStoredProcedure_GetDetail] @StoredProcedures = @StoredProcedures,
                                                 @PageIndex = @PageIndex,
                                                 @ItemsPerPage = @ItemsPerPage,
												 @SearchKey = @SearchKey,
												 @TotalItem = @TotalItem OUT
END
