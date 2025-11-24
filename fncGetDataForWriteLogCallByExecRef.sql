CREATE FUNCTION [dbo].[fncGetDataForWriteLogCallByExecRef]
(
	@StoredProcedureId INT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Data NVARCHAR(MAX)

	SELECT @Data = '<r><n>'+ Name + '</n>'+  '<cbe>' + CAST(CallByExecRef AS VARCHAR(10)) + '</cbe></r>'
		FROM [dbo].[SpmStoredProcedure] WITH (NOLOCK)
		WHERE StoredProcedureId = @StoredProcedureId

	RETURN @Data
END

