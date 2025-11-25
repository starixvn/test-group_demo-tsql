--EXEC SpmStoredProcedure_GetBasicInfo 'Acc_BetList'
CREATE PROCEDURE [dbo].[SpmStoredProcedure_GetBasicInfo]
	@Name VARCHAR(100) = NULL	
AS
/*
Created: 20150820@Larry.Tran
Task: Get the sp basic info by searching name.
DB: SPM
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;	

	SELECT sp.StoredProcedureId,
	   sp.Name,
	   alias.AliasServerId,
	   alias.Name,
	   db.DatabaseId,
	   db.Name 
	FROM dbo.SpmStoredProcedure AS sp WITH(NOLOCK)
	   INNER JOIN dbo.SpmAliasServer AS alias WITH(NOLOCK)
		  ON alias.AliasServerId = sp.AliasServerId
			 AND alias.IsDeleted = 0
			 AND alias.IsActive = 1
	   INNER JOIN dbo.SpmDatabase AS db WITH(NOLOCK)
		  ON db.DatabaseId = sp.DatabaseId
			 AND db.IsDeleted = 0
			 AND db.IsActive = 1
	WHERE sp.IsDeleted = 0
	   AND sp.IsActive = 1
	   AND sp.Name LIKE '%'+ @Name +'%'
END
