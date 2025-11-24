--EXEC SpmDbServer_GetConnectionString 33 
CREATE PROC [dbo].[SpmDbServer_GetConnectionString]
	@DbServerId INT=NULL,
	@SystemId INT=NULL,	
	@PageIndex INT=0,
	@ItemsPerPage INT =50,
	@TotalItem INT=NULL OUT	
AS
/*
Created: 20150528@Larry.Tran
Task: Get the connection string.
DB: SPM
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
    CREATE TABLE #tblConnectionString(
	   MachineId INT,
	   MachineName VARCHAR(100),
	   IPAddress VARCHAR(50),
	   MachineDescription NVARCHAR(2000),
	   EnvironmentId INT,
	   EnvironmentName NVARCHAR(100),
	   DbServerId INT,
	   DbServerName VARCHAR(100),
	   DbServerDescription NVARCHAR(2000),
	   DatabaseId INT,
	   DatabaseName VARCHAR(100),
	   DatabaseDescription NVARCHAR(2000),
	   UserId VARCHAR(100),
	   [Password] VARCHAR(300)
    )

    IF @DbServerId IS NOT NULL 
    BEGIN
	   INSERT INTO #tblConnectionString	   
	   SELECT DISTINCT
		  m.MachineId,
		  m.Name,
		  mi.IPAddress,
		  m.[Description],
		  me.EnvironmentId,
		  ld.Name,
		  ds.DbServerId,
		  ds.Name,
		  ds.[Description],
		  db.DatabaseId,
		  db.Name,
		  db.[Description],
		  du.UserId,
		  du.[Password]
	   FROM dbo.SpmDbServer AS ds WITH (NOLOCK)
		  INNER JOIN dbo.SpmAliasServerEnvironment AS aev WITH (NOLOCK)
			 ON ds.DbServerId = aev.DbServerId
		  INNER JOIN dbo.SpmAliasServer AS al WITH (NOLOCK) 
			 ON al.AliasServerId = aev.AliasServerId
		  INNER JOIN dbo.SpmAliasServerDatabase AS asd WITH (NOLOCK)
			 ON asd.AliasServerId = al.AliasServerId
		  INNER JOIN dbo.SpmDatabase AS db WITH (NOLOCK) 
			 ON db.DatabaseId = asd.DatabaseId
		  INNER JOIN dbo.SpmDatabaseUser AS du WITH (NOLOCK)
			 ON du.DatabaseId = db.DatabaseId
		  INNER JOIN dbo.SpmMachine AS m WITH (NOLOCK)
			 ON ds.MachineId = m.MachineId
		  INNER JOIN dbo.SpmMachineIPAddress AS mi WITH (NOLOCK)
			 ON m.MachineId = mi.MachineId
		  INNER JOIN dbo.SpmMachineEnvironment AS me WITH (NOLOCK)
			 ON me.MachineId = m.MachineId
		  INNER JOIN dbo.LookupData AS ld WITH (NOLOCK)
			 ON me.EnvironmentId = ld.[Value] AND ld.LookupId = 1	  	  
	   WHERE	  
		  al.IsActive = 1
		  AND db.IsActive = 1
		  AND ds.IsActive = 1
		  AND m.IsActive = 1	   
		  AND ds.DbServerId = @DbServerId	   	  
	   ORDER BY
		  m.Name,
		  ds.Name,
		  db.Name,
		  du.UserId
    END
    ELSE IF @SystemId IS NOT NULL
    BEGIN
	   INSERT INTO #tblConnectionString	   
	   SELECT DISTINCT
		  m.MachineId,
		  m.Name,
		  mi.IPAddress,
		  m.[Description],
		  me.EnvironmentId,
		  ld.Name,
		  ds.DbServerId,
		  ds.Name,
		  ds.[Description],
		  db.DatabaseId,
		  db.Name,
		  db.[Description],
		  du.UserId,
		  du.[Password]
	   FROM dbo.SpmStoredProcedure AS sp WITH (NOLOCK)
		  INNER JOIN dbo.SpmSpFunction AS sf WITH (NOLOCK) 
			 ON sf.StoredProcedureId = sp.StoredProcedureId		  
		  INNER JOIN dbo.SpmSystem AS s WITH (NOLOCK) 
			 ON s.SystemId = sf.SystemId		  
		  INNER JOIN dbo.SpmAliasServer AS al WITH (NOLOCK) 
			 ON al.AliasServerId = sp.AliasServerId
		  INNER JOIN dbo.SpmAliasServerEnvironment AS aev WITH (NOLOCK) 
			 ON aev.AliasServerId = al.AliasServerId
		  INNER JOIN dbo.SpmDatabase AS db WITH (NOLOCK) 
			 ON db.DatabaseId = sp.DatabaseId
		  INNER JOIN dbo.SpmAliasServerDatabase AS asd WITH (NOLOCK)
			 ON asd.AliasServerId = al.AliasServerId AND asd.DatabaseId = db.DatabaseId
		  INNER JOIN dbo.SpmDbServer AS ds WITH (NOLOCK) 
			 ON ds.DbServerId = aev.DbServerId
		  INNER JOIN dbo.SpmDatabaseUser AS du WITH (NOLOCK)
			 ON du.DatabaseId = db.DatabaseId
		  INNER JOIN dbo.SpmMachine AS m WITH (NOLOCK)
			 ON ds.MachineId = m.MachineId
		  INNER JOIN dbo.SpmMachineIPAddress AS mi WITH (NOLOCK)
			 ON m.MachineId = mi.MachineId
		  INNER JOIN dbo.SpmMachineEnvironment AS me WITH (NOLOCK)
			 ON me.MachineId = m.MachineId
		  INNER JOIN dbo.LookupData AS ld WITH (NOLOCK)
			 ON me.EnvironmentId = ld.[Value] AND ld.LookupId = 1		  	  	  
	   WHERE	  
		  sp.IsActive	=1 		 
		  AND s.IsActive = 1		 
		  AND al.IsActive = 1
		  AND db.IsActive = 1
		  AND ds.IsActive = 1
		  AND m.IsActive = 1	   
		  AND s.SystemId = @SystemId	   	  
	   ORDER BY
		  m.Name,
		  ds.Name,
		  db.Name,
		  du.UserId 
    END

    SELECT @TotalItem = COUNT(*) 
    FROM(
	   SELECT DISTINCT
		  cs.MachineId,
		  cs.DbServerId,
		  cs.DatabaseId,
		  cs.UserId
	   FROM #tblConnectionString AS cs
    ) AS sub
    
    --IpAddress information
    SELECT DISTINCT cs.MachineId,	   
	   cs.IPAddress	   
    FROM #tblConnectionString AS cs    

    --Environment information
    SELECT DISTINCT cs.MachineId,
	   cs.EnvironmentId,
	   cs.EnvironmentName AS Name 
    FROM #tblConnectionString AS cs  
    
    --User information
    SELECT sub.MachineId,
	   sub.MachineName AS Name,	
	   sub.MachineDescription AS [Description],   
	   sub.DbServerId,
	   sub.DbServerName AS Name,
	   sub.DbServerDescription AS [Description],
	   sub.DatabaseId,
	   sub.DatabaseName AS Name,
	   sub.DatabaseDescription AS [Description],
	   sub.UserId,
	   sub.[Password],
	   sub.[Index]
    FROM(    
	   SELECT cs.MachineId,
		  cs.MachineName,	
		  cs.MachineDescription,   
		  cs.DbServerId,
		  cs.DbServerName,
		  cs.DbServerDescription,
		  cs.DatabaseId,
		  cs.DatabaseName,
		  cs.DatabaseDescription,
		  cs.UserId,
		  cs.[Password],
		  ROW_NUMBER()
		  OVER (PARTITION BY cs.MachineId 
			 ORDER BY cs.MachineName,
				cs.DbServerName,
				cs.DatabaseName,
				cs.UserId
		  ) AS [Index]
	   FROM #tblConnectionString AS cs
	   GROUP BY
		  cs.MachineId,
		  cs.MachineName,	
		  cs.MachineDescription,   
		  cs.DbServerId,
		  cs.DbServerName,
		  cs.DbServerDescription,
		  cs.DatabaseId,
		  cs.DatabaseName,
		  cs.DatabaseDescription,
		  cs.UserId,
		  cs.[Password]
    ) AS sub
    ORDER BY
	   sub.MachineName,
	   sub.DbServerName,
	   sub.DatabaseName,
	   sub.UserId
    OFFSET (@PageIndex * @ItemsPerPage) ROWS
    FETCH NEXT @ItemsPerPage ROWS ONLY;	     
END
