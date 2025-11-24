CREATE PROC [dbo].[SpmDbServer_GroupByEnvironment]   
AS
/*
Created: 20150617@Larry.Tran
Task: Group SpmDbServer by Environment.
DB: SPM
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON
        
    --SpmDbServer
    SELECT 
	   me.EnvironmentId,
	   env.Name,
	   ds.DbServerId,
	   ds.Name, 
	   ds.IsActive, 
	   ds.[Description]	   
    FROM dbo.SpmDbServer AS ds WITH(NOLOCK)
	   INNER JOIN dbo.SpmMachine AS m WITH(NOLOCK)
		  ON ds.MachineId = m.MachineId
	   INNER JOIN dbo.SpmMachineEnvironment AS me WITH(NOLOCK)
		  ON me.MachineId = m.MachineId
	   INNER JOIN dbo.LookupData AS env WITH(NOLOCK)
		  ON env.[Value] = me.EnvironmentId 
			 AND env.LookupId = 1 --Environment
    WHERE ds.IsActive = 1
	   AND ds.IsDeleted	= 0
	   AND m.IsActive = 1
	   AND m.IsDeleted = 0
END
