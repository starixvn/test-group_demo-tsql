CREATE PROC [dbo].[SpmStoredProcedure_Api-NewImportData]
    @Data VARCHAR(MAX),
    @CreatedBy	INT,
    @ErrCode INT = 0 OUTPUT,
    @ErrMsg VARCHAR(MAX) = '' OUTPUT
AS
/*
Created: 20160921@Larry.Tran
Task: Validate data before importing stored procedure from excel file.
DB: SPM
Original: 

Revisions:  
Param's Explanation:
- @Data: <ROOT>
		  <SP IssueId="1" SPName="" AliasServer="" Database="" Type="" Developer='' Action='' Status='' 
                Version='' CallByWeb='' CallByExecRef='' Description=''></SP>
	   </ROOT>
*/
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @DocHandler INT   
    DECLARE @ImportData dbo.ImportDataTableType
    DECLARE @SpType INT = 2
    DECLARE @SpStatus INT = 6
    DECLARE @SpVersion INT = 3   
    DECLARE @ObjectTypeId INT = 8 -- SP	
    DECLARE @InsertSpNameLog VARCHAR(50) = 'SpmStoredProcedure_Insert'
    DECLARE @UpdateSpNameLog VARCHAR(50) = 'SpmStoredProcedure_Update'    
  
    CREATE TABLE #tblImportData(
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
    
    CREATE TABLE #tblImportSpLogs(	    
	   SpName VARCHAR(100), 
	   AliasServerId INT, 
	   DatabaseId INT, 	
	   SpNameLog VARCHAR(50),    
	   OldData VARCHAR(MAX)
    ) 

    EXEC sp_xml_preparedocument @DocHandler OUTPUT, @Data

    INSERT INTO @ImportData
    SELECT 
        IssueId,
        SPName,
        AliasServer,
        [Database],
        [Type],
        Developer,
        [Action],
        [Status],
        [Version],
        ISNULL(CallByWeb,0),
        ISNULL(CallByExecRef,0),
        [Description]
    FROM OPENXML(@DocHandler, '/ROOT/SP', 1) 
    WITH (
        IssueId INT, 
        SPName VARCHAR(100), 
        AliasServer VARCHAR(100), 
        [Database] VARCHAR(100), 
        [Type] VARCHAR(20),         
        Developer VARCHAR(50), 
        [Action] VARCHAR(20), 
        [Status] VARCHAR(50), 
        [Version] VARCHAR(20), 
        CallByWeb BIT,
        CallByExecRef BIT,
        [Description] NVARCHAR(1000) 
    ) AS Data

    EXEC sp_xml_removedocument @DocHandler

    EXEC SpmStoredProcedure_ValidateImportData @Data = @ImportData, @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
    
    IF ISNULL(@ErrCode,0) = 0
    BEGIN
        SET XACT_ABORT ON
        BEGIN TRAN
	   BEGIN TRY
            --Prepare data
            INSERT INTO #tblImportData
            (
                IssueId,
                StoredProcedureId,
                Name,
                AliasServerId,
                DatabaseId,
                Type,
                CallByWeb,
                CallByExecRef,
                DeveloperId,
                ActionName,
                VersionId,
                Status,
                Description
            )
            SELECT
                IssueId,
                (
                    SELECT TOP 1 sp.StoredProcedureId 
                    FROM dbo.SpmStoredProcedure AS sp WITH (NOLOCK)                  
                    WHERE sp.Name = id.SPName
                        AND sp.IsDeleted = 0
                        AND sp.AliasServerId = al.AliasServerId
                        AND sp.DatabaseId = db.DatabaseId
                ) AS StoredProcedureId,
                id.SPName,
                al.AliasServerId,
                db.DatabaseId,
                ty.[Value] AS [Type],
                id.CallByWeb,
                id.CallByExecRef,
                ISNULL(e.EmployeeId,@CreatedBy) AS DeveloperId,
                id.[Action],
                ver.[Value] AS VersionId,
                sta.[Value] AS [Status],
                id.Description
            FROM @ImportData AS id
                INNER JOIN dbo.SpmAliasServer AS al WITH(NOLOCK) ON al.Name = id.AliasServer
                INNER JOIN dbo.SpmDatabase AS db WITH(NOLOCK) ON db.Name = id.[Database]
                INNER JOIN dbo.LookupData AS ty WITH(NOLOCK) ON id.[Type] = ty.Name AND ty.LookupId = @SpType
                LEFT JOIN dbo.Employee AS e WITH(NOLOCK) ON id.Developer = e.NickName AND e.IsDeleted = 0 AND e.[Enabled] = 1
                INNER JOIN dbo.LookupData AS ver WITH(NOLOCK) ON id.[Version] = ver.Name AND ver.LookupId = @SpVersion
                INNER JOIN dbo.LookupData AS sta WITH(NOLOCK) ON id.[Status] = sta.Name AND sta.LookupId = @SpStatus        
	   
	       --Get data for write Insert log
	       INSERT INTO #tblImportSpLogs
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
	       FROM #tblImportData AS iss
		      LEFT JOIN dbo.SpmStoredProcedure AS sp WITH (NOLOCK) 
			     ON sp.Name = iss.Name 
				    AND sp.AliasServerId = iss.AliasServerId 
				    AND sp.DatabaseId = iss.DatabaseId
				    AND sp.IsDeleted = 0
	       WHERE sp.StoredProcedureId IS NULL

           -- Update sp type if having difference
           UPDATE sp WITH(UPDLOCK,ROWLOCK)
           SET
                sp.SpTypeId = iss.[Type]
           FROM #tblImportData AS iss
	           INNER JOIN dbo.SpmStoredProcedure AS sp ON sp.Name = iss.Name 
		          AND sp.AliasServerId = iss.AliasServerId 
		          AND sp.DatabaseId = iss.DatabaseId
		          AND sp.IsDeleted = 0
            WHERE iss.[Type] <> sp.SpTypeId

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
	       FROM #tblImportData AS iss
	           LEFT JOIN dbo.SpmStoredProcedure AS sp WITH (NOLOCK) ON sp.Name = iss.Name 
		          AND sp.AliasServerId = iss.AliasServerId 
		          AND sp.DatabaseId = iss.DatabaseId
		          AND sp.IsDeleted = 0
	       WHERE sp.StoredProcedureId IS NULL

	       UPDATE iss
	       SET iss.StoredProcedureId = sp.StoredProcedureId
	       FROM dbo.SpmStoredProcedure AS sp WITH (NOLOCK)
	           INNER JOIN #tblImportData AS iss ON sp.Name = iss.Name 
		          AND sp.AliasServerId = iss.AliasServerId 
		          AND sp.DatabaseId = iss.DatabaseId
		          AND sp.IsDeleted = 0
            
	       --Get data for write Update log
	       INSERT INTO #tblImportSpLogs
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
                INNER JOIN #tblImportData AS iss ON sp.StoredProcedureId = iss.StoredProcedureId	      
                LEFT JOIN dbo.SpmSpIssue AS spi
			     ON spi.IssueId = iss.IssueId 
				    AND spi.StoredProcedureId = iss.StoredProcedureId
		      LEFT JOIN #tblImportSpLogs AS spLog
			     ON spLog.SpName = sp.Name
				    AND spLog.AliasServerId = sp.AliasServerId
				    AND spLog.DatabaseId = sp.DatabaseId
	       WHERE spi.StoredProcedureId IS NULL
		      AND spLog.SpName IS NULL
            
	       INSERT INTO dbo.SpmSpIssue(StoredProcedureId, IssueId, DeveloperId, ActionName, VersionId, [Status], [Description],ModifiedBy,ModifiedDate)
	       SELECT iss.StoredProcedureId, iss.IssueId, iss.DeveloperId, iss.ActionName, iss.VersionId, iss.[Status], iss.[Description],@CreatedBy, GETDATE()
	       FROM #tblImportData AS iss
                LEFT JOIN dbo.SpmSpIssue AS spi WITH (NOLOCK)
                    ON spi.IssueId = iss.IssueId AND spi.StoredProcedureId = iss.StoredProcedureId
            WHERE
                spi.StoredProcedureId IS NULL
	       
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
	       FROM #tblImportSpLogs AS spLog
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
            SELECT @ErrCode = 100,
                @ErrMsg= ERROR_MESSAGE()                
	   END CATCH                
    END    
END

