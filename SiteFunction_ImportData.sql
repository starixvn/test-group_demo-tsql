CREATE PROC [dbo].[SiteFunction_ImportData]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON

    DECLARE @ModifiedBy INT = 287 -- Larry
    DECLARE @ModifiedDate DATETIME = GETDATE()
    DECLARE @IsActive BIT = 1
    DECLARE @IsDeleted BIT = 0
    DECLARE @NullProductId INT = -1

    IF OBJECT_ID('#tblImportFunction') IS NOT NULL
    BEGIN
	   DROP TABLE #tblImportFunction
    END

    CREATE TABLE #tblImportFunction(
        Functions VARCHAR(2000),
        Name VARCHAR(100),
        Id INT NULL
    )

    IF OBJECT_ID('#tblImportProduct') IS NOT NULL
    BEGIN
	   DROP TABLE #tblImportProduct
    END

    CREATE TABLE #tblImportProduct(
        Products VARCHAR(1000),
        Name VARCHAR(100),
        Id INT NULL
    )

    BEGIN TRANSACTION

    --Correct data
    UPDATE sf
    SET sf.[Group] = replace( sf.[Group],'- ',' - '),
        sf.Functions = replace( sf.Functions,'- ',' - ')
    FROM dbo.ImportSystemFunction AS sf

    --Prepare data
    INSERT INTO #tblImportFunction
    (
        Functions,
        Name
    )    
    SELECT DISTINCT
        f.Functions,
        LTRIM(RTRIM(fn.val))
    FROM dbo.ImportSystemFunction AS f WITH (NOLOCK)
        CROSS APPLY dbo.fnc_strSplit(f.Functions,',') AS fn

    INSERT INTO #tblImportProduct
    (
        Products,
        Name
    )
    SELECT DISTINCT
        f.Products,
        LTRIM(RTRIM(fn.val))
    FROM dbo.ImportSystemFunction AS f WITH (NOLOCK)
        CROSS APPLY dbo.fnc_strSplit(f.Products,',') AS fn
    WHERE ISNULL(fn.val,'') <> ''

    --Insert System
    INSERT INTO dbo.SpmSystem
    (    
        Name,        
        IsActive,
        ModifiedBy,
        ModifiedDate,
        IsDeleted
    )    
    SELECT DISTINCT 
        LTRIM(RTRIM(Site)),
        @IsActive,
        @ModifiedBy,
        @ModifiedDate,
        @IsDeleted
    FROM [dbo].[ImportSystemFunction] AS sf WITH (NOLOCK)
        LEFT JOIN dbo.SpmSystem AS s WITH (NOLOCK) ON LTRIM(RTRIM(sf.[Site])) = s.Name
    WHERE s.SystemId IS NULL

    ----Update SiteId
    UPDATE sf
    SET
        sf.SiteId = s.SystemId
    FROM dbo.ImportSystemFunction AS sf WITH (NOLOCK)
        INNER JOIN dbo.SpmSystem AS s WITH (NOLOCK) ON LTRIM(RTRIM(sf.[Site])) = s.Name

    --Insert Function Group
    INSERT INTO dbo.SpmFunctionGroup
    (     
        Name,        
        IsActive,
        ModifiedBy,
        ModifiedDate,
        IsDeleted
    )    
    SELECT DISTINCT 
        LTRIM(RTRIM(sf.[Group])),
        @IsActive,
        @ModifiedBy,
        @ModifiedDate,
        @IsDeleted
    FROM dbo.ImportSystemFunction AS sf WITH (NOLOCK)
        LEFT JOIN dbo.SpmFunctionGroup AS fg WITH (NOLOCK) ON LTRIM(RTRIM(sf.[Group])) = fg.Name
    WHERE fg.FunctionGroupId IS NULL

    ----Update GroupId
    UPDATE sf
    SET
        sf.GroupId = g.FunctionGroupId
    FROM dbo.ImportSystemFunction AS sf WITH (NOLOCK)
        INNER JOIN dbo.SpmFunctionGroup AS g WITH (NOLOCK) ON LTRIM(RTRIM(sf.[Group])) = g.Name
    
    --Insert Function
    INSERT INTO dbo.SpmFunction
    (       
        Name,
        IsActive,        
        ModifiedBy,
        ModifiedDate,
        IsDeleted
    )    
    SELECT DISTINCT
        i.Name,
        @IsActive,
        @ModifiedBy,
        @ModifiedDate,
        @IsDeleted
    FROM #tblImportFunction AS i WITH (NOLOCK)
        INNER JOIN dbo.ImportSystemFunction AS sf WITH (NOLOCK) ON i.Functions = sf.Functions
        LEFT JOIN dbo.SpmFunction AS f WITH (NOLOCK) ON i.Name = f.Name
    WHERE f.FunctionId IS NULL    

    ----Update Function Id
    UPDATE tf
    SET
        tf.Id = f.FunctionId
    FROM #tblImportFunction AS tf WITH (NOLOCK)
        INNER JOIN dbo.SpmFunction AS f WITH (NOLOCK) ON tf.Name = f.Name

    ----Update Function Group
    UPDATE f
    SET
        f.FunctionGroupId = sf.GroupId
    FROM #tblImportFunction AS i WITH (NOLOCK)
        INNER JOIN dbo.ImportSystemFunction AS sf WITH (NOLOCK) ON i.Functions = sf.Functions
        INNER JOIN dbo.SpmFunction AS f WITH (NOLOCK) ON i.Id = f.FunctionId

    --Insert Product
    INSERT INTO dbo.SpmProduct
    (       
        Name,        
        IsActive,
        ModifiedBy,
        ModifiedDate,
        IsDeleted
    )
    SELECT DISTINCT
        tp.Name,
        @IsActive,
        @ModifiedBy,
        @ModifiedDate,
        @IsDeleted
    FROM #tblImportProduct AS tp WITH (NOLOCK)
        LEFT JOIN dbo.SpmProduct AS p WITH (NOLOCK) ON tp.Name = p.Name
    WHERE p.ProductId IS NULL

    ----Update Product Id
    UPDATE tp
    SET
        tp.Id = p.ProductId
    FROM #tblImportProduct AS tp WITH (NOLOCK)
        INNER JOIN dbo.SpmProduct AS p WITH (NOLOCK) ON tp.Name = p.Name
    
    --Insert [SpmFunctionSystemProduct]
    INSERT INTO dbo.SpmFunctionSystemProduct
    (
        FunctionId,
        SystemId,
        ProductId
    )    
    SELECT DISTINCT
        f.Id,
        sf.SiteId,
        ISNULL(p.Id,-1)
    FROM dbo.ImportSystemFunction AS sf WITH (NOLOCK)        
        INNER JOIN #tblImportFunction AS f ON sf.Functions  = f.Functions
        LEFT JOIN #tblImportProduct AS p ON sf.Products = p.Products
        LEFT JOIN dbo.SpmFunctionSystemProduct AS fsp WITH (NOLOCK) 
            ON sf.SiteId = fsp.SystemId 
                AND fsp.FunctionId = f.Id
                AND (ISNULL(p.Id,-1) = -1 OR fsp.ProductId = p.Id)
    WHERE fsp.FunctionId IS NULL
    
    --Insert Alias Server
    INSERT INTO dbo.SpmAliasServer
    (       
        Name,        
        IsActive,
        ModifiedBy,
        ModifiedDate,
        IsDeleted
    )
    SELECT DISTINCT
        LTRIM(RTRIM(f.ServerAlias)),
        @IsActive,
        @ModifiedBy,
        @ModifiedDate,
        @IsDeleted
    FROM dbo.ImportSystemFunction AS f WITH (NOLOCK)
        LEFT JOIN dbo.SpmAliasServer AS al WITH (NOLOCK) ON LTRIM(RTRIM(f.ServerAlias)) = al.Name
    WHERE al.AliasServerId IS NULL

    ----Update Server Alias Id
    UPDATE f
    SET
        f.ServerAliasId = al.AliasServerId
    FROM dbo.ImportSystemFunction AS f WITH (NOLOCK)
        INNER JOIN dbo.SpmAliasServer AS al WITH (NOLOCK) ON LTRIM(RTRIM(f.ServerAlias)) = al.Name

    --Insert Database
    INSERT INTO dbo.SpmDatabase
    (        
        Name,        
        IsActive,
        ModifiedBy,
        ModifiedDate,
        IsDeleted
    )
    SELECT DISTINCT
        LTRIM(RTRIM(f.[Database])),
        @IsActive,
        @ModifiedBy,
        @ModifiedDate,
        @IsDeleted
    FROM dbo.ImportSystemFunction AS f WITH (NOLOCK)
        LEFT JOIN dbo.SpmDatabase AS d WITH (NOLOCK) ON LTRIM(RTRIM(f.[Database])) = d.Name
    WHERE d.DatabaseId IS NULL

    ----Update Database Id
    UPDATE f
    SET
        f.DatabaseId = d.DatabaseId
    FROM dbo.ImportSystemFunction AS f WITH (NOLOCK)
        INNER JOIN dbo.SpmDatabase AS d WITH (NOLOCK) ON LTRIM(RTRIM(f.[Database])) = d.Name

    --Insert Alias / Database relation
    INSERT INTO dbo.SpmAliasServerDatabase
    (
        AliasServerId,
        DatabaseId
    )
    SELECT DISTINCT
        f.ServerAliasId,
        f.DatabaseId
    FROM dbo.ImportSystemFunction AS f WITH (NOLOCK)
        LEFT JOIN SpmAliasServerDatabase AS ad WITH (NOLOCK) ON ad.DatabaseId = f.DatabaseId AND ad.AliasServerId = f.ServerAliasId
    WHERE ad.AliasServerId IS NULL

    --Insert Stored Procedure
    INSERT INTO dbo.SpmStoredProcedure
    (       
        Name,
        AliasServerId,
        DatabaseId,
        IsActive,
        CallByWeb,
        CallByExecRef,
        SpTypeId,        
        ModifiedBy,
        ModifiedDate,
        IsDeleted
    )
    SELECT DISTINCT
        LTRIM(RTRIM(f.StoredProcedure)),
        f.ServerAliasId,
        f.DatabaseId,
        @IsActive,
        f.CallByWeb,
        f.CallByExecRef,
        CAST(f.IsFunction AS INT) + 1 AS SpTypeId,
        @ModifiedBy,
        @ModifiedDate,
        @IsDeleted
    FROM dbo.ImportSystemFunction AS f WITH(NOLOCK)
        LEFT JOIN dbo.SpmStoredProcedure AS sp WITH(NOLOCK) 
            ON LTRIM(RTRIM(f.StoredProcedure)) = sp.Name
                AND f.DatabaseId = sp.DatabaseId
                AND f.ServerAliasId = sp.AliasServerId
    WHERE sp.StoredProcedureId IS NULL

    --Update CallByWeb, CallByExecRef
    UPDATE sp
    SET
        sp.CallByWeb = f.CallByWeb,
        sp.CallByExecRef = f.CallByExecRef
    FROM dbo.ImportSystemFunction AS f WITH(NOLOCK)
        INNER JOIN dbo.SpmStoredProcedure AS sp WITH(NOLOCK) 
            ON LTRIM(RTRIM(f.StoredProcedure)) = sp.Name
                AND f.DatabaseId = sp.DatabaseId
                AND f.ServerAliasId = sp.AliasServerId

    ----Update Stored Procedure Id
    UPDATE f
    SET
        f.StoredProcedureId = sp.StoredProcedureId
    FROM dbo.ImportSystemFunction AS f WITH(NOLOCK)
        INNER JOIN dbo.SpmStoredProcedure AS sp WITH(NOLOCK) 
            ON LTRIM(RTRIM(f.StoredProcedure)) = sp.Name
                AND f.DatabaseId = sp.DatabaseId
                AND f.ServerAliasId = sp.AliasServerId

    --Insert SP / System / Function / Product
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
        f.Id,
        sf.SiteId,
        ISNULL(p.Id,-1),
        @ModifiedBy,
        @ModifiedDate
    FROM dbo.ImportSystemFunction AS sf WITH(NOLOCK)
        INNER JOIN #tblImportFunction AS f ON sf.Functions = f.Functions
        LEFT JOIN #tblImportProduct AS p ON sf.Products = p.Products
        LEFT JOIN dbo.SpmSpFunction AS spf WITH(NOLOCK)
            ON sf.StoredProcedureId = spf.StoredProcedureId
                AND sf.SiteId = spf.SystemId
                AND f.Id = spf.FunctionId
                AND (
                    ISNULL(p.Id,-1) = -1
                    OR p.Id = spf.ProductId
                )
    WHERE spf.StoredProcedureId IS NULL

    --Update NestedStoredProcedureId
    UPDATE sf
        SET sf.NestedStoredProcedureId = sp.StoredProcedureId
    FROM dbo.SpmStoredProcedure AS sp WITH(NOLOCK)
        INNER JOIN dbo.SpmAliasServer AS al WITH(NOLOCK) ON sp.AliasServerId = al.AliasServerId
        INNER JOIN dbo.SpmDatabase AS db WITH(NOLOCK) ON sp.DatabaseId = db.DatabaseId
        INNER JOIN dbo.ImportSystemFunction AS sf WITH(NOLOCK)
            ON LTRIM(RTRIM(sf.NestedSP)) = sp.Name
                AND LTRIM(RTRIM(sf.NestedDatabase)) = db.Name
                AND LTRIM(RTRIM(sf.NestedServerAlias)) = al.Name

    --Insert [dbo].[SpmSpRelation]
    INSERT dbo.SpmSpRelation
    (
        StoredProcedureId,
        NestedSpId
    )
    SELECT DISTINCT
        sf.StoredProcedureId, 
        sf.NestedStoredProcedureId
    FROM dbo.ImportSystemFunction AS sf WITH(NOLOCK)
        LEFT JOIN dbo.SpmSpRelation AS r WITH(NOLOCK)
            ON sf.StoredProcedureId = r.StoredProcedureId AND
                sf.NestedStoredProcedureId = r.NestedSpId
    WHERE r.StoredProcedureId IS NULL AND
        sf.NestedStoredProcedureId IS NOT NULL

    COMMIT TRANSACTION

    IF OBJECT_ID('#tblImportFunction') IS NOT NULL
    BEGIN
	   DROP TABLE #tblImportFunction
    END

    IF OBJECT_ID('#tblImportProduct') IS NOT NULL
    BEGIN
	   DROP TABLE #tblImportProduct
    END
END

