CREATE PROCEDURE [dbo].[SpmRole_GetFunctionByRoleId] --1
	@RoleId INT
AS
/*
Created: 20150609@Josh.Phan
Task: Get function of role by role Id.
DB: SPM
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT DISTINCT 
        fk.[FunctionId]
		,fk.[FunctionKey]
		,fk.[Name] AS FunctionName
		,fk.[ParentFunctionId]
		,fk.[IsReadOnly]
		,rf.[IsRead]
		,rf.[IsHost]
        ,m.DisplayOrder
	FROM dbo.[FunctionKey] AS fk WITH (NOLOCK)
        INNER JOIN dbo.Menu AS m WITH(NOLOCK) ON fk.FunctionId = m.FunctionId
		LEFT JOIN (
			SELECT [FunctionId]
				,[IsRead]
				,[IsHost]
			FROM dbo.[RoleFunction] WITH (NOLOCK)
			WHERE [RoleId] = @RoleId) AS rf ON fk.[FunctionId] = rf.[FunctionId]
	WHERE fk.[IsDisabled] = 0
    ORDER BY m.DisplayOrder
END

