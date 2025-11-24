CREATE PROCEDURE [dbo].[SpmDatabaseStandby_ParseTextToTable]
    @StandbyDatabasesText NVARCHAR(MAX),
    @EnvironmentId INT,
    @ErrCode INT = 0 OUTPUT,
    @ErrMsg NVARCHAR(MAX) = '' OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LocalErrMsg NVARCHAR(MAX) = N'';

    -- Initialize outputs
    SET @ErrCode = 0;
    SET @ErrMsg = N'';

    -- Validate input
    IF ISNULL(LTRIM(RTRIM(@StandbyDatabasesText)), '') = ''
    BEGIN
        SET @ErrCode = 100;
        SET @ErrMsg = N'Standby databases text is required.';
        RETURN;
    END;

    -- Clean input
    SET @StandbyDatabasesText = REPLACE(REPLACE(REPLACE(@StandbyDatabasesText, CHAR(13), ''), CHAR(10), ''), '  ', ' ');

    -- STEP 1: Split text into pairs (deduplicate)

    DECLARE @Pairs TABLE (Pair NVARCHAR(400));

    INSERT INTO @Pairs (Pair)
    SELECT DISTINCT LTRIM(RTRIM(val))
    FROM dbo.fnc_strSplit(@StandbyDatabasesText, ',')
    WHERE LTRIM(RTRIM(val)) <> '';

    -- STEP 2: Split each pair into DbServer and Database name

    DECLARE @Parsed TABLE (
        Pair NVARCHAR(400),
        DbServer NVARCHAR(200),
        DatabaseName NVARCHAR(200)
    );

    INSERT INTO @Parsed (Pair, DbServer, DatabaseName)
    SELECT 
        p.Pair,
        LTRIM(RTRIM(LEFT(p.Pair, CHARINDEX('/', p.Pair + '/') - 1))) AS DbServer,
        LTRIM(RTRIM(SUBSTRING(p.Pair, CHARINDEX('/', p.Pair + '/') + 1, LEN(p.Pair)))) AS DatabaseName
    FROM @Pairs p;

    -- STEP 3: Validate invalid format (missing '/')

    IF EXISTS (SELECT 1 FROM @Parsed WHERE DbServer = '' OR DatabaseName = '')
    BEGIN
        SELECT @LocalErrMsg = STRING_AGG(N'Invalid format: "' + Pair + N'". Expected "DbServer/Database".', N' ')
        FROM @Parsed WHERE DbServer = '' OR DatabaseName = '';

        SET @ErrCode = 100;
        SET @ErrMsg = @LocalErrMsg;
        RETURN;
    END;

    -- STEP 4: Join with existing DB Server and Database tables

    DECLARE @Lookup TABLE (
        Pair NVARCHAR(400),
        DbServer NVARCHAR(200),
        DatabaseName NVARCHAR(200),
        DbServerId INT,
        DatabaseId INT
    );

    INSERT INTO @Lookup (Pair, DbServer, DatabaseName, DbServerId, DatabaseId)
    SELECT 
        p.Pair,
        p.DbServer,
        p.DatabaseName,
        s.DbServerId,
        d.DatabaseId
    FROM @Parsed p
    LEFT JOIN dbo.SpmDbServer s WITH (NOLOCK)
        ON s.[Name] = p.DbServer AND s.IsDeleted = 0
    LEFT JOIN dbo.SpmDatabase d WITH (NOLOCK)
        ON d.[Name] = p.DatabaseName AND d.IsDeleted = 0;
    -- STEP 5: Collect invalid pairs (missing server, db, or wrong environment)

    -- First, validate that found servers belong to the specified environment
    DECLARE @InvalidEnvServers NVARCHAR(MAX) = N'';

	SELECT @InvalidEnvServers =
	(
		SELECT STRING_AGG(errMsg, N' ')
		FROM (
			SELECT DISTINCT
				N'Server "' + l.DbServer + N'" not found in the selected environment.' AS errMsg
			FROM @Lookup l
			INNER JOIN dbo.SpmDbServer s WITH (NOLOCK)
				ON s.DbServerId = l.DbServerId AND s.IsDeleted = 0
			LEFT JOIN dbo.SpmMachine mc WITH (NOLOCK)
				ON mc.MachineId = s.MachineId AND mc.IsDeleted = 0
			LEFT JOIN dbo.SpmMachineEnvironment me WITH (NOLOCK)
				ON me.MachineId = mc.MachineId AND me.EnvironmentId = @EnvironmentId
			WHERE l.DbServerId IS NOT NULL
				AND me.EnvironmentId IS NULL
		) AS d
	);

    IF @InvalidEnvServers IS NOT NULL
    BEGIN
        SET @ErrCode = 100;
        SET @ErrMsg = @InvalidEnvServers;
        RETURN;
    END;

    -- Then, collect other invalid pairs (missing server or db)
    SELECT @LocalErrMsg = STRING_AGG(
        CASE
            WHEN l.DbServerId IS NULL AND l.DatabaseId IS NULL THEN
                N'Invalid pair "' + l.Pair + N'": both server "' + l.DbServer + N'" and database "' + l.DatabaseName + N'" not found.'
            WHEN l.DbServerId IS NULL THEN
                N'Server "' + l.DbServer + N'" not found for pair "' + l.Pair + N'".'
            WHEN l.DatabaseId IS NULL THEN
                N'Database "' + l.DatabaseName + N'" not found for pair "' + l.Pair + N'".'
        END, N' '
    )
    FROM @Lookup l
    WHERE l.DbServerId IS NULL OR l.DatabaseId IS NULL;

    IF @LocalErrMsg IS NOT NULL
    BEGIN
        SET @ErrCode = 100;
        SET @ErrMsg = @LocalErrMsg;
        RETURN;
    END;

    -- STEP 6: Return valid results

    SELECT DbServerId, DatabaseId
    FROM @Lookup
    WHERE DbServerId IS NOT NULL AND DatabaseId IS NOT NULL;

    SET @ErrCode = 0;
    SET @ErrMsg = N'';
END