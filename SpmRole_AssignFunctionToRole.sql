CREATE PROCEDURE [dbo].[SpmRole_AssignFunctionToRole]
	 @RoleId INT
	,@Functions VARCHAR(5000) = ''
	,@ModifiedBy INT = NULL
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*
Created: 20150609@Josh.Phan
Task: Assign function to role.
DB: SPM
Original: 

Revisions:  
Param's Explanation:
	@Functions = <ROOT><Function FunctionId="1" IsRead="1" IsHost="0"></Function></ROOT>
*/
BEGIN
	SET NOCOUNT ON;		
	
	CREATE TABLE #Functions (
		FunctionId INT
		,IsRead BIT
		,IsHost BIT)

	BEGIN TRY
		DECLARE @DocHandler INT

		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@Functions

		INSERT INTO #Functions (
			FunctionId
			,IsRead
			,IsHost)
		SELECT FunctionId
			,IsRead
			,IsHost
		FROM OPENXML(@DocHandler, '/ROOT/Function', 1) WITH (FunctionId INT, IsRead INT, IsHost BIT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT @ErrCode = 1
			,@ErrMsg = N'Evaluate failed. Paramter invalid.'

		RETURN
	END CATCH

	UPDATE rf
	SET rf.IsRead = f.IsRead
		,rf.IsHost = f.IsHost
	FROM dbo.[RoleFunction] AS rf WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #Functions AS f WITH (NOLOCK) ON rf.FunctionId = f.FunctionId
	WHERE rf.RoleId = @RoleId

	DELETE f
	FROM #Functions AS f
	WHERE EXISTS (
			SELECT 1
			FROM dbo.RoleFunction AS rf WITH (NOLOCK)
			WHERE rf.RoleId = @RoleId
				AND rf.FunctionId = f.FunctionId
			)

	INSERT INTO dbo.[RoleFunction] (
		[RoleId]
		,[FunctionId]
		,[IsRead]
		,[IsHost]
		,[ModifiedBy]
		,[ModifiedDate]
		)
	SELECT @RoleId
		,FunctionId
		,IsRead
		,IsHost
		,@ModifiedBy
		,GETDATE()
	FROM #Functions
END

