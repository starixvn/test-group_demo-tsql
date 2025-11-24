CREATE PROCEDURE [dbo].[SpmDatabaseStandby_ImportData]
    @StandbyDbData [dbo].[StandbyDbTableType] READONLY,
    @CreatedBy INT,
    @ErrCode INT = 0 OUTPUT,
    @ErrMsg NVARCHAR(MAX) = '' OUTPUT
AS
/*
Created: 20250827@Alex.Tran
Task: Import multiple standby databases from Excel
DB: SPM
Original: Reuses SpmDatabaseStandby_Insert

Param's Explanation:
- @StandbyDbData: Table-valued parameter containing standby database information
- @CreatedBy: User ID who is importing the data
*/
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ImportData TABLE (
        AliasServer VARCHAR(100),
        DbServer VARCHAR(100),
        [Database] VARCHAR(100),
        Environment VARCHAR(100),
        StandbyDatabases VARCHAR(MAX),
        IsActive BIT,
        RowNum INT IDENTITY(1,1)
    )
    
    DECLARE @Results TABLE (
        StandbyId INT,
        AliasServer VARCHAR(100),
        DbServer VARCHAR(100),
        [Database] VARCHAR(100),
        Environment VARCHAR(100),
        StandbyDatabases VARCHAR(MAX),
        IsActive BIT,
        Action VARCHAR(10), -- 'INSERT', 'UPDATE', or 'ERROR'
        Message NVARCHAR(2000),
        IsSuccess BIT DEFAULT 0
    )
    
    INSERT INTO @ImportData (AliasServer, DbServer, [Database], Environment, StandbyDatabases, IsActive)
    SELECT 
        AliasServer,
        DbServer,
        [Database],
        Environment,
        StandbyDatabases,
        IsActive
    FROM @StandbyDbData
    
    -- Check if we have any data to process
    IF NOT EXISTS (SELECT 1 FROM @ImportData)
    BEGIN
        SET @ErrCode = 1
        SET @ErrMsg = 'No data provided for import'
        
        -- Return empty result set
        SELECT 
            CAST(NULL AS INT) AS StandbyId,
            CAST(NULL AS VARCHAR(100)) AS AliasServer,
            CAST(NULL AS VARCHAR(100)) AS DbServer,
            CAST(NULL AS VARCHAR(100)) AS [Database],
            CAST(NULL AS VARCHAR(100)) AS Environment,
            CAST(NULL AS VARCHAR(1000)) AS StandbyDatabases,
            CAST(NULL AS BIT) AS IsActive,
            'ERROR' AS Action,
            'No data provided for import' AS Message,
            CAST(0 AS BIT) AS IsSuccess
        WHERE 1 = 0
        
        RETURN
    END
    
    -- Validate data - check for empty required fields
    INSERT INTO @Results (AliasServer, DbServer, [Database], Environment, StandbyDatabases, IsActive, Action, Message)
    SELECT AliasServer, DbServer, [Database], Environment, StandbyDatabases, IsActive, 'ERROR', 'One or more required fields are empty'
    FROM @ImportData 
    WHERE AliasServer IS NULL OR AliasServer = ''
       OR DbServer IS NULL OR DbServer = ''
       OR [Database] IS NULL OR [Database] = ''
       OR Environment IS NULL OR Environment = ''
       OR StandbyDatabases IS NULL OR StandbyDatabases = ''
    
    IF EXISTS (SELECT 1 FROM @Results WHERE Action = 'ERROR')
    BEGIN
        SET @ErrCode = 1
        SET @ErrMsg = 'One or more required fields are empty'
        
        SELECT StandbyId, AliasServer, DbServer, [Database], Environment, StandbyDatabases, IsActive, Action, Message, IsSuccess
        FROM @Results
        
        RETURN
    END
    
    BEGIN TRY
        BEGIN TRANSACTION
        
        SET XACT_ABORT ON
        
        -- Variables for tracking statistics
        DECLARE @InsertCount INT = 0
        DECLARE @UpdateCount INT = 0
        DECLARE @ErrorCount INT = 0
        
        -- Process each standby database in the import data
        DECLARE @AliasServer VARCHAR(100)
        DECLARE @DbServer VARCHAR(100)
        DECLARE @Database VARCHAR(100)
        DECLARE @Environment VARCHAR(100)
        DECLARE @StandbyDatabases VARCHAR(MAX)
        DECLARE @IsActive BIT
        DECLARE @RowNum INT
        DECLARE @AliasServerId INT
        DECLARE @DbServerId INT
        DECLARE @DatabaseId INT
        DECLARE @EnvironmentId INT
        DECLARE @StandbyId INT
        DECLARE @LocalErrCode INT
        DECLARE @LocalErrMsg NVARCHAR(200)
        DECLARE @HasErrors BIT = 0
        DECLARE @StandbyDbsXml XML
        
        DECLARE @XmlData TABLE (
            DbServerId INT,
            DatabaseId INT
        )
        
        DECLARE @StandbyPairs TABLE (
            Pair NVARCHAR(200)
        )
        
        DECLARE @pos INT
        DECLARE @nextPos INT
        DECLARE @pairValue NVARCHAR(200)
        DECLARE @Pair NVARCHAR(200)
        DECLARE @StandbyDbServer VARCHAR(100)
        DECLARE @StandbyDatabase VARCHAR(100)
        DECLARE @StandbyDbServerId INT
        DECLARE @StandbyDatabaseId INT
        DECLARE @PairValid BIT
        DECLARE @DbServerName VARCHAR(100)
        
        DECLARE db_cursor CURSOR FOR
        SELECT AliasServer, DbServer, [Database], Environment, StandbyDatabases, IsActive, RowNum
        FROM @ImportData
        
        OPEN db_cursor
        FETCH NEXT FROM db_cursor INTO @AliasServer, @DbServer, @Database, @Environment, @StandbyDatabases, @IsActive, @RowNum
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @StandbyId = NULL
            SET @LocalErrCode = 0
            SET @LocalErrMsg = ''
            SET @AliasServerId = NULL
            SET @DbServerId = NULL
            SET @DatabaseId = NULL
            
            SELECT @AliasServerId = AliasServerId
            FROM [dbo].[SpmAliasServer] WITH (NOLOCK)
            WHERE [Name] = @AliasServer AND IsDeleted = 0
            
            SET @EnvironmentId = TRY_CAST(@Environment AS INT)
            
            SELECT @DbServerId = DbServerId
            FROM [dbo].[SpmAliasServerEnvironment] WITH (NOLOCK)
            WHERE AliasServerId = @AliasServerId AND EnvironmentId = @EnvironmentId
            
            SET @DbServerName = NULL
            SELECT @DbServerName = [Name]
            FROM [dbo].[SpmDbServer] WITH (NOLOCK)
            WHERE DbServerId = @DbServerId AND IsDeleted = 0
            
            IF @DbServerName IS NOT NULL AND @DbServerName <> @DbServer
            BEGIN
                SET @LocalErrMsg = 'The provided DB Server "' + @DbServer + '" does not match the DB Server associated with Alias Server "' + @AliasServer + '", which is "' + @DbServerName + '"'
                SET @HasErrors = 1
                
                INSERT INTO @Results (AliasServer, DbServer, [Database], Environment, StandbyDatabases, IsActive, Action, Message)
                VALUES (@AliasServer, @DbServer, @Database, @Environment, @StandbyDatabases, @IsActive, 'ERROR', @LocalErrMsg)
                
                SET @ErrorCount = @ErrorCount + 1
                
                FETCH NEXT FROM db_cursor INTO @AliasServer, @DbServer, @Database, @Environment, @StandbyDatabases, @IsActive, @RowNum
                CONTINUE
            END
            
            SELECT @DatabaseId = DatabaseId
            FROM [dbo].[SpmDatabase] WITH (NOLOCK)
            WHERE [Name] = @Database AND IsDeleted = 0
            
            IF @AliasServerId IS NULL OR @DbServerId IS NULL OR @DatabaseId IS NULL OR @EnvironmentId IS NULL
            BEGIN
                INSERT INTO @Results (AliasServer, DbServer, [Database], Environment, StandbyDatabases, IsActive, Action, Message)
                VALUES (@AliasServer, @DbServer, @Database, @Environment, @StandbyDatabases, @IsActive, 'ERROR', 
                       CASE 
                           WHEN @AliasServerId IS NULL THEN 'Alias Server not found.'
                           WHEN @EnvironmentId IS NULL THEN 'Environment not found.'
                           WHEN @DbServerId IS NULL THEN 'DB Server "' + @DbServer + '" is not set as an alias of the Alias Server "' + @AliasServer + '".'
                           WHEN @DatabaseId IS NULL THEN 'Database not found.'
                           ELSE 'Unknown error'
                       END)
                
                SET @ErrorCount = @ErrorCount + 1
                SET @HasErrors = 1
                
                FETCH NEXT FROM db_cursor INTO @AliasServer, @DbServer, @Database, @Environment, @StandbyDatabases, @IsActive, @RowNum
                CONTINUE
            END
            
            SELECT @StandbyId = s.StandbyId
            FROM [dbo].[SpmDatabaseStandby] s WITH (NOLOCK)
            WHERE s.AliasServerId = @AliasServerId 
              AND s.EnvironmentId = @EnvironmentId 
              AND s.DatabaseId = @DatabaseId
              AND s.IsDeleted = 0
            
            SET @StandbyDatabases = REPLACE(REPLACE(REPLACE(@StandbyDatabases, CHAR(13), ''), CHAR(10), ''), '  ', ' ')
            
            DELETE FROM @XmlData
            DELETE FROM @StandbyPairs
            
            SET @pos = 0
            SET @nextPos = 0
            SET @pairValue = NULL
            
            WHILE CHARINDEX(',', @StandbyDatabases, @pos + 1) > 0
            BEGIN
                SET @nextPos = CHARINDEX(',', @StandbyDatabases, @pos + 1)
                SET @pairValue = SUBSTRING(@StandbyDatabases, @pos + 1, @nextPos - @pos - 1)
                
                INSERT INTO @StandbyPairs (Pair)
                VALUES (LTRIM(RTRIM(@pairValue)))
                
                SET @pos = @nextPos
            END
            
            IF @pos < LEN(@StandbyDatabases)
            BEGIN
                SET @pairValue = SUBSTRING(@StandbyDatabases, @pos + 1, LEN(@StandbyDatabases) - @pos)
                
                INSERT INTO @StandbyPairs (Pair)
                VALUES (LTRIM(RTRIM(@pairValue)))
            END
            
            SET @Pair = NULL
            SET @StandbyDbServer = NULL
            SET @StandbyDatabase = NULL
            SET @StandbyDbServerId = NULL
            SET @StandbyDatabaseId = NULL
            SET @PairValid = 0
            
            DECLARE pair_cursor CURSOR FOR
            SELECT Pair FROM @StandbyPairs
            
            OPEN pair_cursor
            FETCH NEXT FROM pair_cursor INTO @Pair
            
            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @PairValid = 1
                SET @StandbyDbServerId = NULL
                SET @StandbyDatabaseId = NULL
                
                IF CHARINDEX('/', @Pair) > 0
                BEGIN
                    SET @StandbyDbServer = LTRIM(RTRIM(SUBSTRING(@Pair, 1, CHARINDEX('/', @Pair) - 1)))
                    SET @StandbyDatabase = LTRIM(RTRIM(SUBSTRING(@Pair, CHARINDEX('/', @Pair) + 1, LEN(@Pair))))
                    
                    SELECT @StandbyDbServerId = DbServerId
                    FROM [dbo].[SpmDbServer] WITH (NOLOCK)
                    WHERE [Name] = @StandbyDbServer AND IsDeleted = 0
                    
                    SELECT @StandbyDatabaseId = DatabaseId
                    FROM [dbo].[SpmDatabase] WITH (NOLOCK)
                    WHERE [Name] = @StandbyDatabase AND IsDeleted = 0
                    
                    IF @StandbyDbServerId IS NULL OR @StandbyDatabaseId IS NULL
                    BEGIN
                        SET @PairValid = 0
                        SET @LocalErrMsg = 'Invalid standby database pair: ' + @Pair + '. '
                        IF @StandbyDbServerId IS NULL
                            SET @LocalErrMsg = @LocalErrMsg + 'DB Server "' + @StandbyDbServer + '" not found. '
                        IF @StandbyDatabaseId IS NULL
                            SET @LocalErrMsg = @LocalErrMsg + 'Database "' + @StandbyDatabase + '" not found.'
                        
                        SET @HasErrors = 1
                    END
                    ELSE
                    BEGIN
                        INSERT INTO @XmlData (DbServerId, DatabaseId)
                        VALUES (@StandbyDbServerId, @StandbyDatabaseId)
                    END
                END
                ELSE
                BEGIN
                    SET @PairValid = 0
                    SET @LocalErrMsg = 'Invalid standby database format: ' + @Pair + '. Expected format: "DbServer/Database"'
                    SET @HasErrors = 1
                END
                
                FETCH NEXT FROM pair_cursor INTO @Pair
            END
            
            CLOSE pair_cursor
            DEALLOCATE pair_cursor
            
            SET @StandbyDbsXml = (
                SELECT 
                    DbServerId AS '@DbServerId',
                    DatabaseId AS '@DatabaseId'
                FROM @XmlData
                FOR XML PATH('StandbyDatabase'), ROOT('ROOT'), TYPE
            )
            
            IF @HasErrors = 1 AND @LocalErrMsg <> ''
            BEGIN
                INSERT INTO @Results (AliasServer, DbServer, [Database], Environment, StandbyDatabases, IsActive, Action, Message)
                VALUES (@AliasServer, @DbServer, @Database, @Environment, @StandbyDatabases, @IsActive, 'ERROR', @LocalErrMsg)
                
                SET @ErrorCount = @ErrorCount + 1
                
                FETCH NEXT FROM db_cursor INTO @AliasServer, @DbServer, @Database, @Environment, @StandbyDatabases, @IsActive, @RowNum
                CONTINUE
            END
            
            IF @StandbyId IS NOT NULL
            BEGIN
                EXEC [dbo].[SpmDatabaseStandby_Update]
                    @StandbyId = @StandbyId,
                    @AliasServerId = @AliasServerId,
                    @EnvironmentId = @EnvironmentId,
                    @DatabaseId = @DatabaseId,
                    @IsActive = @IsActive,
                    @ModifiedBy = @CreatedBy,
                    @StandbyDatabases = @StandbyDbsXml,
                    @ErrCode = @LocalErrCode OUTPUT,
                    @ErrMsg = @LocalErrMsg OUTPUT
                
                IF @LocalErrCode = 0
                BEGIN
                    INSERT INTO @Results (StandbyId, AliasServer, DbServer, [Database], Environment, StandbyDatabases, IsActive, Action, Message, IsSuccess)
                    VALUES (@StandbyId, @AliasServer, @DbServer, @Database, @Environment, @StandbyDatabases, @IsActive, 'UPDATE', 'Standby database configuration updated successfully', 1)
                    
                    SET @UpdateCount = @UpdateCount + 1
                END
                ELSE
                BEGIN
                    INSERT INTO @Results (StandbyId, AliasServer, DbServer, [Database], Environment, StandbyDatabases, IsActive, Action, Message)
                    VALUES (@StandbyId, @AliasServer, @DbServer, @Database, @Environment, @StandbyDatabases, @IsActive, 'ERROR', 
                           'Error updating standby database configuration: ' + ISNULL(@LocalErrMsg, 'Unknown error'))
                    
                    SET @ErrorCount = @ErrorCount + 1
                    SET @HasErrors = 1
                END
            END
            ELSE
            BEGIN
                EXEC [dbo].[SpmDatabaseStandby_Insert]
                    @AliasServerId = @AliasServerId,
                    @EnvironmentId = @EnvironmentId,
                    @DatabaseId = @DatabaseId,
                    @IsActive = @IsActive,
                    @CreatedBy = @CreatedBy,
                    @StandbyDatabases = @StandbyDbsXml,
                    @ErrCode = @LocalErrCode OUTPUT,
                    @ErrMsg = @LocalErrMsg OUTPUT
                
                IF @LocalErrCode = 0
                BEGIN
                    SELECT @StandbyId = StandbyId
                    FROM [dbo].[SpmDatabaseStandby] WITH (NOLOCK)
                    WHERE AliasServerId = @AliasServerId 
                      AND EnvironmentId = @EnvironmentId 
                      AND DatabaseId = @DatabaseId
                      AND IsDeleted = 0
                END
                
                IF @LocalErrCode = 0
                BEGIN
                    INSERT INTO @Results (StandbyId, AliasServer, DbServer, [Database], Environment, StandbyDatabases, IsActive, Action, Message, IsSuccess)
                    VALUES (@StandbyId, @AliasServer, @DbServer, @Database, @Environment, @StandbyDatabases, @IsActive, 'INSERT', 'Standby database configuration inserted successfully', 1)
                    
                    SET @InsertCount = @InsertCount + 1
                END
                ELSE
                BEGIN
                    INSERT INTO @Results (StandbyId, AliasServer, DbServer, [Database], Environment, StandbyDatabases, IsActive, Action, Message)
                    VALUES (NULL, @AliasServer, @DbServer, @Database, @Environment, @StandbyDatabases, @IsActive, 'ERROR', 
                           'Error inserting standby database configuration: ' + ISNULL(@LocalErrMsg, 'Unknown error'))
                    
                    SET @ErrorCount = @ErrorCount + 1
                    SET @HasErrors = 1
                END
            END
            
            DELETE FROM @StandbyPairs
            
            FETCH NEXT FROM db_cursor INTO @AliasServer, @DbServer, @Database, @Environment, @StandbyDatabases, @IsActive, @RowNum
        END
        
        CLOSE db_cursor
        DEALLOCATE db_cursor
        
        IF @HasErrors = 1
        BEGIN
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION
            
            SET @ErrCode = 3
            SET @ErrMsg = 'One or more errors occurred during import. No changes were made.'
        END
        ELSE
        BEGIN
            IF @@TRANCOUNT > 0
                COMMIT TRANSACTION
            
            SET @ErrCode = 0
            SET @ErrMsg = 'Successfully processed ' + CAST((@InsertCount + @UpdateCount) AS VARCHAR) + ' standby database configuration(s): ' + 
                          CAST(@InsertCount AS VARCHAR) + ' inserted, ' + CAST(@UpdateCount AS VARCHAR) + ' updated'
        END
        
        SELECT StandbyId, AliasServer, DbServer, [Database], Environment, StandbyDatabases, IsActive, Action, Message, IsSuccess
        FROM @Results
    END TRY
    BEGIN CATCH
        SET XACT_ABORT OFF
        
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION
            
        SET @ErrCode = ERROR_NUMBER()
        SET @ErrMsg = ERROR_MESSAGE()
        
        IF CURSOR_STATUS('local', 'db_cursor') >= 0
        BEGIN
            CLOSE db_cursor
            DEALLOCATE db_cursor
        END
        
        IF CURSOR_STATUS('local', 'pair_cursor') >= 0
        BEGIN
            CLOSE pair_cursor
            DEALLOCATE pair_cursor
        END
        
        INSERT INTO @Results (StandbyId, AliasServer, DbServer, [Database], Environment, StandbyDatabases, IsActive, Action, Message)
        VALUES (NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'ERROR', 'Unexpected error: ' + ERROR_MESSAGE())
        
        SELECT StandbyId, AliasServer, DbServer, [Database], Environment, StandbyDatabases, IsActive, Action, Message, IsSuccess
        FROM @Results
    END CATCH
END
