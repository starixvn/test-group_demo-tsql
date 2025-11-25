CREATE PROCEDURE [dbo].[AliasServer_Get]
	@DBServerIds VARCHAR(50)=NULL,
	@DatabaseIds VARCHAR(50)=NULL,
	@IsActive BIT=0 
AS
/*
Created: 20150416@Quinn.Vo
Task: Get Alias Server info from SPM.
DB: SPM
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT asv.AliasServerId AS Id,
	asv.Name,
	asv.[Description]
	FROM dbo.SpmAliasServer AS asv WITH (NOLOCK)
	WHERE asv.IsActive = 1

END

