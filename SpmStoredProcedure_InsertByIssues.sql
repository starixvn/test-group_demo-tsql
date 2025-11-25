CREATE PROCEDURE [dbo].[SpmStoredProcedure_InsertByIssues]
	@IssueIds	VARCHAR(2000)
	,@StoredProceduresIssues VARCHAR(MAX)
	,@NestedSps	NVARCHAR(MAX) = NULL
	,@SystemFunctions VARCHAR(MAX) = NULL
	,@CreatedBy	INT = NULL

	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20150603@Quinn.Vo
Task: Insert stored procedure issues.
DB: SPM
Original: 

Revisions:  
Param's Explanation:
- @IssueIds: '35476, 36469'
- @StoredProceduresIssues:
	<ROOT>
		<SP IssueId="" Name="" AliasServerId="" DatabaseId="" Type="" CallByWeb="" CallByExecRef="" DeveloperId="1" ActionName="A" Status="1" VersionId="1" Description='Test'></SP>
	</ROOT>
- @NestedSps: 
	<ROOT>
		<NestedSp Name="" AliasServerId="" DatabaseId="" NestedSpId="1"></NestedSp>
	</ROOT>
- @SystemFunctions: 
	<ROOT>
		<SystemFunction Name="" AliasServerId="" DatabaseId="" SystemId="1" ProductId="" FunctionId="2" ></SystemFunction>
	</ROOT>
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @DocHandler INT	
	DECLARE @ObjectTypeId INT = 8 -- SP
	DECLARE @Issues IntId
	DECLARE @InsertSpNameLog VARCHAR(50) = 'SpmStoredProcedure_Insert'
	DECLARE @UpdateSpNameLog VARCHAR(50) = 'SpmStoredProcedure_Update'

	INSERT INTO @Issues (Id) 
	SELECT val FROM fnc_strSplit(@IssueIds, ',')
	
	CREATE TABLE #StoredProceduresIssues(
		IssueId INT, 
		StoredProcedureId INT, 
		Name VARCHAR(100), 
		AliasServerId INT, 
		DatabaseId INT, 
		[Type] INT, 
		CallByWeb BIT, 
		CallByExecRef BIT, 
		DeveloperId INT, 
		ActionName VARCHAR(10), 
		VersionId INT, 
		[Status] INT, 
		[Description] NVARCHAR(2000))
	
	CREATE TABLE #NestedSps(StoredProcedureId INT, Name VARCHAR(100), AliasServerId INT, DatabaseId INT, NestedSpId INT)
	
	CREATE TABLE #tblSystemFunctions(
	    StoredProcedureId INT, 
	    Name VARCHAR(100), 
	    AliasServerId INT, 
	    DatabaseId INT, 	    
	    SystemId INT, 
	    ProductId INT, 
	    FunctionId INT
	)

	CREATE TABLE #tblSpLogs(	    
	    SpName VARCHAR(100), 
	    AliasServerId INT, 
	    DatabaseId INT, 	
	    SpNameLog VARCHAR(50),    
	    OldData VARCHAR(MAX)
	)

	EXEC sp_xml_preparedocument @DocHandler OUTPUT, @StoredProceduresIssues
	INSERT INTO #StoredProceduresIssues(IssueId, Name, AliasServerId, DatabaseId, [Type], CallByWeb, CallByExecRef, DeveloperId, ActionName, [Status], VersionId, [Description])
	SELECT IssueId, Name, AliasServerId, DatabaseId, Type, CallByWeb, CallByExecRef, DeveloperId, ActionName, Status, VersionId, Description 
	FROM OPENXML(@DocHandler, '/ROOT/SP', 1) 
	WITH (IssueId INT, Name VARCHAR(100), AliasServerId INT, DatabaseId INT, Type INT, CallByWeb BIT, CallByExecRef BIT, DeveloperId INT, 
		ActionName VARCHAR(10), Status INT, VersionId INT, Description NVARCHAR(2000)) AS Data
	EXEC sp_xml_removedocument @DocHandler

	EXEC sp_xml_preparedocument @DocHandler OUTPUT, @NestedSps
	INSERT INTO #NestedSps(Name, AliasServerId, DatabaseId, NestedSpId)
	SELECT Name, AliasServerId, DatabaseId, NestedSpId
	FROM OPENXML(@DocHandler, '/ROOT/NestedSp', 1) 
	WITH (Name VARCHAR(100), AliasServerId INT, DatabaseId INT, NestedSpId INT) AS Data
	EXEC sp_xml_removedocument @DocHandler

	EXEC sp_xml_preparedocument @DocHandler OUTPUT, @SystemFunctions
	INSERT INTO #tblSystemFunctions(Name, AliasServerId, DatabaseId, SystemId, ProductId, FunctionId)
	SELECT 
	   Name,
	   AliasServerId,
	   DatabaseId,
	   SystemId,
	   (CASE WHEN ISNULL(ProductId,0) = 0 THEN -1 ELSE ProductId END),
	   (CASE WHEN ISNULL(FunctionId,0) = 0 THEN -1 ELSE FunctionId END)
	FROM OPENXML(@DocHandler, '/ROOT/SystemFunction', 1) 
	WITH ( 
	    Name VARCHAR(100), 
	    AliasServerId INT, 
	    DatabaseId INT, 	    
	    SystemId INT, 
	    ProductId INT, 
	    FunctionId INT
     ) AS Data
	EXEC sp_xml_removedocument @DocHandler	

	SET XACT_ABORT ON
	BEGIN TRAN
	BEGIN TRY
	   --Get data for write Update log
	   INSERT INTO #tblSpLogs
	   (
	       SpName,
	       AliasServerId,
	       DatabaseId,
	       SpNameLog,
	       OldData
	   )
	   SELECT sp.Name,
		  sp.AliasServerId,
		  sp.DatabaseId,
		  @UpdateSpNameLog,
		  dbo.fncGetDataForWriteLog(sp.StoredProcedureId,@ObjectTypeId)
	   FROM dbo.SpmStoredProcedure AS sp WITH (NOLOCK)
	   INNER JOIN #StoredProceduresIssues AS iss ON sp.Name = iss.Name 
		  AND sp.AliasServerId = iss.AliasServerId 
		  AND sp.DatabaseId = iss.DatabaseId
		  AND sp.IsDeleted = 0

	   -- Update Stored Procedure
	   UPDATE sp
	   SET sp.SpTypeId = iss.[Type],
		  sp.CallByWeb = iss.CallByWeb,
		  sp.CallByExecRef = iss.CallByExecRef
	   FROM dbo.SpmStoredProcedure AS sp WITH (ROWLOCK, UPDLOCK)
	   INNER JOIN #StoredProceduresIssues AS iss ON sp.Name = iss.Name 
		  AND sp.AliasServerId = iss.AliasServerId 
		  AND sp.DatabaseId = iss.DatabaseId
		  AND sp.IsDeleted = 0
	   
	   --Get data for write Insert log
	   INSERT INTO #tblSpLogs
	   (
	       SpName,
	       AliasServerId,
	       DatabaseId,
	       SpNameLog,
	       OldData
	   )
	   SELECT iss.Name,
		  iss.AliasServerId,
		  iss.DatabaseId,
		  @InsertSpNameLog,
		  NULL
	   FROM #StoredProceduresIssues AS iss
		  LEFT JOIN dbo.SpmStoredProcedure AS sp WITH (NOLOCK) 
			 ON sp.Name = iss.Name 
				AND sp.AliasServerId = iss.AliasServerId 
				AND sp.DatabaseId = iss.DatabaseId
				AND sp.IsDeleted = 0
	   WHERE sp.StoredProcedureId IS NULL

	   --Insert new Stored Procedure
	   INSERT INTO dbo.SpmStoredProcedure(
		  Name,
		  AliasServerId,
		  DatabaseId,
		  SpTypeId,
		  CallByWeb,
		  CallByExecRef,
		  IsActive,
		  ModifiedBy,
		  ModifiedDate
		  )
	   SELECT iss.Name, 
		  iss.AliasServerId, 
		  iss.DatabaseId, 
		  iss.[Type], 
		  iss.CallByWeb, 
		  iss.CallByExecRef, 
		  1, 
		  @CreatedBy, 
		  GETDATE()
	   FROM #StoredProceduresIssues AS iss
	   LEFT JOIN dbo.SpmStoredProcedure AS sp WITH (NOLOCK) ON sp.Name = iss.Name 
		  AND sp.AliasServerId = iss.AliasServerId 
		  AND sp.DatabaseId = iss.DatabaseId
		  AND sp.IsDeleted = 0
	   WHERE sp.StoredProcedureId IS NULL

	   UPDATE iss
	   SET iss.StoredProcedureId = sp.StoredProcedureId
	   FROM dbo.SpmStoredProcedure AS sp WITH (NOLOCK)
	   INNER JOIN #StoredProceduresIssues AS iss ON sp.Name = iss.Name 
		  AND sp.AliasServerId = iss.AliasServerId 
		  AND sp.DatabaseId = iss.DatabaseId
		  AND sp.IsDeleted = 0

	   UPDATE nes
	   SET nes.StoredProcedureId = sp.StoredProcedureId
	   FROM dbo.SpmStoredProcedure AS sp WITH (NOLOCK)
	   INNER JOIN #NestedSps AS nes ON sp.Name = nes.Name 
		  AND sp.AliasServerId = nes.AliasServerId 
		  AND sp.DatabaseId = nes.DatabaseId
		  AND sp.IsDeleted = 0

	   --Get data for write Update log
	   INSERT INTO #tblSpLogs
	   (
	       SpName,
	       AliasServerId,
	       DatabaseId,
	       SpNameLog,
	       OldData
	   )
	   SELECT sp.Name,
		  sp.AliasServerId,
		  sp.DatabaseId,
		  @UpdateSpNameLog,
		  dbo.fncGetDataForWriteLog(sp.StoredProcedureId,@ObjectTypeId)
	   FROM dbo.SpmSpIssue AS spi WITH (NOLOCK)
		  INNER JOIN @Issues AS issu ON spi.IssueId = issu.Id
		  INNER JOIN dbo.SpmStoredProcedure AS sp WITH (NOLOCK)
			 ON sp.StoredProcedureId = spi.StoredProcedureId				
		  LEFT JOIN #StoredProceduresIssues AS iss 
			 ON spi.IssueId = iss.IssueId 
				AND spi.StoredProcedureId = iss.StoredProcedureId
		  LEFT JOIN #tblSpLogs AS spLog
			 ON spLog.SpName = sp.Name
				AND spLog.AliasServerId = sp.AliasServerId
				AND spLog.DatabaseId = sp.DatabaseId
	   WHERE iss.StoredProcedureId IS NULL
		  AND spLog.SpName IS NULL

	   DELETE spi
	   FROM dbo.SpmSpIssue AS spi WITH (NOLOCK)
	   INNER JOIN @Issues AS issu ON spi.IssueId = issu.Id
	   LEFT JOIN #StoredProceduresIssues AS iss ON spi.IssueId = iss.IssueId AND spi.StoredProcedureId = iss.StoredProcedureId
	   WHERE iss.StoredProcedureId IS NULL

	   UPDATE spi
	   SET spi.DeveloperId = iss.DeveloperId,
		  spi.ActionName = iss.ActionName,
		  spi.VersionId = iss.VersionId,
		  spi.[Description] = iss.[Description],
		  spi.[Status] = iss.[Status]            
	   FROM dbo.SpmSpIssue AS spi WITH (ROWLOCK,UPDLOCK)
	   INNER JOIN #StoredProceduresIssues AS iss ON spi.IssueId = iss.IssueId AND spi.StoredProcedureId = iss.StoredProcedureId

	   DELETE iss
	   FROM dbo.SpmSpIssue AS spi WITH (NOLOCK)
	   INNER JOIN #StoredProceduresIssues AS iss ON spi.IssueId = iss.IssueId AND spi.StoredProcedureId = iss.StoredProcedureId

	   INSERT INTO dbo.SpmSpIssue(StoredProcedureId, IssueId, DeveloperId, ActionName, VersionId, [Status], [Description],ModifiedBy,ModifiedDate)
	   SELECT iss.StoredProcedureId, iss.IssueId, iss.DeveloperId, iss.ActionName, iss.VersionId, iss.[Status], iss.[Description],@CreatedBy, GETDATE()
	   FROM #StoredProceduresIssues AS iss

	   -- nested
	   DELETE spre
	   FROM dbo.SpmSpRelation AS spre WITH (NOLOCK)
	   INNER JOIN #NestedSps AS nes ON spre.StoredProcedureId = nes.StoredProcedureId

	   INSERT INTO dbo.SpmSpRelation(StoredProcedureId, NestedSpId)
	   SELECT DISTINCT nes.StoredProcedureId, nes.NestedSpId
	   FROM #NestedSps AS nes
	   WHERE nes.NestedSpId > 0

	   --System function
	   ----Update StoredProcedureId for #tblSystemFunctions
	   UPDATE sf
	   SET sf.StoredProcedureId = sp.StoredProcedureId
	   FROM #tblSystemFunctions AS sf
	   INNER JOIN dbo.SpmStoredProcedure AS sp WITH(NOLOCK)
		  ON sp.Name = sf.Name 
			 AND sp.AliasServerId = sf.AliasServerId 
			 AND sp.DatabaseId = sf.DatabaseId
			 AND sp.IsDeleted = 0
	   
        DELETE spf
        FROM dbo.SpmSpFunction AS spf
            INNER JOIN #tblSystemFunctions AS tsf ON spf.StoredProcedureId = tsf.StoredProcedureId
            LEFT JOIN #tblSystemFunctions AS fn ON spf.FunctionId = fn.FunctionId 
	            AND fn.SystemId = spf.SystemId
	            AND fn.ProductId = spf.ProductId
        WHERE fn.FunctionId IS NULL

        DELETE fn
        FROM dbo.SpmSpFunction AS spf WITH (NOLOCK)
        INNER JOIN #tblSystemFunctions AS fn ON spf.FunctionId = fn.FunctionId 
	        AND fn.SystemId = spf.SystemId
	        AND fn.ProductId = spf.ProductId
	        AND spf.StoredProcedureId = fn.StoredProcedureId

	   ----Insert new SpmSpFunction
	   INSERT INTO dbo.SpmSpFunction
	   (
	       StoredProcedureId,
	       FunctionId,
	       SystemId,
	       ProductId,
	       ModifiedBy,
	       ModifiedDate
	   )
	   SELECT DISTINCT
        sf.StoredProcedureId,
		  sf.FunctionId,
		  sf.SystemId,
		  sf.ProductId,
		  @CreatedBy,
		  GETDATE()
	   FROM #tblSystemFunctions AS sf
	   WHERE sf.SystemId > 0
	 
	   --Write log
	   INSERT INTO dbo.LogDetail
	   (	    
	       UserId,
	       SpName,
	       LogDate,
	       ObjectId,
	       ObjectTypeId,
	       ActionId,
	       Data,
	       OldData,
	       ObjectIds
	   )
	   SELECT DISTINCT
		  @CreatedBy,
		  spLog.SpNameLog,
		  GETDATE(),
		  sp.StoredProcedureId,
		  @ObjectTypeId,
		  la.Id,
		  [dbo].[fncGetDataForWriteLog](sp.StoredProcedureId, @ObjectTypeId),
		  spLog.OldData,
		  NULL
	   FROM #tblSpLogs AS spLog
		  INNER JOIN dbo.SpmStoredProcedure AS sp WITH (NOLOCK)
			 ON sp.Name = spLog.SpName
				AND sp.AliasServerId = spLog.AliasServerId
				AND sp.DatabaseId = spLog.DatabaseId
				AND sp.IsDeleted = 0
		  INNER JOIN dbo.LogAction AS la WITH (NOLOCK)
			 ON la.SpName = spLog.SpNameLog
	   WHERE ISNULL(spLog.OldData,'') <> [dbo].[fncGetDataForWriteLog](sp.StoredProcedureId, @ObjectTypeId)

	   COMMIT
	END TRY
	BEGIN CATCH
	    ROLLBACK
        SELECT @ErrCode = 100
                ,@ErrMsg = ERROR_MESSAGE()
	END CATCH
END


