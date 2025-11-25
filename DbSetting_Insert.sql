CREATE PROCEDURE [dbo].[DbSetting_Insert]	
	@DbSettings VARCHAR(MAX)
	
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(1000) = '' OUTPUT

AS
/*
Created: Josh.Phan@2015-1-22
Task: INSERT Database setting
DB: [SPM]
Original: 

Revisions:    
Param's Explanation:
	,@DbSettings = '<ROOT>
		<Setting System=''NDICT'' Product=''Keno'' Function='Login' SpName=''abc'' DbName=''SPM'' =''abc'' 
			AliasServer=''abc'' ServerIP=''abc'' Username=''aef'' Password=''aefef'' EnvironmentId=''1''></Setting>
		</ROOT>'
*/
BEGIN
	SET NOCOUNT ON;
	
	IF OBJECT_ID('tempdb..#DbSettingDetail') IS NOT NULL
		BEGIN
			DROP TABLE #DbSettingDetail
		END
				
	CREATE TABLE #DbSettingDetail (
		[System] VARCHAR(100)
		,[Product] VARCHAR(300)
		,[Function] VARCHAR(300)
		,[SpName] VARCHAR(500)
		,[DbName] VARCHAR(300) 
		,[AliasServer] VARCHAR(100)
		,[ServerIP] VARCHAR(100)
		,[Username] VARCHAR(100)
		,[Password] VARCHAR(100)
		,[EnvironmentId] INT)
 
	DECLARE @DocHandler INT

	SELECT @DbSettings = ISNULL(@DbSettings,'')

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@DbSettings

		INSERT INTO #DbSettingDetail(
			 [System]
			,[Product]
			,[Function]
			,[SpName]
			,[DbName]
			,[AliasServer]
			,[ServerIP]
			,[Username]
			,[Password]
			,[EnvironmentId])
		SELECT   [System]
				,[Product]
				,[Function]
				,[SpName]
				,[DbName]
				,[AliasServer]
				,[ServerIP]
				,[Username]
				,[Password]
				,[EnvironmentId]
		FROM OPENXML(@DocHandler, '/ROOT/Setting', 1) 
		WITH (
			[System]  VARCHAR(100)
			,[Product] VARCHAR(300)
			,[Function] VARCHAR(300)
			,[SpName] VARCHAR(500)
			,[DbName] VARCHAR(300)
			,[AliasServer] VARCHAR(100)
			,[ServerIP] VARCHAR(100)
			,[Username] VARCHAR(100)
			,[Password] VARCHAR(100)
			,[EnvironmentId] INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT @ErrCode = 100
			,@ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;	

	DECLARE @EnvironmentId INT
	SET @EnvironmentId = (SELECT DISTINCT [EnvironmentId] FROM #DbSettingDetail)
	
	/*
	** Insert System
	*/	
	INSERT INTO [dbo].[SpmSystem]
		([Name]
		,[Description]
		,[IsActive]
		,[ModifiedBy]
		,[ModifiedDate])
	SELECT DISTINCT 
		[System]
		,NULL
		,1
		,NULL
		,GETDATE()
	FROM #DbSettingDetail AS dbS
	WHERE dbS.[System] IS NOT NULL AND NOT EXISTS (
			SELECT TOP 1 1
			FROM [dbo].[SpmSystem] WITH (NOLOCK)
			WHERE [Name] = dbS.[System] AND IsDeleted = 0)
	
	/*
	** Insert Product
	*/	
	INSERT INTO [dbo].[SpmProduct]
		([Name]
		,[Description]
		,[IsActive]
		,[ModifiedBy]
		,[ModifiedDate])
	SELECT DISTINCT
		[Product]
		,NULL
		,1
		,NULL
		,GETDATE()
	FROM #DbSettingDetail AS dbS
	WHERE ISNULL(dbS.[Product], '') <> '' AND NOT EXISTS (
		SELECT TOP 1 1
		FROM [dbo].[SpmProduct] WITH (NOLOCK)
		WHERE [Name] = dbS.[Product] AND IsDeleted = 0)		
	
	/*
	** Insert Function
	*/
	INSERT INTO [dbo].[SpmFunction]
		([Name]
		,[IsActive]
		,[Description]
		,[ModifiedBy]
		,[ModifiedDate])
	SELECT DISTINCT
		[Function]
		,1
		,NULL
		,NULL
		,GETDATE()
	FROM #DbSettingDetail AS dbS
	WHERE NOT EXISTS (
		SELECT TOP 1 1
		FROM [dbo].[SpmFunction] WITH (NOLOCK)
		WHERE [Name] = dbS.[Function] AND IsDeleted = 0)	
	
	INSERT INTO [dbo].[SpmFunctionSystemProduct]
		([FunctionId]
		,[SystemId]
		,[ProductId])
	SELECT DISTINCT
		fn.[FunctionId]
		,sy.[SystemId]
		,prod.[ProductId]
	FROM #DbSettingDetail AS dbS
		INNER JOIN [dbo].[SpmFunction] AS fn WITH (NOLOCK) 
			ON dbS.[Function] = fn.[Name] AND fn.IsDeleted = 0
		INNER JOIN [dbo].[SpmSystem] AS sy WITH (NOLOCK) 
			ON dbS.[System] = sy.[Name] AND sy.IsDeleted = 0
		LEFT JOIN [dbo].[SpmProduct] AS prod WITH (NOLOCK) 
			ON dbS.[Product] = prod.[Name] AND prod.IsDeleted = 0

	/*
	** Insert Database
	*/
	INSERT INTO [dbo].[SpmDatabase]
		([Name]
		,[Description]
		,[IsActive]
		,[ModifiedBy]
		,[ModifiedDate])
	SELECT DISTINCT
		[DbName]
		,NULL
		,1
		,NULL
		,GETDATE()
	FROM #DbSettingDetail AS dbS
	WHERE NOT EXISTS (
		SELECT TOP 1 1
		FROM [dbo].[SpmDatabase] WITH (NOLOCK)
		WHERE [Name] = dbS.[DbName] AND IsDeleted = 0)	
			
	/*
	** Insert username/password of Db Server if Alias Server is already exists
	*/
	INSERT INTO [dbo].[SpmDatabaseUser]
		([DbServerId]
		,[DatabaseId]
		,[UserId]
		,[Password])
	SELECT DISTINCT 
		aev.[DbServerId]
		,db.[DatabaseId]
		,dbS.[Username]
		,dbS.[Password]
	FROM #DbSettingDetail AS dbS
		INNER JOIN [dbo].[SpmAliasServer] AS ali WITH (NOLOCK) ON dbS.AliasServer = ali.[Name] AND ali.IsDeleted = 0
		INNER JOIN [dbo].[SpmAliasServerEnvironment] AS aev WITH (NOLOCK) ON ali.[AliasServerId] = aev.[AliasServerId]
		INNER JOIN [dbo].[SpmDatabase] AS db WITH (NOLOCK) ON dbS.[DbName] = db.[Name] AND db.IsDeleted = 0
	WHERE aev.[EnvironmentId] = dbS.[EnvironmentId] AND ISNULL(aev.DbServerId, '') <> '' 

	/*
	** Insert Alias Server
	*/
	INSERT INTO [dbo].[SpmAliasServer]
		([Name]
		,[Description]
		,[IsActive]
		,[ModifiedBy]
		,[ModifiedDate])
	SELECT DISTINCT
		[AliasServer]
		,NULL
		,1
		,NULL
		,GETDATE()
	FROM #DbSettingDetail AS dbS
	WHERE ISNULL(dbS.[AliasServer], '') <> '' AND NOT EXISTS (
		SELECT TOP 1 1
		FROM [dbo].[SpmAliasServer] WITH (NOLOCK)
		WHERE [Name] = dbS.[AliasServer] AND IsDeleted = 0)

	/*
	** Insert Alias Server Database
	*/	
	INSERT INTO [dbo].[SpmAliasServerDatabase]
		([AliasServerId]
		,[DatabaseId])
	SELECT DISTINCT
		ali.[AliasServerId]
		,db.[DatabaseId]
	FROM #DbSettingDetail AS dbS
		INNER JOIN [dbo].[SpmAliasServer] AS ali WITH (NOLOCK) ON dbS.AliasServer = ali.[Name] AND ali.IsDeleted = 0
		INNER JOIN [dbo].[SpmDatabase] AS db WITH (NOLOCK) ON dbS.DbName = db.[Name] AND db.IsDeleted = 0
	WHERE NOT EXISTS (
		SELECT TOP 1 1
		FROM [dbo].[SpmAliasServerDatabase] WITH (NOLOCK)
		WHERE [AliasServerId] = ali.[AliasServerId] AND [DatabaseId] = db.[DatabaseId])

	/*
	** Insert Alias Server Detail
	*/	
	INSERT INTO [dbo].[SpmAliasServerEnvironment]
		([AliasServerId]
		,[EnvironmentId]
		,[DbServerId])
	SELECT DISTINCT
		ali.[AliasServerId]
		,@EnvironmentId
		,NULL
	FROM #DbSettingDetail AS dbS
		INNER JOIN [dbo].[SpmAliasServer] AS ali WITH (NOLOCK) ON dbS.AliasServer = ali.[Name] AND ali.IsDeleted = 0
	WHERE NOT EXISTS (
		SELECT TOP 1 1
		FROM [dbo].[SpmAliasServerEnvironment] WITH (NOLOCK)
		WHERE [AliasServerId] = ali.[AliasServerId] AND [EnvironmentId] = @EnvironmentId)

	/*
	** Insert Store Procedures
	*/	
	INSERT INTO [dbo].[SpmStoredProcedure]
		([Name]
		,[AliasServerId]
		,[DatabaseId]
		,[IsActive]
		,[CallByWeb]
		,[CallByExecRef]
		,[SpTypeId]
		,[Description]
		,[ModifiedBy]
		,[ModifiedDate])	
	SELECT DISTINCT
		dbS.[SpName]
		,ali.[AliasServerId]
		,db.[DatabaseId]
		,1
		,1
		,0
		,1 -- SP type
		,NULL
		,NULL
		,GETDATE()
	FROM #DbSettingDetail AS dbS
		INNER JOIN [dbo].[SpmAliasServer] AS ali WITH (NOLOCK) ON dbS.[AliasServer] = ali.[Name] AND ali.IsDeleted = 0
		INNER JOIN [dbo].[SpmDatabase] AS db WITH (NOLOCK) ON dbS.[DbName] = db.[Name] AND db.IsDeleted = 0
	WHERE NOT EXISTS (
		SELECT TOP 1 1
		FROM [dbo].[SpmStoredProcedure] WITH (NOLOCK)
		WHERE [Name] = dbS.[SpName] AND [AliasServerId] = ali.[AliasServerId] AND [DatabaseId] = db.DatabaseId AND IsDeleted = 0)

	/*
	** Insert relationship between SP and Function
	*/	
	INSERT INTO [dbo].[SpmSpFunction]
		([StoredProcedureId]
		,[FunctionId]
		,[ModifiedBy]
		,[ModifiedDate])
	SELECT DISTINCT 
		sp.[StoredProcedureId]
		,func.[FunctionId]
		,NULL
		,GETDATE()
	FROM #DbSettingDetail AS dbS 
		INNER JOIN [dbo].[SpmStoredProcedure] AS sp WITH (NOLOCK) ON dbS.[SpName] = sp.[Name] AND sp.IsDeleted = 0
		INNER JOIN [dbo].[SpmFunction] AS func WITH (NOLOCK) ON dbs.[Function] = func.[Name] AND func.IsDeleted = 0
	WHERE NOT EXISTS (
		SELECT TOP 1 1
		FROM [dbo].[SpmSpFunction] WITH (NOLOCK)
		WHERE [StoredProcedureId] = sp.[StoredProcedureId] AND [FunctionId] = func.[FunctionId])
	
	DROP TABLE #DbSettingDetail
END


