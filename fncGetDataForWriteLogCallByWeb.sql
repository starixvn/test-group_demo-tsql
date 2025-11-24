CREATE FUNCTION [dbo].[fncGetDataForWriteLogCallByWeb]
(
	@StoredProcedureId INT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Data NVARCHAR(MAX)

	SELECT @Data = '<r><n>'+ Name + '</n>'+  '<cbw>' + CAST(CallByWeb AS VARCHAR(10)) + '</cbw></r>'
		FROM [dbo].[SpmStoredProcedure] WITH (NOLOCK)
		WHERE StoredProcedureId = @StoredProcedureId

	RETURN @Data
END

