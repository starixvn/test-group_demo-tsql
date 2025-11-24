
CREATE PROCEDURE [dbo].[SpmAliasServer_ImportData]
        @AliasServerData [dbo].[AliasServerTableType] READONLY, -- Table-valued parameter with XML for DbServerEnvironments
    @CreatedBy INT,
    @ErrCode INT = 0 OUTPUT,
    @ErrMsg NVARCHAR(MAX) = '' OUTPUT
AS
    /*
    Created: 20250827@Alex.Tran
    Task: Import multiple alias servers from Excel
    DB: SPM
    Original: Reuses SpmAliasServer_Insert

    Param's Explanation:
    - @AliasServerData: Table-valued parameter containing alias server information
    - @CreatedBy: User ID who is importing the data
    */
BEGIN
    SET NOCOUNT ON;

        -- Create a temporary table to store the import data
    DECLARE @ImportData TABLE (
        Name VARCHAR(50),
        DatabaseNames VARCHAR(2000),
        DbServerEnvironments XML,
        NotDeployFor VARCHAR(MAX),
        Description NVARCHAR(200),
        IsActive BIT,
        RowNum INT IDENTITY(1,1)
        )

        -- Create a result table to store operation results
    DECLARE @Results TABLE (
        AliasServerId INT,
        Name VARCHAR(50),
        DatabaseNames VARCHAR(2000),
        DbServerEnvironments XML,
        NotDeployFor VARCHAR(MAX),
        Description NVARCHAR(200),
        IsActive BIT,
        Action VARCHAR(10), -- 'INSERT', 'UPDATE', or 'ERROR'
        Message NVARCHAR(2000),
        IsSuccess BIT DEFAULT 0
        )
        
        -- Copy data from TVP to our temp table
        INSERT INTO @ImportData (
            Name, 
            DatabaseNames, 
            DbServerEnvironments,
            NotDeployFor, 
            Description, 
            IsActive
        )
        SELECT 
            Name,
            DatabaseNames,
            DbServerEnvironments,
            NotDeployFor,
            Description,
            IsActive
        FROM @AliasServerData
        
        -- Check if we have any data to process
        IF NOT EXISTS (SELECT 1 FROM @ImportData)
    BEGIN
            SET @ErrCode = 1
            SET @ErrMsg = 'No data provided for import'

            -- Return empty result set
            SELECT 
                CAST(NULL AS INT) AS AliasServerId,
               CAST(NULL AS VARCHAR(50)) AS Name,
               CAST(NULL AS VARCHAR(2000)) AS DatabaseNames,
               CAST(NULL AS NVARCHAR(200)) AS Description,
               CAST(NULL AS BIT) AS IsActive,
               'ERROR' AS Action,
               'No data provided for import' AS Message,
               CAST(0 AS BIT) AS IsSuccess
            WHERE 1 = 0
            
            RETURN
        END
        
        -- Validate data - check for empty required fields
        INSERT INTO @Results (Name, DatabaseNames, DbServerEnvironments, NotDeployFor, Description, IsActive, Action, Message)
        SELECT Name, DatabaseNames, DbServerEnvironments, NotDeployFor, Description, IsActive, 'ERROR', 'Alias Server Name is required'
    FROM @ImportData
        WHERE Name IS NULL OR Name = ''

        IF EXISTS (SELECT 1 FROM @Results WHERE Action = 'ERROR')
    BEGIN
            SET @ErrCode = 1
            SET @ErrMsg = 'One or more required fields are empty'

            -- Return the results
        SELECT AliasServerId, Name, DatabaseNames, DbServerEnvironments,
               NotDeployFor, Description, IsActive,
               Action, Message, IsSuccess
            FROM @Results
            
            RETURN
        END
        
        -- Begin transaction for all operations
        BEGIN TRY
            BEGIN TRANSACTION
            
            -- Variables for tracking statistics
            DECLARE @InsertCount INT = 0
            DECLARE @UpdateCount INT = 0
            DECLARE @ErrorCount INT = 0
            
            -- Process each alias server in the import data
            DECLARE @Name VARCHAR(50)
            DECLARE @DatabaseNames VARCHAR(2000)
            DECLARE @DbServerEnvironments XML
            DECLARE @NotDeployFor VARCHAR(MAX)
            DECLARE @Description NVARCHAR(200)
            DECLARE @IsActive BIT
            DECLARE @RowNum INT
            DECLARE @AliasServerId INT
            DECLARE @LocalErrCode INT
            DECLARE @LocalErrMsg NVARCHAR(200)
            DECLARE @HasErrors BIT = 0
            
            -- Variables for database operations
            DECLARE @DatabaseIds VARCHAR(2000)
            DECLARE @Data NVARCHAR(MAX)
            DECLARE @OldData NVARCHAR(MAX)
            
            -- Variables for error tracking
            DECLARE @MissingDatabases NVARCHAR(1000) = ''
            DECLARE @MissingServers NVARCHAR(1000) = ''
            DECLARE @InvalidEnvironments NVARCHAR(1000) = ''
            DECLARE @MissingItems NVARCHAR(1000) = ''
            DECLARE @NotInDatabaseIds NVARCHAR(1000) = ''
            DECLARE @ErrorMessage NVARCHAR(2000) = ''
            DECLARE @CurrentEnv VARCHAR(20)
            DECLARE @CurrentServer VARCHAR(100)
            DECLARE @EnvServers NVARCHAR(1000)
            
                    -- Table variables
        DECLARE @ServerValidation TABLE (
            Status VARCHAR(10),
            DbServerId INT,
            EnvironmentId INT,
            EnvironmentName VARCHAR(20),
            DbServerName VARCHAR(100)
        )
        
        DECLARE @DatabaseIdTable TABLE (DatabaseId INT)
        
        DECLARE @NoDeployTable TABLE (
            DatabaseId INT,
            EnvironmentId INT
        )
        
        DECLARE @SplitPairs TABLE (
            RowNum INT IDENTITY(1,1), 
            Value NVARCHAR(200)
        )
        
        DECLARE @SplitDatabaseNames TABLE (
            RowNum INT IDENTITY(1,1), 
            Value NVARCHAR(100)
        )
        
        DECLARE @Pair VARCHAR(200)
        DECLARE @DatabaseName VARCHAR(100)
        DECLARE @EnvironmentName VARCHAR(100)
        DECLARE @DatabaseId INT
        DECLARE @EnvironmentId INT
        DECLARE @pairPos INT
        DECLARE @pairNextPos INT
        DECLARE @pairValue NVARCHAR(200)
        DECLARE @dbPos INT
        DECLARE @dbNextPos INT
        DECLARE @dbValue NVARCHAR(100)
        DECLARE @DbNameIndex INT
        DECLARE @DbNameCount INT
        DECLARE @DbName VARCHAR(100)
            
            DECLARE alias_cursor CURSOR FOR
            SELECT 
                Name, 
                DatabaseNames, 
                DbServerEnvironments,
                NotDeployFor, 
                Description, 
                IsActive, 
                RowNum
            FROM @ImportData
            
            OPEN alias_cursor
        FETCH NEXT FROM alias_cursor INTO
                @Name, 
                @DatabaseNames, 
                @DbServerEnvironments,
                @NotDeployFor, 
                @Description, 
                @IsActive, 
                @RowNum

        WHILE @@FETCH_STATUS = 0
        BEGIN
                -- Reset all variables for this row
                SET @AliasServerId = NULL
                SET @LocalErrCode = 0
                SET @LocalErrMsg = ''
                SET @DatabaseIds = NULL
                SET @MissingDatabases = ''
                SET @MissingServers = ''
                SET @InvalidEnvironments = ''
                SET @MissingItems = ''
                SET @NotInDatabaseIds = ''
                SET @ErrorMessage = ''
                SET @Data = NULL
                SET @OldData = NULL
                
                -- Clear temporary tables
                DELETE FROM @ServerValidation
                DELETE FROM @DatabaseIdTable
                DELETE FROM @NoDeployTable
                
                -- Check if the alias server already exists
                DECLARE @ExistingAliasServerId INT = NULL
                
                SELECT @ExistingAliasServerId = AliasServerId
                    FROM [dbo].[SpmAliasServer] WITH (NOLOCK)
                WHERE [Name] = @Name AND IsDeleted = 0
                
            IF @DatabaseNames IS NOT NULL AND LEN(@DatabaseNames) > 0
            BEGIN
                    DELETE FROM @SplitDatabaseNames
                    
                    INSERT INTO @SplitDatabaseNames (Value)
                    SELECT DISTINCT val FROM dbo.fnc_strSplit(@DatabaseNames, ',')
                    
                    SELECT @MissingDatabases = ''
                    
                    SELECT @MissingDatabases = @MissingDatabases + 
                        CASE WHEN @MissingDatabases = '' THEN '' ELSE ', ' END + s.Value
                    FROM @SplitDatabaseNames s
                    WHERE NOT EXISTS (
                        SELECT 1 
                        FROM [dbo].[SpmDatabase] 
                        WHERE [Name] = s.Value 
                        AND IsDeleted = 0
                    )
                    ORDER BY s.RowNum
                    
                    -- If any databases are missing, add an error
                IF LEN(@MissingDatabases) > 0
                BEGIN
                    -- Add error to results
                        INSERT INTO @Results (Name, DatabaseNames, DbServerEnvironments, NotDeployFor, Description, IsActive, Action, Message)
                        VALUES (@Name, @DatabaseNames, @DbServerEnvironments, @NotDeployFor, @Description, @IsActive, 'ERROR', 
                            'The following databases do not exist: ' + @MissingDatabases)
                        
                        SET @ErrorCount = @ErrorCount + 1
                        SET @HasErrors = 1

                    FETCH NEXT FROM alias_cursor INTO
                            @Name, 
                            @DatabaseNames, 
                            @DbServerEnvironments, 
                            @NotDeployFor, 
                            @Description, 
                            @IsActive, 
                            @RowNum
                        CONTINUE
                    END
                    
                    -- Get database IDs for the provided database names
                    -- Use the already populated @SplitDatabaseNames table
                    SELECT @DatabaseIds = COALESCE(@DatabaseIds + ',', '') + CAST(DatabaseId AS VARCHAR(10))
                    FROM [dbo].[SpmDatabase] WITH (NOLOCK)
                    WHERE [Name] IN (
                        SELECT Value FROM @SplitDatabaseNames
                    )
                    AND IsDeleted = 0
                END
                
                -- Variables to track missing servers or invalid environment relationships
                SET @MissingServers = ''
                SET @InvalidEnvironments = ''
                
                -- Clear the validation table
                DELETE FROM @ServerValidation
                
                -- Process XML data for environment DB servers
                IF @DbServerEnvironments IS NOT NULL
                BEGIN
                    DECLARE @DocHandler INT
                    
                    -- Prepare XML document
                    EXEC sp_xml_preparedocument @DocHandler OUTPUT, @DbServerEnvironments
                    
                    -- Insert server validations from XML data
                    INSERT INTO @ServerValidation (Status, DbServerId, EnvironmentId, EnvironmentName, DbServerName)
                    SELECT 
                        v.Status,
                        v.DbServerId,
                        e.EnvironmentId,
                        e.EnvironmentName,
                        v.DbServerName
                    FROM OPENXML(@DocHandler, '/ROOT/DbServer', 1) 
                    WITH (
                        DbServerName VARCHAR(100),
                        EnvironmentId INT
                    ) AS xml
                    CROSS APPLY (
                        SELECT 
                            ld.Name AS EnvironmentName,
                            xml.EnvironmentId
                        FROM [dbo].[LookupData] ld
                        INNER JOIN [dbo].[Lookup] l ON ld.LookupId = l.Id
                        WHERE l.Code = 'Environment'
                        AND ld.Id = xml.EnvironmentId
                    ) AS e
                    CROSS APPLY (
                        SELECT 
                            Status,
                            DbServerId,
                            DbServerName
                        FROM [dbo].[fncValidateDbServerForEnvironment](
                            xml.DbServerName,
                            xml.EnvironmentId
                        )
                    ) AS v
                    
                    -- Clean up XML document
                    EXEC sp_xml_removedocument @DocHandler
                END
                
                -- Process missing servers with environment in parentheses
                SET @MissingServers = ''
                
                -- Create a cursor to process missing servers
                DECLARE missing_srv_cursor CURSOR FOR
                SELECT DbServerName, EnvironmentName
                FROM @ServerValidation 
                WHERE Status = 'NOT FOUND'
                ORDER BY DbServerName
                
                OPEN missing_srv_cursor
                FETCH NEXT FROM missing_srv_cursor INTO @CurrentServer, @CurrentEnv
                
                WHILE @@FETCH_STATUS = 0
                BEGIN
                    -- Add comma if not the first server
                    IF LEN(@MissingServers) > 0
                        SET @MissingServers = @MissingServers + ', '
                        
                    -- Format as ServerName(Environment)
                    SET @MissingServers = @MissingServers + @CurrentServer + '(' + @CurrentEnv + ')'
                    
                    FETCH NEXT FROM missing_srv_cursor INTO @CurrentServer, @CurrentEnv
                END
                
                CLOSE missing_srv_cursor
                DEALLOCATE missing_srv_cursor
                
                -- Process invalid servers with environment in parentheses
                SET @InvalidEnvironments = ''
                
                -- Create a cursor to process invalid servers
                DECLARE invalid_srv_cursor CURSOR FOR
                SELECT DbServerName, EnvironmentName
                FROM @ServerValidation 
                WHERE Status = 'INVALID'
                ORDER BY DbServerName
                
                OPEN invalid_srv_cursor
                FETCH NEXT FROM invalid_srv_cursor INTO @CurrentServer, @CurrentEnv
                
                WHILE @@FETCH_STATUS = 0
                BEGIN
                    -- Add comma if not the first server
                    IF LEN(@InvalidEnvironments) > 0
                        SET @InvalidEnvironments = @InvalidEnvironments + ', '
                        
                    -- Format as ServerName(Environment)
                    SET @InvalidEnvironments = @InvalidEnvironments + @CurrentServer + '(' + @CurrentEnv + ')'
                    
                    FETCH NEXT FROM invalid_srv_cursor INTO @CurrentServer, @CurrentEnv
                END
                
                CLOSE invalid_srv_cursor
                DEALLOCATE invalid_srv_cursor
                
                -- Check if any servers were missing or invalid for their environments
                IF LEN(@MissingServers) > 0 OR LEN(@InvalidEnvironments) > 0
            BEGIN
                    SET @ErrorMessage = ''
                    
                    IF LEN(@MissingServers) > 0
                        SET @ErrorMessage = 'The following DB servers do not exist: ' + @MissingServers
                        
                    IF LEN(@InvalidEnvironments) > 0
                BEGIN
                        IF LEN(@ErrorMessage) > 0
                            SET @ErrorMessage = @ErrorMessage + '. '
                            
                        SET @ErrorMessage = @ErrorMessage + 'The following DB servers are not valid for their environments: ' + @InvalidEnvironments
                    END
                    
                    -- Add error to results
                    INSERT INTO @Results (Name, DatabaseNames, DbServerEnvironments, NotDeployFor, Description, IsActive, Action, Message)
                    VALUES (@Name, @DatabaseNames, @DbServerEnvironments, @NotDeployFor, @Description, @IsActive, 'ERROR', @ErrorMessage)
                    
                    SET @ErrorCount = @ErrorCount + 1
                    SET @HasErrors = 1

                FETCH NEXT FROM alias_cursor INTO
                        @Name, 
                        @DatabaseNames, 
                        @DbServerEnvironments,
                        @NotDeployFor, 
                        @Description, 
                        @IsActive, 
                        @RowNum
                    CONTINUE
                END
                
                -- Variables to track missing databases, environments, or databases not in DatabaseIds
                SET @MissingItems = ''
                SET @NotInDatabaseIds = ''
                
                -- Clear the database ID table
                DELETE FROM @DatabaseIdTable
                
                -- Clear the no-deploy table
                DELETE FROM @NoDeployTable
                
                -- Parse @DatabaseIds into the table
            IF @DatabaseIds IS NOT NULL AND LEN(@DatabaseIds) > 0
            BEGIN
                    -- Use fnc_strSplit function for database IDs
                    INSERT INTO @DatabaseIdTable (DatabaseId)
                    SELECT CAST(val AS INT) 
                    FROM dbo.fnc_strSplit(@DatabaseIds, ',')
                    WHERE ISNUMERIC(val) = 1
            END

            IF @NotDeployFor IS NOT NULL AND LEN(@NotDeployFor) > 0
            BEGIN
                    -- Clear and populate the split pairs table once
                    DELETE FROM @SplitPairs
                    
                    -- Use fnc_strSplit function for pairs
                    INSERT INTO @SplitPairs (Value)
                    SELECT DISTINCT val FROM dbo.fnc_strSplit(@NotDeployFor, ',')
                    
                    DECLARE @PairIndex INT = 1
                    DECLARE @PairCount INT = (SELECT COUNT(*) FROM @SplitPairs)
                    -- Reset variables for NotDeployFor processing
                    SET @Pair = NULL
                    SET @DatabaseName = NULL
                    SET @EnvironmentName = NULL
                    SET @DatabaseId = NULL
                    SET @EnvironmentId = NULL

                WHILE @PairIndex <= @PairCount
                BEGIN
                        SELECT @Pair = Value FROM @SplitPairs WHERE RowNum = @PairIndex
                        
                        -- Split the pair into database name and environment name
                    IF @Pair LIKE '%/%'
                    BEGIN
                            SET @DatabaseName = LTRIM(RTRIM(SUBSTRING(@Pair, 1, CHARINDEX('/', @Pair) - 1)))
                            SET @EnvironmentName = LTRIM(RTRIM(SUBSTRING(@Pair, CHARINDEX('/', @Pair) + 1, LEN(@Pair))))
                            
                            -- Look up the database ID
                            SELECT @DatabaseId = DatabaseId 
                            FROM [dbo].[SpmDatabase] 
                            WHERE [Name] = @DatabaseName AND IsDeleted = 0
                            
                            -- Look up the environment ID
                            -- Get environment ID from LookupData table
                        SELECT @EnvironmentId = ld.Id
                            FROM [dbo].[LookupData] ld
                            INNER JOIN [dbo].[Lookup] l ON ld.LookupId = l.Id
                            WHERE l.Code = 'Environment'
                            AND ld.Name = @EnvironmentName
                            
                            -- Check if both IDs are found
                        IF @DatabaseId IS NOT NULL AND @EnvironmentId IS NOT NULL
                        BEGIN
                                -- Check if the database ID is in the DatabaseIds list
                                IF EXISTS (SELECT 1 FROM @DatabaseIdTable WHERE DatabaseId = @DatabaseId)
                                BEGIN
                                    -- Add to NoDeployTable
                                    INSERT INTO @NoDeployTable (DatabaseId, EnvironmentId)
                                    VALUES (@DatabaseId, @EnvironmentId)
                                END
                                ELSE
                                BEGIN
                                    -- Track databases not in DatabaseIds
                                    SET @NotInDatabaseIds = @NotInDatabaseIds + CASE WHEN LEN(@NotInDatabaseIds) > 0 THEN ', ' ELSE '' END + @DatabaseName
                                END
                        END
                        ELSE
                        BEGIN
                                -- Track missing items
                                IF @DatabaseId IS NULL
                                    SET @MissingItems = @MissingItems + CASE WHEN LEN(@MissingItems) > 0 THEN ', ' ELSE '' END + 'Database: ' + @DatabaseName
                                IF @EnvironmentId IS NULL
                                    SET @MissingItems = @MissingItems + CASE WHEN LEN(@MissingItems) > 0 THEN ', ' ELSE '' END + 'Environment: ' + @EnvironmentName
                        END
                    END

                        SET @PairIndex = @PairIndex + 1
                END
            END

                -- NoDeployTable now contains all valid no-deploy database/environment pairs

                -- Check if any databases or environments were missing
                IF LEN(@MissingItems) > 0 OR LEN(@NotInDatabaseIds) > 0
            BEGIN
                    SET @ErrorMessage = ''
                    
                    IF LEN(@MissingItems) > 0
                        SET @ErrorMessage = 'The following items do not exist: ' + @MissingItems
                        
                    IF LEN(@NotInDatabaseIds) > 0
                BEGIN
                        IF LEN(@ErrorMessage) > 0
                            SET @ErrorMessage = @ErrorMessage + '. '
                            
                        SET @ErrorMessage = @ErrorMessage + 'The following databases in NotDeployFor are not in DatabaseNames: ' + @NotInDatabaseIds
                    END
                    
                    -- Add error to results
                    INSERT INTO @Results (Name, DatabaseNames, DbServerEnvironments, NotDeployFor, Description, IsActive, Action, Message)
                    VALUES (@Name, @DatabaseNames, @DbServerEnvironments, @NotDeployFor, @Description, @IsActive, 'ERROR', @ErrorMessage)
                    
                    SET @ErrorCount = @ErrorCount + 1
                    SET @HasErrors = 1

                FETCH NEXT FROM alias_cursor INTO
                        @Name, 
                        @DatabaseNames, 
                        @DbServerEnvironments,
                        @NotDeployFor, 
                        @Description, 
                        @IsActive, 
                        @RowNum
                    CONTINUE
                END
                
                -- Insert or update the alias server
            IF @ExistingAliasServerId IS NULL
            BEGIN
                    -- Insert validation - check if name already exists
                    IF EXISTS (SELECT 1
                        FROM [dbo].[SpmAliasServer] WITH (NOLOCK)
                        WHERE [Name] = @Name AND IsDeleted = 0)
                    BEGIN
                        SET @LocalErrCode = 100
                        SET @LocalErrMsg = 'Alias Server ''' + @Name + ''' has already existed. Please try again.'
                        
                        -- Add to results with error
                        INSERT INTO @Results (AliasServerId, Name, DatabaseNames, DbServerEnvironments, NotDeployFor, Description, IsActive, Action, Message)
                        VALUES (NULL, @Name, @DatabaseNames, @DbServerEnvironments, @NotDeployFor, @Description, @IsActive, 'ERROR', 
                            'Error inserting Alias Server: ' + @LocalErrMsg)
                        
                        SET @ErrorCount = @ErrorCount + 1
                        SET @HasErrors = 1
                        
                        FETCH NEXT FROM alias_cursor INTO 
                            @Name, 
                            @DatabaseNames, 
                            @DbServerEnvironments, 
                            @NotDeployFor, 
                            @Description, 
                            @IsActive, 
                            @RowNum
                        CONTINUE
                    END
                    
                    -- Insert the new alias server
                    SET @Data = NULL
                    
                    INSERT INTO [dbo].[SpmAliasServer]
                        ([Name]
                        ,[Description]
                        ,[IsActive]
                        ,[ModifiedBy]
                        ,[ModifiedDate])	
                    VALUES (
                        @Name
                        ,@Description
                        ,@IsActive
                        ,@CreatedBy
                        ,GETDATE())		
                
                    SELECT @AliasServerId = CAST(SCOPE_IDENTITY() AS INT)		
                    
                    IF ISNULL(@DatabaseIds,'') <> ''
                BEGIN
                        INSERT INTO [dbo].[SpmAliasServerDatabase]
                            ([AliasServerId]
                            ,[DatabaseId])
                        SELECT DISTINCT
                            @AliasServerId
                            ,val
                        FROM fnc_strSplit (@DatabaseIds, ',')
                    END
                
                    -- Insert server environments directly from our validation table
                    INSERT INTO [dbo].[SpmAliasServerEnvironment] (
                        [AliasServerId]
                        ,[EnvironmentId]
                        ,[DbServerId])
                    SELECT DISTINCT
                        @AliasServerId
                        ,EnvironmentId
                        ,DbServerId
                    FROM @ServerValidation
                    WHERE Status = 'VALID'

                    -- Insert no-deploy databases directly from our table
                    INSERT INTO dbo.SpmAliasServerNoDeployment
                    (
                        AliasServerId,
                        DatabaseId,
                        EnvironmentId
                    )
                    SELECT DISTINCT
                        @AliasServerId
                        ,DatabaseId
                        ,EnvironmentId
                    FROM @NoDeployTable

                    -- Log the insert operation
                    EXEC @Data = [dbo].[fncGetDataForWriteLog] @ObjectId = @AliasServerId, @ObjectType = 4
                    EXEC dbo.SpmLog_Insert @UserId = @CreatedBy, @SpName = 'SpmAliasServer_ImportData', @ObjectId = @AliasServerId, @ObjectTypeId = 4, @Data = @Data, @OldData = NULL
                    
                    -- Add to results
                    INSERT INTO @Results (AliasServerId, Name, DatabaseNames, DbServerEnvironments, NotDeployFor, Description, IsActive, Action, Message, IsSuccess)
                    VALUES (@AliasServerId, @Name, @DatabaseNames, @DbServerEnvironments, @NotDeployFor, @Description, @IsActive, 'INSERT', 'Alias Server inserted successfully', 1)
                    
                    SET @InsertCount = @InsertCount + 1
                END
                ELSE
                BEGIN
                    -- Update validation - check if another record with same name exists
                    IF EXISTS(SELECT 1
                        FROM [dbo].[SpmAliasServer] WITH (NOLOCK)
                        WHERE [AliasServerId] <> @ExistingAliasServerId AND [Name] = @Name AND IsDeleted = 0)
                    BEGIN
                        SET @LocalErrCode = 100
                        SET @LocalErrMsg = 'Alias Server ''' + @Name + ''' has already existed. Please try again.'
                        
                        -- Add to results with error
                        INSERT INTO @Results (AliasServerId, Name, DatabaseNames, DbServerEnvironments, NotDeployFor, Description, IsActive, Action, Message)
                        VALUES (@ExistingAliasServerId, @Name, @DatabaseNames, @DbServerEnvironments, @NotDeployFor, @Description, @IsActive, 'ERROR', 
                            'Error updating Alias Server: ' + @LocalErrMsg)
                        
                        SET @ErrorCount = @ErrorCount + 1
                        SET @HasErrors = 1
                        
                        FETCH NEXT FROM alias_cursor INTO 
                            @Name, 
                            @DatabaseNames, 
                            @DbServerEnvironments, 
                            @NotDeployFor, 
                            @Description, 
                            @IsActive, 
                            @RowNum
                        CONTINUE
                    END
                    
                    -- Check if we can deactivate
                    IF @IsActive = 0 AND EXISTS(SELECT 1
                        FROM [dbo].[SpmStoredProcedure] AS st WITH (NOLOCK)
                        WHERE st.AliasServerId = @ExistingAliasServerId
                            AND st.[IsDeleted] = 0
                            AND st.IsActive = 1)
                    BEGIN
                        SET @LocalErrCode = 100
                        SET @LocalErrMsg = 'You can not deactivate this Alias because it is being used by one or more Stored Procedure.'
                        
                        -- Add to results with error
                        INSERT INTO @Results (AliasServerId, Name, DatabaseNames, DbServerEnvironments, NotDeployFor, Description, IsActive, Action, Message)
                        VALUES (@ExistingAliasServerId, @Name, @DatabaseNames, @DbServerEnvironments, @NotDeployFor, @Description, @IsActive, 'ERROR', 
                            'Error updating Alias Server: ' + @LocalErrMsg)
                        
                        SET @ErrorCount = @ErrorCount + 1
                        SET @HasErrors = 1
                        
                        FETCH NEXT FROM alias_cursor INTO 
                            @Name, 
                            @DatabaseNames, 
                            @DbServerEnvironments, 
                            @NotDeployFor, 
                            @Description, 
                            @IsActive, 
                            @RowNum
                        CONTINUE
                    END
                    
                    -- Create temporary tables for validation
                    DECLARE @TempDatabase TABLE (DatabaseId SMALLINT)
                    IF ISNULL(@DatabaseIds,'') <> ''
            BEGIN
                        INSERT INTO @TempDatabase(DatabaseId)
                        SELECT DISTINCT val FROM fnc_strSplit (@DatabaseIds, ',')
                    END	
                    
                    -- We already have the valid DB servers in @ServerValidation
                    
                    -- Check if we can activate
                    IF (@IsActive = 1 AND (EXISTS (SELECT 1
                            FROM [dbo].[SpmDbServer] AS sv WITH (NOLOCK)
                            INNER JOIN @ServerValidation AS tmpsv ON sv.DbServerId = tmpsv.DbServerId
                            WHERE sv.IsActive = 0 AND tmpsv.Status = 'VALID')
                        OR EXISTS (SELECT 1 FROM [dbo].[SpmDatabase] AS db WITH (NOLOCK)
                            INNER JOIN @TempDatabase AS tmpdb ON db.DatabaseId = tmpdb.DatabaseId
                            WHERE db.IsActive = 0)))
                BEGIN
                        SET @LocalErrCode = 100
                        SET @LocalErrMsg = 'You can not activate this Alias because DB Server or Database are been deactivate.'
                        
                        -- Add to results with error
                        INSERT INTO @Results (AliasServerId, Name, DatabaseNames, DbServerEnvironments, NotDeployFor, Description, IsActive, Action, Message)
                        VALUES (@ExistingAliasServerId, @Name, @DatabaseNames, @DbServerEnvironments, @NotDeployFor, @Description, @IsActive, 'ERROR', 
                            'Error updating Alias Server: ' + @LocalErrMsg)
                        
                        SET @ErrorCount = @ErrorCount + 1
                        SET @HasErrors = 1
                        
                        FETCH NEXT FROM alias_cursor INTO 
                            @Name, 
                            @DatabaseNames, 
                            @DbServerEnvironments, 
                            @NotDeployFor, 
                            @Description, 
                            @IsActive, 
                            @RowNum
                        CONTINUE
                    END
                    
                    -- Get old data for logging
                    SET @OldData = NULL
                    EXEC @OldData = [dbo].[fncGetDataForWriteLog] @ObjectId = @ExistingAliasServerId, @ObjectType = 4
                    
                    -- Update the alias server
                    UPDATE [dbo].[SpmAliasServer] WITH (ROWLOCK,UPDLOCK)
                    SET [Name] = @Name
                        ,[Description] = @Description
                        ,[IsActive] = @IsActive
                        ,[ModifiedBy] = @CreatedBy
                        ,[ModifiedDate] = GETDATE()
                    WHERE [AliasServerId] = @ExistingAliasServerId	

                    -- Update related tables
                    DELETE FROM [dbo].[SpmAliasServerDatabase] WHERE [AliasServerId] = @ExistingAliasServerId 		
                
                    INSERT INTO [dbo].[SpmAliasServerDatabase]
                        ([AliasServerId]
                        ,[DatabaseId])
                    SELECT DISTINCT
                        @ExistingAliasServerId
                        ,[DatabaseId]
                    FROM @TempDatabase AS db        
                    
                    DELETE FROM [dbo].[SpmAliasServerEnvironment] WHERE [AliasServerId] = @ExistingAliasServerId

                    -- Insert server environments directly from our validation table
                    INSERT INTO [dbo].[SpmAliasServerEnvironment] (
                        [AliasServerId]
                        ,[EnvironmentId]
                        ,[DbServerId])
                    SELECT DISTINCT
                        @ExistingAliasServerId
                        ,EnvironmentId
                        ,DbServerId
                    FROM @ServerValidation
                    WHERE Status = 'VALID'

                    DELETE dbo.SpmAliasServerNoDeployment WHERE [AliasServerId] = @ExistingAliasServerId	

                    -- Insert no-deploy databases directly from our table
                    INSERT INTO dbo.SpmAliasServerNoDeployment
                    (
                        AliasServerId,
                        DatabaseId,
                        EnvironmentId
                    )
                    SELECT DISTINCT
                        @ExistingAliasServerId
                        ,DatabaseId
                        ,EnvironmentId
                    FROM @NoDeployTable

                    -- Log the update operation
                    EXEC @Data = [dbo].[fncGetDataForWriteLog] @ObjectId = @ExistingAliasServerId, @ObjectType = 4
                    EXEC dbo.SpmLog_Insert @UserId = @CreatedBy, @SpName = 'SpmAliasServer_ImportData', @ObjectId = @ExistingAliasServerId, @ObjectTypeId = 4, @Data = @Data, @OldData = @OldData
                    
                    -- Add to results
                    INSERT INTO @Results (AliasServerId, Name, DatabaseNames, DbServerEnvironments, NotDeployFor, Description, IsActive, Action, Message, IsSuccess)
                    VALUES (@ExistingAliasServerId, @Name, @DatabaseNames, @DbServerEnvironments, @NotDeployFor, @Description, @IsActive, 'UPDATE', 'Alias Server updated successfully', 1)
                    
                    SET @UpdateCount = @UpdateCount + 1
            END

            FETCH NEXT FROM alias_cursor INTO
                    @Name, 
                    @DatabaseNames, 
                    @DbServerEnvironments, 
                    @NotDeployFor, 
                    @Description, 
                    @IsActive, 
                    @RowNum
            END
            
            CLOSE alias_cursor
            DEALLOCATE alias_cursor
            
            -- Check if we had any errors
        IF @HasErrors = 1
        BEGIN
                -- Roll back the transaction
                IF @@TRANCOUNT > 0
                    ROLLBACK TRANSACTION

                SET @ErrCode = 3
                SET @ErrMsg = 'One or more errors occurred during import. No changes were made.'
        END
        ELSE
        BEGIN
                -- Commit the transaction
                IF @@TRANCOUNT > 0
                    COMMIT TRANSACTION

                SET @ErrCode = 0
                SET @ErrMsg = 'Successfully imported ' + CAST(@InsertCount AS VARCHAR) + ' and updated ' + CAST(@UpdateCount AS VARCHAR) + ' Alias Server(s)'
        END

            -- Return the results
        SELECT AliasServerId, Name, DatabaseNames, DbServerEnvironments,
               NotDeployFor, Description, IsActive,
               Action, Message, IsSuccess
        FROM @Results
    END TRY
    BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION
                
            SET @ErrCode = ERROR_NUMBER()
            SET @ErrMsg = ERROR_MESSAGE()
            
            -- Clean up cursor if still open
        IF CURSOR_STATUS('local', 'alias_cursor') >= 0
        BEGIN
                CLOSE alias_cursor
                DEALLOCATE alias_cursor
            END
            
            -- Add error to results
            INSERT INTO @Results (AliasServerId, Name, DatabaseNames, DbServerEnvironments, NotDeployFor, Description, IsActive, Action, Message)
            VALUES (NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'ERROR', 'Unexpected error: ' + ERROR_MESSAGE())
            
            -- Return the results
        SELECT AliasServerId, Name, DatabaseNames, DbServerEnvironments,
               NotDeployFor, Description, IsActive,
               Action, Message, IsSuccess
            FROM @Results
    END CATCH
END