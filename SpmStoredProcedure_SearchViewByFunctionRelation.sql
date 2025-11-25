--EXEC SpmStoredProcedure_SearchViewByFunctionRelation NULL,NULL,NULL 
CREATE PROC [dbo].[SpmStoredProcedure_SearchViewByFunctionRelation]    
    @SpName VARCHAR( 300 )= NULL,
    @DbServerId INT = NULL,
    @SystemId INT = NULL,
    @FunctionId VARCHAR(MAX) = NULL,
    @ProductId VARCHAR(MAX) = NULL,
    @DatabaseId INT = NULL,
    @TagId INT = NULL,
    @AliasServerId INT = NULL,
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
    - @UsedSps: <ROOT>
                    <SP Name="SpA" DbServer="DB02" Database="bodb02"></SP>
              </ROOT>
*/
BEGIN
    SET NOCOUNT ON
    
    DECLARE @DocHandler INT
    DECLARE @tblFunction TABLE (
        FunctionId INT PRIMARY KEY
    )        
    DECLARE @tblProduct TABLE (
        ProductId INT PRIMARY KEY
    )

    CREATE TABLE #tblStoredProcedure(
        StoredProcedureId INT PRIMARY KEY,
        SpName VARCHAR(100)
    )

    CREATE TABLE #tblUsedSp(
        StoredProcedureId INT,
        Name VARCHAR(100),
        DbServer VARCHAR(100),
        [Database] VARCHAR(100)
    )

	CREATE TABLE #tblParentStoredProcedure(
       SystemFunction VARCHAR(250),        
       StoredProcedureId INT,
       SpName VARCHAR(100),
	   ParentId INT DEFAULT 0,
	   PRIMARY KEY CLUSTERED (SystemFunction,StoredProcedureId,ParentId)
    )

    CREATE TABLE #tblPagedStoredProcedure(
       SystemFunction VARCHAR(250),        
       StoredProcedureId INT,
       SpName VARCHAR(100),
	   PRIMARY KEY CLUSTERED (SystemFunction,StoredProcedureId)
    )

	CREATE TABLE #tblNestedStoredProcedure(
       SystemFunction VARCHAR(250),
       StoredProcedureId INT,
       SpName VARCHAR(100),
	   ParentId INT,
       [SpDescription] NVARCHAR(2000),
       ModifiedDate DATETIME,
       CallByWeb BIT,
       CallByExecRef BIT,
       DevDbServerName VARCHAR(100),
       LocalDbServerName VARCHAR(100),
       SITDbServerName VARCHAR(100),
       SIT2DbServerName VARCHAR(100),
       MNLDbServerName VARCHAR(100),
       PRODDbServerName VARCHAR(100),      
       SpTypeId INT,
       SpTypeName NVARCHAR(100),
       AliasServerId INT,
       AliasServerName VARCHAR(100),       
       DatabaseId INT,
       DatabaseName VARCHAR(100)
    )
    
    CREATE TABLE #tblRedmineChildIssue(
       Id INT PRIMARY KEY
    )

    IF ISNULL(@RedmineIssueIds,'') <> ''
    BEGIN
        INSERT INTO #tblRedmineChildIssue (Id)
		SELECT DISTINCT CAST(val AS INT) FROM fnc_strSplit (@RedmineIssueIds, ',')
    END
    
    INSERT INTO @tblFunction   
    SELECT val FROM fnc_strSplit(@FunctionId,',') 

    INSERT INTO @tblProduct   
    SELECT val FROM fnc_strSplit(@ProductId,',')

    IF ISNULL(@UsedSps,'') <> ''
    BEGIN
        EXEC sp_xml_preparedocument @DocHandler OUTPUT, @UsedSps
        INSERT INTO #tblUsedSp
        (        
            Name,
            DbServer,
            [Database]
        )    
        SELECT
            RTRIM(LTRIM(Name)),
            RTRIM(LTRIM(DbServer)),
            RTRIM(LTRIM([Database])) 
        FROM OPENXML(@DocHandler, '/ROOT/SP', 1) 
        WITH (Name VARCHAR(100),
            DbServer VARCHAR(100),
            [Database] VARCHAR(100)) AS Data
        EXEC sp_xml_removedocument @DocHandler

        UPDATE us
        SET
            us.StoredProcedureId = sp.StoredProcedureId
        FROM #tblUsedSp AS us
            INNER JOIN dbo.SpmDbServer AS ds WITH(NOLOCK) ON us.DbServer = ds.Name AND ds.IsActive = 1 AND ds.IsDeleted = 0
            INNER JOIN dbo.SpmDatabase AS db WITH(NOLOCK) ON db.Name = us.[Database] AND db.IsActive = 1 AND db.IsDeleted = 0
            INNER JOIN dbo.SpmAliasServerEnvironment AS ae WITH(NOLOCK) ON ds.DbServerId = ae.DbServerId AND ae.EnvironmentId = 4
            INNER JOIN dbo.SpmAliasServer AS al WITH(NOLOCK) ON al.AliasServerId = ae.AliasServerId AND al.IsActive = 1 AND al.IsDeleted = 0
            INNER JOIN dbo.SpmAliasServerDatabase AS ab WITH(NOLOCK) ON db.DatabaseId = ab.DatabaseId AND al.AliasServerId = ab.AliasServerId  
            INNER JOIN dbo.SpmStoredProcedure AS sp WITH(NOLOCK) 
                ON sp.Name = us.Name 
                    AND sp.AliasServerId = al.AliasServerId 
                    AND sp.DatabaseId = db.DatabaseId  
                    AND sp.IsActive    = 1
                    AND sp.IsDeleted = 0
    END
    
    CREATE TABLE #tblParentFunctions(
        StoredProcedureId INT,      
        SystemId INT,
        SystemName VARCHAR(100),
        FunctionId INT,
        FunctionName VARCHAR(100),
        ParentId INT,
        IsLeaf BIT
    )

    CREATE TABLE #tblFuctionRelation(
        StoredProcedureId INT,      
        SystemId INT,       
        FunctionId INT,       
        ParentId INT,
        IsLeaf BIT,
        RelationPath VARCHAR(1000)
    )

    INSERT INTO #tblStoredProcedure    
    SELECT DISTINCT              
       sp.StoredProcedureId,
       sp.Name AS SpName       
    FROM [dbo].[SpmStoredProcedure] AS sp WITH (NOLOCK)
       INNER JOIN [dbo].[SpmAliasServer] AS al WITH (NOLOCK) 
            ON al.AliasServerId = sp.AliasServerId AND al.IsActive = 1 AND al.IsDeleted = 0      
        INNER JOIN [dbo].[SpmDatabase] AS db WITH (NOLOCK) 
            ON db.DatabaseId = sp.DatabaseId AND db.IsActive = 1 AND db.IsDeleted = 0
        LEFT JOIN [dbo].[SpmAliasServerEnvironment] AS aev WITH (NOLOCK) 
            ON aev.AliasServerId = al.AliasServerId
        LEFT JOIN dbo.SpmDbServer AS ds WITH (NOLOCK)
            ON ds.DbServerId = aev.DbServerId AND ds.IsActive = 1 AND ds.IsDeleted = 0
        LEFT JOIN [dbo].[SpmSpFunction] AS sf WITH (NOLOCK) 
            ON sf.StoredProcedureId = sp.StoredProcedureId
        LEFT JOIN [dbo].[SpmFunction] AS f WITH (NOLOCK) 
            ON f.FunctionId = sf.FunctionId AND f.IsActive = 1 AND f.IsDeleted = 0
        LEFT JOIN dbo.SpmFunctionGroup AS fg WITH(NOLOCK)
            ON fg.FunctionGroupId = f.FunctionGroupId AND fg.IsActive = 1 AND fg.IsDeleted = 0                
        LEFT JOIN [dbo].[SpmSystem] AS s WITH (NOLOCK) 
            ON s.SystemId = sf.SystemId AND s.IsActive = 1 AND s.IsDeleted = 0
        LEFT JOIN [dbo].[SpmProduct] AS p WITH (NOLOCK) 
            ON p.ProductId = sf.ProductId AND p.IsActive = 1 AND p.IsDeleted = 0
        LEFT JOIN dbo.SpmSpIssue AS spi WITH (NOLOCK) 
            ON sp.StoredProcedureId = spi.StoredProcedureId
        LEFT JOIN @tblFunction AS tf ON sf.FunctionId = tf.FunctionId
        LEFT JOIN @tblProduct AS tp ON sf.ProductId = tp.ProductId
        LEFT JOIN #tblRedmineChildIssue AS ri ON spi.IssueId = ri.Id  
        LEFT JOIN #tblUsedSp AS us ON sp.StoredProcedureId = us.StoredProcedureId           
    WHERE
        sp.IsActive    = 1 
        AND sp.IsDeleted = 0
        AND (ISNULL(@SpName,'') = '' OR sp.Name LIKE '%' + @SpName + '%')
        AND (@DbServerId IS NULL OR ds.DbServerId = @DbServerId)
        AND (
            (
                @OrphanSps = 0
                AND (@SystemId IS NULL OR s.SystemId = @SystemId)
                AND (
                    ISNULL(@FunctionId,'') = '' 
                    OR f.FunctionId = tf.FunctionId
                )
                AND (
                    ISNULL(@ProductId,'') = '' 
                    OR p.ProductId = tp.ProductId
                )
            ) OR (@OrphanSps = 1 AND sf.StoredProcedureId IS NULL)
        )
        AND (@DatabaseId IS NULL OR db.DatabaseId = @DatabaseId)                 
        AND (@AliasServerId IS NULL OR al.AliasServerId = @AliasServerId)
        AND (
            ISNULL(@RedmineIssueIds,'') = ''
            OR spi.IssueId = ri.Id
        )
        AND (
            ISNULL(@UsedSps,'') = ''
            OR us.StoredProcedureId IS NULL
        )
        
    -- Prepare Parent Functions data
    ;WITH ParentFunctions( 
        StoredProcedureId,      
        SystemId,
        SystemName,
        FunctionId,
        FunctionName,
        ParentId,
        IsLeaf
    ) AS (
        (
            SELECT
                spid.StoredProcedureId,                
                s.SystemId,
                s.Name AS SystemName,
                f.FunctionId, 
                f.Name AS FunctionName,
                ISNULL(fr.ParentId,-1) AS ParentId,
                1 AS IsLeaf
            FROM #tblStoredProcedure AS spid
                INNER JOIN dbo.SpmSpFunction AS sf WITH (NOLOCK) ON spid.StoredProcedureId = sf.StoredProcedureId
                INNER JOIN dbo.SpmSystem AS s WITH (NOLOCK) ON sf.SystemId = s.SystemId
                LEFT JOIN dbo.SpmFunction AS f WITH (NOLOCK) ON sf.FunctionId = f.FunctionId AND f.IsActive = 1 AND f.IsDeleted = 0
                LEFT JOIN dbo.SpmFunctionRelation AS fr WITH (NOLOCK) ON s.SystemId = fr.SystemId AND f.FunctionId = fr.FunctionId
                LEFT JOIN @tblFunction AS tf ON sf.FunctionId = tf.FunctionId
            WHERE s.IsActive = 1
                AND s.IsDeleted = 0
                AND (@SystemId IS NULL OR s.SystemId = @SystemId)
                AND (
                    ISNULL(@FunctionId,'') = '' 
                    OR f.FunctionId = tf.FunctionId
                )          
        )
        UNION ALL
        (
            SELECT    
                pf.StoredProcedureId,            
                pf.SystemId,
                pf.SystemName,
                f.FunctionId, 
                f.Name AS FunctionName,
                fr.ParentId,
                0 AS IsLeaf
           FROM ParentFunctions AS pf
                INNER JOIN dbo.SpmFunctionRelation AS fr WITH (NOLOCK) ON pf.ParentId = fr.FunctionId AND pf.SystemId = fr.SystemId
                INNER JOIN dbo.SpmFunction AS f WITH (NOLOCK) ON fr.FunctionId = f.FunctionId
            WHERE f.IsActive = 1
                AND f.IsDeleted = 0                 
        )                              
    )
    INSERT INTO #tblParentFunctions
    (
        StoredProcedureId,
        SystemId,
        SystemName,
        FunctionId,
        FunctionName,
        ParentId,
        IsLeaf
    )    
    SELECT        
        StoredProcedureId,      
        SystemId,
        SystemName,
        FunctionId,
        FunctionName,
        ParentId,
        IsLeaf
    FROM ParentFunctions

    -- Get Relation Path
    ;WITH TopParents
    (
        StoredProcedureId,      
        SystemId,
        SystemName,
        FunctionId,
        FunctionName,
        ParentId,
        RelationPath,
        IsLeaf
    ) 
    AS(
        (
            SELECT 
                StoredProcedureId,      
                SystemId,
                SystemName,
                FunctionId,
                FunctionName,
                ParentId,
                (CASE WHEN SystemName IS NOT NULL AND FunctionName IS NULL THEN SystemName
                    ELSE CAST((SystemName +' / ' + FunctionName) AS VARCHAR(500)) END) AS RelationPath,
                IsLeaf
            FROM #tblParentFunctions 
            WHERE ParentId = -1
        )UNION ALL(
            SELECT 
                p.StoredProcedureId,      
                p.SystemId,
                p.SystemName,
                t.FunctionId,
                t.FunctionName,
                t.ParentId,
                CAST((p.RelationPath + ISNULL((' / ' + t.FunctionName),'')) AS VARCHAR(500)) AS RelationPath,
                t.IsLeaf
            FROM TopParents AS p
                INNER JOIN #tblParentFunctions AS t 
                    ON p.StoredProcedureId = t.StoredProcedureId
                        AND p.SystemId = t.SystemId
                        AND p.FunctionId = t.ParentId
        )
    )
    INSERT INTO #tblFuctionRelation
    (
        StoredProcedureId,
        SystemId,
        FunctionId,
        ParentId,
        IsLeaf,
        RelationPath
    )    
    SELECT
        StoredProcedureId,
        SystemId,
        FunctionId,
        ParentId,
        IsLeaf,
        RelationPath 
    FROM TopParents
    WHERE IsLeaf = 1    
	
	INSERT INTO #tblParentStoredProcedure 
	SELECT DISTINCT
		d.SystemFunction,
        d.StoredProcedureId,
        d.SpName,
		ISNULL(parent.StoredProcedureId,0)
	FROM (	
		SELECT
			ISNULL(fr.RelationPath,'None') AS  SystemFunction,
			sp.StoredProcedureId,
			sp.SpName
		FROM #tblStoredProcedure AS sp
			LEFT JOIN #tblFuctionRelation AS fr ON sp.StoredProcedureId = fr.StoredProcedureId
	) AS d
		LEFT JOIN dbo.SpmSpRelation AS sr WITH(NOLOCK) ON d.StoredProcedureId = sr.NestedSpId
		LEFT JOIN #tblStoredProcedure AS parent WITH(NOLOCK) ON sr.StoredProcedureId = parent.StoredProcedureId
		LEFT JOIN #tblFuctionRelation AS fr ON parent.StoredProcedureId = fr.StoredProcedureId AND d.SystemFunction = ISNULL(fr.RelationPath,'None')

    INSERT INTO #tblPagedStoredProcedure
    SELECT
        d.SystemFunction,
        d.StoredProcedureId,
        d.SpName
    FROM #tblParentStoredProcedure AS d		
		LEFT JOIN #tblParentStoredProcedure AS sp ON sp.StoredProcedureId = d.StoredProcedureId 
				AND sp.SystemFunction = d.SystemFunction
				AND sp.ParentId > 0
	WHERE
		d.ParentId = 0	
		AND sp.StoredProcedureId IS NULL
	ORDER BY
       d.SystemFunction,
       d.SpName
    OFFSET (@PageIndex * @ItemsPerPage) ROWS
    FETCH NEXT @ItemsPerPage ROWS ONLY

	-- Total Item
    SET @TotalItem = (
		SELECT COUNT(*) 
		FROM #tblParentStoredProcedure AS d
			LEFT JOIN #tblParentStoredProcedure AS sp ON sp.StoredProcedureId = d.StoredProcedureId 
				AND sp.SystemFunction = d.SystemFunction
				AND sp.ParentId > 0
		WHERE d.ParentId = 0 AND sp.StoredProcedureId IS NULL
	)
	
	;WITH Dependencies(		
		SystemFunction,     
		StoredProcedureId,
		SpName,
		ParentId
	) AS (
		SELECT
			sub.SystemFunction,     
			sub.StoredProcedureId,
			sub.SpName,
			0 AS ParentId			
		FROM #tblPagedStoredProcedure AS sub
		UNION ALL
		SELECT
			sp.SystemFunction,
			sp.StoredProcedureId,
			sp.SpName,
			sp.ParentId
		FROM Dependencies AS d
			INNER JOIN #tblParentStoredProcedure AS sp ON d.StoredProcedureId = sp.ParentId
				AND sp.StoredProcedureId <> d.ParentId
				AND sp.SystemFunction = d.SystemFunction
	)
	INSERT INTO #tblNestedStoredProcedure    
    SELECT DISTINCT
        d.SystemFunction,
        d.StoredProcedureId,
        d.SpName,    
		d.ParentId,
        sp.[Description],
        sp.ModifiedDate,
        sp.CallByWeb,
        sp.CallByExecRef,
        dbo.fnGetDbServerName(sp.AliasServerId,1) AS DevDbServerName,
        dbo.fnGetDbServerName(sp.AliasServerId,2) AS LocalDbServerName,
        dbo.fnGetDbServerName(sp.AliasServerId,3) AS SITDbServerName,
        dbo.fnGetDbServerName(sp.AliasServerId,6) AS SIT2DbServerName,
        dbo.fnGetDbServerName(sp.AliasServerId,5) AS MNLDbServerName,  
        dbo.fnGetDbServerName(sp.AliasServerId,4) AS PRODDbServerName,
        sp.SpTypeId,
        ld.Name,
        al.AliasServerId,
        al.Name,        
        db.DatabaseId,
        db.Name
    FROM Dependencies AS d
        INNER JOIN dbo.SpmStoredProcedure AS sp WITH(NOLOCK) ON d.StoredProcedureId = sp.StoredProcedureId
        INNER JOIN [dbo].[LookupData] AS ld WITH (NOLOCK) 
                ON sp.SpTypeId = ld.[Value] 
                    AND ld.LookupId = 2 -- sp type
        INNER JOIN dbo.SpmAliasServer AS al WITH(NOLOCK) ON sp.AliasServerId = al.AliasServerId
        INNER JOIN dbo.SpmDatabase AS db WITH(NOLOCK) ON sp.DatabaseId = db.DatabaseId
	ORDER BY
       d.SystemFunction,
       d.SpName    
    
    --Stored procedure
    SELECT
        sub.SystemFunction,        
        sub.StoredProcedureId,
        sub.SpName AS Name,
		sub.ParentId,
        sub.SpDescription AS [Description],
        sub.ModifiedDate,
        sub.CallByWeb,
        sub.CallByExecRef,
        sub.DevDbServerName,
        sub.LocalDbServerName,
        sub.SITDbServerName,
        sub.SIT2DbServerName,
        sub.MNLDbServerName,
        sub.PRODDbServerName,        
        sub.SpTypeId,
        sub.SpTypeName AS Name,
        sub.AliasServerId,
        sub.AliasServerName AS Name,      
        sub.DatabaseId,
        sub.DatabaseName AS Name
    FROM #tblNestedStoredProcedure AS sub
	ORDER BY
		sub.SystemFunction,
		sub.SpName

    -- Redmine info
    SELECT DISTINCT
        spi.StoredProcedureId,
        spi.IssueId,       
        spi.ModifiedDate,
        spi.[Status] AS StatusId,
        sta.Name,       
        spi.DeveloperId AS UserId,
        e.NickName
    FROM #tblNestedStoredProcedure AS spid 
        INNER JOIN dbo.SpmSpIssue AS spi WITH (NOLOCK) ON spid.StoredProcedureId = spi.StoredProcedureId
        INNER JOIN dbo.LookupData AS sta WITH (NOLOCK) ON spi.[Status] = sta.Value AND sta.LookupId = 6 -- 6: is sp status
        INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON spi.DeveloperId = e.EmployeeId
    ORDER BY spi.ModifiedDate DESC
    
    -- Function Relation
    SELECT DISTINCT        
        StoredProcedureId,
        RelationPath
    FROM #tblFuctionRelation
END