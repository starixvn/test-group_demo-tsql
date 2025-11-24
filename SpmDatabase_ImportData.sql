CREATE PROCEDURE [dbo].[SpmDatabase_ImportData]
    @DatabasesData [dbo].[DatabaseTableType] READONLY, -- Table-valued parameter
    @CreatedBy INT,
    @ErrCode INT = 0 OUTPUT,
    @ErrMsg NVARCHAR(MAX) = '' OUTPUT
AS
/*
Created: 20250827@Alex.Tran
Task: Import multiple databases from Excel
DB: SPM
Original: Reuses SpmDatabase_Insert and SpmDatabase_Update

Revisions:  
- Added result set with action and error message for each record
- Modified to process all records before committing
- Added rollback if any error occurs

Param's Explanation:
- @DatabasesData: Table-valued parameter containing database information
- @CreatedBy: User ID who is importing the data
*/
BEGIN
    SET NOCOUNT ON;
    
    -- Create a temporary table to store the import data
    DECLARE @ImportData TABLE (
        Name VARCHAR(100),
        Description NVARCHAR(2000),
        ExecutionUser VARCHAR(100),
        IsActive BIT,
        RowNum INT IDENTITY(1,1)
    )
    
    -- Create a result table to store operation results
    DECLARE @Results TABLE (
        DatabaseId INT,
        Name VARCHAR(100),
        Description NVARCHAR(2000),
        ExecutionUser VARCHAR(100),
        IsActive BIT,
        Action VARCHAR(10), -- 'INSERT', 'UPDATE', or 'ERROR'
        Message NVARCHAR(2000)
    )
    
    -- Copy data from TVP to our temp table
    INSERT INTO @ImportData (Name, Description, ExecutionUser, IsActive)
    SELECT 
        Name,
        Description,
        ExecutionUser,
        IsActive
    FROM @DatabasesData
    
    -- Check if we have any data to process
    IF NOT EXISTS (SELECT 1 FROM @ImportData)
    BEGIN
        SET @ErrCode = 1
        SET @ErrMsg = 'No data provided for import'
        
        -- Return empty result set
        SELECT 
            CAST(NULL AS INT) AS DatabaseId,
            CAST(NULL AS VARCHAR(100)) AS Name,
            CAST(NULL AS NVARCHAR(2000)) AS Description,
            CAST(NULL AS VARCHAR(100)) AS ExecutionUser,
            CAST(NULL AS BIT) AS IsActive,
            'ERROR' AS Action,
            'No data provided for import' AS Message
        WHERE 1 = 0
        
        RETURN
    END
    
    -- Validate data - check for empty names
    INSERT INTO @Results (Name, Description, ExecutionUser, IsActive, Action, Message)
    SELECT Name, Description, ExecutionUser, IsActive, 'ERROR', 'Database name cannot be empty'
    FROM @ImportData 
    WHERE Name IS NULL OR Name = ''
    
    IF EXISTS (SELECT 1 FROM @Results WHERE Action = 'ERROR')
    BEGIN
        SET @ErrCode = 1
        SET @ErrMsg = 'One or more database names are empty'
        
        -- Return the results
        SELECT DatabaseId, Name, Description, ExecutionUser, IsActive, Action, Message
        FROM @Results
        
        RETURN
    END
    
    -- Check for duplicates in the import data
    DECLARE @DuplicateNames TABLE (Name VARCHAR(100), Count INT)
    
    INSERT INTO @DuplicateNames
    SELECT Name, COUNT(*) as Count
    FROM @ImportData 
    GROUP BY Name 
    HAVING COUNT(*) > 1
    
    IF EXISTS (SELECT 1 FROM @DuplicateNames)
    BEGIN
        -- Add duplicate records to results
        INSERT INTO @Results (Name, Description, ExecutionUser, IsActive, Action, Message)
        SELECT i.Name, i.Description, i.ExecutionUser, i.IsActive, 'ERROR', 
               'Duplicate database name found in import data: ' + i.Name
        FROM @ImportData i
        INNER JOIN @DuplicateNames d ON i.Name = d.Name
        
        SET @ErrCode = 2
        SET @ErrMsg = 'Duplicate database names found in import data'
        
        -- Return the results
        SELECT DatabaseId, Name, Description, ExecutionUser, IsActive, Action, Message
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
        
        -- Process each database in the import data
        DECLARE @Name VARCHAR(100)
        DECLARE @Description NVARCHAR(2000)
        DECLARE @ExecutionUser VARCHAR(100)
        DECLARE @IsActive BIT
        DECLARE @RowNum INT
        DECLARE @DatabaseId INT
        DECLARE @LocalErrCode INT
        DECLARE @LocalErrMsg NVARCHAR(200)
        DECLARE @HasErrors BIT = 0
        
        DECLARE db_cursor CURSOR FOR
        SELECT Name, Description, ExecutionUser, IsActive, RowNum
        FROM @ImportData
        
        OPEN db_cursor
        FETCH NEXT FROM db_cursor INTO @Name, @Description, @ExecutionUser, @IsActive, @RowNum
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @DatabaseId = NULL
            SET @LocalErrCode = 0
            SET @LocalErrMsg = ''
            
            -- Check if the database already exists
            SELECT @DatabaseId = DatabaseId
            FROM [dbo].[SpmDatabase] WITH (NOLOCK)
            WHERE [Name] = @Name AND IsDeleted = 0
            
            IF @DatabaseId IS NOT NULL
            BEGIN
                -- Database exists, update it
                EXEC [dbo].[SpmDatabase_Update]
                    @DatabaseId = @DatabaseId,
                    @Name = @Name,
                    @Description = @Description,
                    @ExecutionUser = @ExecutionUser,
                    @IsActive = @IsActive,
                    @ModifiedBy = @CreatedBy,
                    @ModifiedDate = NULL, -- Let the SP set the current date
                    @ErrCode = @LocalErrCode OUTPUT,
                    @ErrMsg = @LocalErrMsg OUTPUT
                
                -- Check if the update was successful
                IF @LocalErrCode = 0
                BEGIN
                    -- Add to results
                    INSERT INTO @Results (DatabaseId, Name, Description, ExecutionUser, IsActive, Action, Message)
                    VALUES (@DatabaseId, @Name, @Description, @ExecutionUser, @IsActive, 'UPDATE', 'Database updated successfully')
                    
                    SET @UpdateCount = @UpdateCount + 1
                END
                ELSE
                BEGIN
                    -- Add to results with error
                    INSERT INTO @Results (DatabaseId, Name, Description, ExecutionUser, IsActive, Action, Message)
                    VALUES (@DatabaseId, @Name, @Description, @ExecutionUser, @IsActive, 'ERROR', 
                           'Error updating database: ' + ISNULL(@LocalErrMsg, 'Unknown error'))
                    
                    SET @ErrorCount = @ErrorCount + 1
                    SET @HasErrors = 1
                END
            END
            ELSE
            BEGIN
                -- Database doesn't exist, insert it
                EXEC [dbo].[SpmDatabase_Insert]
                    @Name = @Name,
                    @Description = @Description,
                    @ExecutionUser = @ExecutionUser,
                    @IsActive = @IsActive,
                    @CreatedBy = @CreatedBy,
                    @DatabaseId = @DatabaseId OUTPUT,
                    @ErrCode = @LocalErrCode OUTPUT,
                    @ErrMsg = @LocalErrMsg OUTPUT
                
                -- Check if the insert was successful
                IF @LocalErrCode = 0
                BEGIN
                    -- Add to results
                    INSERT INTO @Results (DatabaseId, Name, Description, ExecutionUser, IsActive, Action, Message)
                    VALUES (@DatabaseId, @Name, @Description, @ExecutionUser, @IsActive, 'INSERT', 'Database inserted successfully')
                    
                    SET @InsertCount = @InsertCount + 1
                END
                ELSE
                BEGIN
                    -- Add to results with error
                    INSERT INTO @Results (DatabaseId, Name, Description, ExecutionUser, IsActive, Action, Message)
                    VALUES (NULL, @Name, @Description, @ExecutionUser, @IsActive, 'ERROR', 
                           'Error inserting database: ' + ISNULL(@LocalErrMsg, 'Unknown error'))
                    
                    SET @ErrorCount = @ErrorCount + 1
                    SET @HasErrors = 1
                END
            END
            
            FETCH NEXT FROM db_cursor INTO @Name, @Description, @ExecutionUser, @IsActive, @RowNum
        END
        
        CLOSE db_cursor
        DEALLOCATE db_cursor
        
        -- Check if we had any errors
        IF @HasErrors = 1
        BEGIN
            -- Roll back the transaction
            ROLLBACK TRANSACTION
            
            SET @ErrCode = 3
            SET @ErrMsg = 'One or more errors occurred during import. No changes were made.'
        END
        ELSE
        BEGIN
            -- Commit the transaction
            COMMIT TRANSACTION
            
            SET @ErrCode = 0
            SET @ErrMsg = 'Successfully processed ' + CAST((@InsertCount + @UpdateCount) AS VARCHAR) + ' database(s): ' + 
                          CAST(@InsertCount AS VARCHAR) + ' inserted, ' + CAST(@UpdateCount AS VARCHAR) + ' updated'
        END
        
        -- Return the results
        SELECT DatabaseId, Name, Description, ExecutionUser, IsActive, Action, Message
        FROM @Results
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION
            
        SET @ErrCode = ERROR_NUMBER()
        SET @ErrMsg = ERROR_MESSAGE()
        
        -- Clean up cursor if still open
        IF CURSOR_STATUS('local', 'db_cursor') >= 0
        BEGIN
            CLOSE db_cursor
            DEALLOCATE db_cursor
        END
        
        -- Add error to results
        INSERT INTO @Results (DatabaseId, Name, Description, ExecutionUser, IsActive, Action, Message)
        VALUES (NULL, NULL, NULL, NULL, NULL, 'ERROR', 'Unexpected error: ' + ERROR_MESSAGE())
        
        -- Return the results
        SELECT DatabaseId, Name, Description, ExecutionUser, IsActive, Action, Message
        FROM @Results
    END CATCH
END