CREATE PROCEDURE [dbo].[SpmDbServer_ImportData]
    @DbServersData [dbo].[DbServerTableType] READONLY,
    @CreatedBy INT,
    @ErrCode INT = 0 OUTPUT,
    @ErrMsg NVARCHAR(500) = '' OUTPUT
AS
/*
Created: 20240101@Alex.Tran
Task: Import multiple DB Servers from Excel
DB: SPM
Original: Reuses SpmDbServer_Insert and SpmDbServer_Update

Revisions:  
- Added result set with action and error message for each record
- Modified to process all records before committing
- Added rollback if any error occurs

Param's Explanation:
- @DbServersData: Table-valued parameter containing DB server information
- @CreatedBy: User ID who is importing the data
- @ErrCode: Output parameter for error code (0 = success, non-zero = error)
- @ErrMsg: Output parameter for error message
*/
BEGIN
    SET NOCOUNT ON;
    
    -- Create a table to store results
    DECLARE @ImportResults TABLE
    (
        DbServerId INT NULL,
        Name NVARCHAR(100),
        Machine NVARCHAR(100),
        Description NVARCHAR(200),
        IsPrimary BIT,
        IsActive BIT,
        Action NVARCHAR(10),
        Message NVARCHAR(500),
        IsSuccess BIT
    );
    
    -- Variable to track if any errors occurred
    DECLARE @HasErrors BIT = 0;
    
    -- Process each DB server in the imported data
    DECLARE @Name NVARCHAR(100);
    DECLARE @MachineName NVARCHAR(100);
    DECLARE @Description NVARCHAR(200);
    DECLARE @IsPrimary BIT;
    DECLARE @IsActive BIT;
    DECLARE @MachineId INT;
    DECLARE @DbServerId INT;
    DECLARE @LocalErrCode INT;
    DECLARE @LocalErrMsg NVARCHAR(500);
    
    -- Begin transaction for all operations
    BEGIN TRY
        BEGIN TRANSACTION
        SET XACT_ABORT ON
        
        -- Cursor to process each row
        DECLARE db_cursor CURSOR FOR 
        SELECT 
            d.Name,
            d.Machine,
            d.Description,
            d.IsPrimary,
            d.IsActive
        FROM @DbServersData d;
        
        OPEN db_cursor;
        
        FETCH NEXT FROM db_cursor INTO @Name, @MachineName, @Description, @IsPrimary, @IsActive;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @DbServerId = NULL;
            SET @LocalErrCode = 0;
            SET @LocalErrMsg = '';
            SET @MachineId = NULL;
            
            -- Find machine by name
            SELECT @MachineId = MachineId
            FROM [dbo].[SpmMachine]
            WHERE [Name] = @MachineName AND IsDeleted = 0;
            
            -- If machine not found, add error and continue to next record
            IF @MachineId IS NULL
            BEGIN
                INSERT INTO @ImportResults
                    (DbServerId, Name, Machine, Description, IsPrimary, IsActive, Action, Message, IsSuccess)
                VALUES
                    (NULL, @Name, @MachineName, @Description, @IsPrimary, @IsActive, 'ERROR', 'Machine "' + @MachineName + '" not found', 0);
                    
                SET @HasErrors = 1;
                
                FETCH NEXT FROM db_cursor INTO @Name, @MachineName, @Description, @IsPrimary, @IsActive;
                CONTINUE;
            END
            
            -- Check if DB server already exists
            SELECT @DbServerId = DbServerId
            FROM [dbo].[SpmDbServer]
            WHERE [Name] = @Name AND IsDeleted = 0;
            
            -- Insert or update the DB server
            IF @DbServerId IS NULL
            BEGIN
                -- Insert new DB server
                EXEC [dbo].[SpmDbServer_Insert]
                    @DbServerId = @DbServerId OUTPUT,
                    @Name = @Name,
                    @MachineId = @MachineId,
                    @IsPrimary = @IsPrimary,
                    @IsActive = @IsActive,
                    @Description = @Description,
                    @CreatedBy = @CreatedBy,
                    @ErrCode = @LocalErrCode OUTPUT,
                    @ErrMsg = @LocalErrMsg OUTPUT
                
                -- Check if the insert was successful
                IF @LocalErrCode = 0
                BEGIN
                    -- Add to results
                    INSERT INTO @ImportResults
                        (DbServerId, Name, Machine, Description, IsPrimary, IsActive, Action, Message, IsSuccess)
                    VALUES
                        (@DbServerId, @Name, @MachineName, @Description, @IsPrimary, @IsActive, 'INSERT', 'DB Server created successfully', 1);
                END
                ELSE
                BEGIN
                    -- Add to results with error
                    INSERT INTO @ImportResults
                        (DbServerId, Name, Machine, Description, IsPrimary, IsActive, Action, Message, IsSuccess)
                    VALUES
                        (NULL, @Name, @MachineName, @Description, @IsPrimary, @IsActive, 'ERROR', 
                           'Error inserting DB Server: ' + ISNULL(@LocalErrMsg, 'Unknown error'), 0);
                    
                    SET @HasErrors = 1;
                END
            END
            ELSE
            BEGIN
                -- Update the existing DB server
                EXEC [dbo].[SpmDbServer_Update]
                    @DbServerId = @DbServerId,
                    @Name = @Name,
                    @MachineId = @MachineId,
                    @IsPrimary = @IsPrimary,
                    @IsActive = @IsActive,
                    @Description = @Description,
                    @ModifiedBy = @CreatedBy,
                    @ErrCode = @LocalErrCode OUTPUT,
                    @ErrMsg = @LocalErrMsg OUTPUT
                
                -- Check if the update was successful
                IF @LocalErrCode = 0
                BEGIN
                    -- Add to results
                    INSERT INTO @ImportResults
                        (DbServerId, Name, Machine, Description, IsPrimary, IsActive, Action, Message, IsSuccess)
                    VALUES
                        (@DbServerId, @Name, @MachineName, @Description, @IsPrimary, @IsActive, 'UPDATE', 'DB Server updated successfully', 1);
                END
                ELSE
                BEGIN
                    -- Add to results with error
                    INSERT INTO @ImportResults
                        (DbServerId, Name, Machine, Description, IsPrimary, IsActive, Action, Message, IsSuccess)
                    VALUES
                        (@DbServerId, @Name, @MachineName, @Description, @IsPrimary, @IsActive, 'ERROR', 
                           'Error updating DB Server: ' + ISNULL(@LocalErrMsg, 'Unknown error'), 0);
                    
                    SET @HasErrors = 1;
                END
            END
            
            FETCH NEXT FROM db_cursor INTO @Name, @MachineName, @Description, @IsPrimary, @IsActive;
        END
        
        CLOSE db_cursor;
        DEALLOCATE db_cursor;
        
        -- Check if we had any errors
        IF @HasErrors = 1
        BEGIN
            -- Roll back the transaction
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION
            
            SET @ErrCode = 3;
            SET @ErrMsg = 'One or more errors occurred during import. No changes were made.';
        END
        ELSE
        BEGIN
            -- Commit the transaction
            IF @@TRANCOUNT > 0
                COMMIT TRANSACTION
            
            SET @ErrCode = 0;
            SET @ErrMsg = 'Import completed successfully';
        END
        
        -- Return the results
        SELECT 
            DbServerId, 
            Name, 
            Machine, 
            Description, 
            IsPrimary, 
            IsActive, 
            Action, 
            Message, 
            IsSuccess
        FROM @ImportResults
        ORDER BY 
            CASE Action 
                WHEN 'ERROR' THEN 1 
                WHEN 'INSERT' THEN 2 
                WHEN 'UPDATE' THEN 3
            END,
            Name;
    END TRY
    BEGIN CATCH
        SET XACT_ABORT OFF
        
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION
            
        SET @ErrCode = ERROR_NUMBER();
        SET @ErrMsg = ERROR_MESSAGE();
        
        -- Clean up cursor if still open
        IF CURSOR_STATUS('local', 'db_cursor') >= 0
        BEGIN
            CLOSE db_cursor;
            DEALLOCATE db_cursor;
        END
        
        -- Add error to results
        INSERT INTO @ImportResults
            (DbServerId, Name, Machine, Description, IsPrimary, IsActive, Action, Message, IsSuccess)
        VALUES
            (NULL, NULL, NULL, NULL, NULL, NULL, 'ERROR', 'Unexpected error: ' + ERROR_MESSAGE(), 0);
        
        -- Return the results
        SELECT 
            DbServerId, 
            Name, 
            Machine, 
            Description, 
            IsPrimary, 
            IsActive, 
            Action, 
            Message, 
            IsSuccess
        FROM @ImportResults;
    END CATCH
END