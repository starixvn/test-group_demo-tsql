CREATE PROCEDURE [dbo].[SpmDatabaseStandby_Update]	
	@StandbyId INT
    ,@AliasServerId INT
    ,@EnvironmentId INT
    ,@DatabaseId INT
	,@IsActive BIT=0	
	,@ModifiedBy INT=NULL
    ,@StandbyDatabases XML = NULL
    ,@StandbyDatabasesText NVARCHAR(MAX) = NULL
	,@ErrCode INT=0 OUTPUT
	,@ErrMsg NVARCHAR(MAX)='' OUTPUT
AS
/*
Created: 20181022@Larry.Tran
Task: Update Database Standby. 
DB: SPM
Original: 

Revisions:  
Param's Explanation:
    - @StandbyDatabases:
        <ROOT>
	       <StandbyDatabase DbServerId="" DatabaseId=""></StandbyDatabase>
        </ROOT>
    - @StandbyDatabasesText:
        Format: "StandbyDbServer/StandbyDatabase, StandbyDbServer/StandbyDatabase"
        If provided, will be parsed and converted to XML format
*/
BEGIN
	SET NOCOUNT ON;	
	
    DECLARE @Data NVARCHAR(MAX)
    DECLARE @OldData NVARCHAR(MAX)
    DECLARE @LogObjectType INT = 13
    DECLARE @ParsedStandbyData TABLE (
        DbServerId INT NOT NULL,
        DatabaseId INT NOT NULL
    )

	IF EXISTS( 
		SELECT TOP 1 1 
		FROM [dbo].SpmDatabaseStandby AS sb WITH (NOLOCK)
		WHERE IsDeleted = 0 AND
            sb.AliasServerId = @AliasServerId AND
            sb.EnvironmentId = @EnvironmentId AND
            sb.DatabaseId = @DatabaseId AND
            sb.StandbyId <> @StandbyId
    )		
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = 'The Standby Database configuration has already existed.'
		RETURN
	END

	SET XACT_ABORT ON
	BEGIN TRAN
	BEGIN TRY       
        EXEC @OldData = [dbo].[fncGetDataForWriteLog] @ObjectId = @StandbyId, @ObjectType = @LogObjectType

        UPDATE dbo.SpmDatabaseStandby WITH(UPDLOCK,ROWLOCK)
        SET            
            AliasServerId = @AliasServerId, -- int
            EnvironmentId = @EnvironmentId, -- int
            DatabaseId = @DatabaseId, -- int
            IsActive = @IsActive, -- bit
            ModifiedBy = @ModifiedBy, -- int
            ModifiedDate = GETDATE()
        WHERE StandbyId = @StandbyId

        DELETE dbo.SpmDatabaseStandbyRelation WHERE StandbyId = @StandbyId

        -- Parse standby databases data
        IF @StandbyDatabasesText IS NOT NULL AND @StandbyDatabasesText <> ''
        BEGIN
            -- Parse text input using stored procedure that returns result set
            DECLARE @ParseErrCode INT, @ParseErrMsg NVARCHAR(MAX)
            INSERT INTO @ParsedStandbyData (DbServerId, DatabaseId)
            EXEC [dbo].[SpmDatabaseStandby_ParseTextToTable]
                @StandbyDatabasesText = @StandbyDatabasesText,
                @EnvironmentId = @EnvironmentId,
                @ErrCode = @ParseErrCode OUTPUT,
                @ErrMsg = @ParseErrMsg OUTPUT

            IF @ParseErrCode <> 0
            BEGIN
                SELECT @ErrCode = @ParseErrCode, 
                    @ErrMsg = @ParseErrMsg
                ROLLBACK
                RETURN
            END
        END
        ELSE IF @StandbyDatabases IS NOT NULL AND CAST(@StandbyDatabases AS NVARCHAR(MAX)) <> ''
        BEGIN
            -- Parse XML input (legacy support)
            DECLARE @DocHandler INT
            EXEC sp_xml_preparedocument @DocHandler OUTPUT, @StandbyDatabases

            INSERT INTO @ParsedStandbyData (DbServerId, DatabaseId)
            SELECT DbServerId, DatabaseId
            FROM OPENXML(@DocHandler, '/ROOT/StandbyDatabase', 1)
            WITH (DbServerId INT, DatabaseId INT)

            EXEC sp_xml_removedocument @DocHandler
        END
        
        -- Validate that we have standby databases data
        IF NOT EXISTS (SELECT 1 FROM @ParsedStandbyData)
        BEGIN
            SELECT @ErrCode = 100
                ,@ErrMsg = 'Standby databases data is required.'
            ROLLBACK
            RETURN
        END

        -- Insert standby database relations directly from parsed data
        INSERT INTO dbo.SpmDatabaseStandbyRelation
        (
            StandbyId,
            DbServerId,
            DatabaseId
        )
        SELECT DISTINCT
            @StandbyId,
            DbServerId,
            DatabaseId
        FROM @ParsedStandbyData
        
	    EXEC @Data = [dbo].[fncGetDataForWriteLog] @ObjectId = @StandbyId, @ObjectType = @LogObjectType
	    EXEC dbo.SpmLog_Insert @UserId = @ModifiedBy, @SpName = 'SpmDatabaseStandby_Update', @ObjectId = @StandbyId, @ObjectTypeId = @LogObjectType, @Data = @Data, @OldData = @OldData

        COMMIT
    END TRY
    BEGIN CATCH
	   IF @@TRANCOUNT > 0
	   BEGIN
		  ROLLBACK

		  SELECT @ErrCode = 100
		        ,@ErrMsg = ERROR_MESSAGE()
	   END
    END CATCH
END