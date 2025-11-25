--EXEC SpmStoredProcedure_Search NULL,NULL,NULL 
CREATE PROC [dbo].[SpmStoredProcedure_Search]	
	@SpName VARCHAR( 300 )= NULL,
	@DbServerId INT = NULL,
	@SystemId INT = NULL,
	@FunctionId VARCHAR(MAX) = NULL,
	@ProductId VARCHAR(MAX) = NULL,
	@DatabaseId INT = NULL,
	@TagId INT = NULL,
	@AliasServerId INT = NULL,
    @ViewByMode SMALLINT = 1,
    @RedmineIssueIds VARCHAR(MAX) = NULL,
    @OrphanSps BIT = 0,
    @UsedSps VARCHAR(MAX) = NULL,
	@PageIndex INT = 0,
	@ItemsPerPage INT = 50,
	@TotalItem INT = NULL OUT
AS
/*
Created: 20150520@Larry.Tran
Task: Search the SpmStoredProcedure information.
DB: SPM
Original: 

Revisions:  
Param's Explanation:
    - @FunctionId: 1,2,3
    - @ProductId: 1,2,3
*/
BEGIN
    SET NOCOUNT ON

    DECLARE @ViewByFunctionGroup SMALLINT = 1
    DECLARE @ViewByParentFunction SMALLINT = 2

    IF @ViewByMode = @ViewByFunctionGroup
    BEGIN
        EXEC SpmStoredProcedure_SearchViewByFunctionGroup @SpName = @SpName,
                                                            @DbServerId = @DbServerId,
                                                            @SystemId = @SystemId,
                                                            @FunctionId = @FunctionId,
                                                            @ProductId = @ProductId,
                                                            @DatabaseId = @DatabaseId,
                                                            @TagId = @TagId,
                                                            @AliasServerId = @AliasServerId,
                                                            @RedmineIssueIds = @RedmineIssueIds,
                                                            @OrphanSps = @OrphanSps,
                                                            @UsedSps = @UsedSps,
                                                            @PageIndex = @PageIndex,
                                                            @ItemsPerPage = @ItemsPerPage,
                                                            @TotalItem = @TotalItem OUT
    END
    ELSE IF @ViewByMode = @ViewByParentFunction
    BEGIN
        EXEC SpmStoredProcedure_SearchViewByFunctionRelation @SpName = @SpName,
                                                            @DbServerId = @DbServerId,
                                                            @SystemId = @SystemId,
                                                            @FunctionId = @FunctionId,
                                                            @ProductId = @ProductId,
                                                            @DatabaseId = @DatabaseId,
                                                            @TagId = @TagId,
                                                            @AliasServerId = @AliasServerId,
                                                            @RedmineIssueIds = @RedmineIssueIds,
                                                            @OrphanSps = @OrphanSps,
                                                            @UsedSps = @UsedSps,
                                                            @PageIndex = @PageIndex,
                                                            @ItemsPerPage = @ItemsPerPage,
                                                            @TotalItem = @TotalItem OUT
    END
END

