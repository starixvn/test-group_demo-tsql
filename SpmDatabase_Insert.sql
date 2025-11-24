CREATE PROCEDURE [dbo].[SpmDatabase_Insert]	
	@Name VARCHAR(100)
	,@IsActive BIT=0
	,@Description NVARCHAR(2000)=NULL
	,@ExecutionUser VARCHAR(100)=NULL
	,@CreatedBy INT=NULL
	
	,@DatabaseId INT=NULL OUTPUT
	,@ErrCode INT=0 OUTPUT
	,@ErrMsg NVARCHAR(200)='' OUTPUT
AS
/*
Created: 20150327@Aaron.Cao
Task: Insert new Database. 
DB: SPM
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;	
	
	DECLARE @Data NVARCHAR(MAX)

	IF EXISTS( 
		SELECT 1 
		FROM [dbo].[SpmDatabase] WITH (NOLOCK)
		WHERE [Name] = @Name AND IsDeleted = 0)
		
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = 'Database ''' + @Name + ''' has already existed.'
		RETURN
	END

	INSERT INTO [dbo].[SpmDatabase]
		([Name]
		,[Description]
		,[IsActive]
		,[ExecutionUser]
		,[ModifiedBy]
		,[ModifiedDate])
	VALUES 
		(@Name
		,@Description
		,@IsActive
		,LTRIM(RTRIM(@ExecutionUser))
		,@CreatedBy
		,GETDATE())

	SELECT @DatabaseId = CAST(SCOPE_IDENTITY() AS INT)

	EXEC @Data = [dbo].[fncGetDataForWriteLog] @ObjectId = @DatabaseId, @ObjectType = 3
	EXEC dbo.SpmLog_Insert @UserId = @CreatedBy, @SpName = 'SpmDatabase_Insert', @ObjectId = @DatabaseId, @ObjectTypeId = 3, @Data = @Data, @OldData = NULL
END

