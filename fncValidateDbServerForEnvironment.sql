CREATE FUNCTION [dbo].[fncValidateDbServerForEnvironment] (
    @DbServerName VARCHAR(100),
    @EnvironmentId INT
)
RETURNS TABLE
AS
RETURN (
    SELECT 
        CASE 
            WHEN s.DbServerId IS NULL THEN 'NOT FOUND'
            WHEN NOT EXISTS (
                SELECT 1 
                FROM [dbo].[SpmMachineEnvironment] me
                INNER JOIN [dbo].[SpmMachine] m ON me.MachineId = m.MachineId
                INNER JOIN [dbo].[SpmDbServer] d ON d.MachineId = m.MachineId
                WHERE me.EnvironmentId = @EnvironmentId
                AND d.DbServerId = s.DbServerId
            ) THEN 'INVALID'
            ELSE 'VALID'
        END AS Status,
        s.DbServerId,
        @DbServerName AS DbServerName
    FROM (VALUES(1)) AS dummy(x)
    OUTER APPLY (
        SELECT TOP 1 DbServerId
        FROM [dbo].[SpmDbServer] 
        WHERE [Name] = @DbServerName AND IsDeleted = 0
    ) AS s
);