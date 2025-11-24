CREATE PROCEDURE [dbo].[SpmDbServer_Get]
	@MachineId INT = NULL
	,@EnvironmentId INT = NULL	
	,@IsActive BIT = NULL
	,@IsPrimary BIT = NULL
AS
/*
Created: 20150325@Tim.Trinh
Task: Get Db Server info from SPM.
DB: SPM
Original: 

Revisions:
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;
	
	CREATE TABLE #DbServer ([DbServerId] INT)
	
	INSERT INTO #DbServer(DbServerId)
	SELECT DISTINCT serv.[DbServerId]
	FROM [dbo].[SpmDbServer] AS serv WITH(NOLOCK)
	INNER JOIN  [dbo].[SpmMachine] AS mc WITH(NOLOCK)
		ON mc.[MachineId] = serv.[MachineId]
	INNER JOIN [dbo].[SpmMachineEnvironment] AS me WITH(NOLOCK)
		ON me.[MachineId] = mc.[MachineId]
	INNER JOIN [dbo].[LookupData] AS env WITH (NOLOCK) 
	     ON env.[LookupId] = 1 AND env.[Value] = me.[EnvironmentId]	
	WHERE serv.IsDeleted = 0
		AND (@MachineId IS NULL
			 OR mc.[MachineId] = @MachineId)
		AND (@EnvironmentId IS NULL
			 OR me.[EnvironmentId] = @EnvironmentId)			
		AND (@IsActive IS NULL
			OR serv.[IsActive] = @IsActive)
		AND (@IsPrimary IS NULL
			OR serv.[IsPrimary] = @IsPrimary)
	
	-- database server and machine	
	SELECT DISTINCT serv.[DbServerId]
		,serv.[Name]
		,serv.[Description]
		,serv.[IsActive]
		,serv.[IsPrimary]
		,mc.[MachineId]
		,mc.[Name] MachineName
	FROM #DbServer AS ser WITH(NOLOCK)
	INNER JOIN [dbo].[SpmDbServer] AS serv WITH(NOLOCK)
		ON serv.[DbServerId] = ser.[DbServerId]
	INNER JOIN  [dbo].[SpmMachine] AS mc WITH(NOLOCK)
		ON mc.[MachineId] = serv.[MachineId]
	ORDER BY serv.[Name]
	
	-- ip address
	SELECT DISTINCT serv.[DbServerId]
	     ,ip.[IPAddress]
	FROM #DbServer AS ser WITH(NOLOCK)
	INNER JOIN [dbo].[SpmDbServer] AS serv WITH(NOLOCK)
	     ON serv.[DbServerId] = ser.[DbServerId]
	INNER JOIN  [dbo].[SpmMachine] AS mc WITH(NOLOCK)
		ON mc.[MachineId] = serv.[MachineId]
	INNER JOIN [dbo].[SpmMachineIPAddress] AS ip WITH(NOLOCK)
	     ON mc.[MachineId] = ip.[MachineId]
	
	-- environment		
	SELECT DISTINCT serv.[DbServerId]
		,me.[EnvironmentId]
		,env.[Name] EnvironmentName
	FROM #DbServer AS ser WITH(NOLOCK)
	INNER JOIN [dbo].[SpmDbServer] AS serv WITH(NOLOCK)
		ON serv.[DbServerId] = ser.[DbServerId]
	INNER JOIN [dbo].[SpmMachine] AS mc WITH(NOLOCK)
		ON mc.[MachineId] = serv.[MachineId]
	INNER JOIN [dbo].[SpmMachineEnvironment] AS me WITH(NOLOCK)
		ON me.[MachineId] = mc.[MachineId]
	INNER JOIN [dbo].[LookupData] AS env WITH (NOLOCK) 
	     ON env.[LookupId] = 1 
	     AND env.[Value] = me.[EnvironmentId]	
END
