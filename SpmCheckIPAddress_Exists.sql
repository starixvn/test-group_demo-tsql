CREATE PROCEDURE [dbo].[SpmCheckIPAddress_Exists]
	@MachineId INT=NULL
	,@IpAddresses VARCHAR(500)=NULL
	
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20150318@Josh.Phan
Task: Check IP Address is exists or not.
DB: SPM
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;
	
	IF OBJECT_ID('tempdb..#IPAddressTemp') IS NOT NULL
		BEGIN
			DROP TABLE #IPAddressTemp
		END 

	CREATE TABLE #IPAddressTemp (
		IPAddress  VARCHAR(50))

	IF ISNULL(@IpAddresses,'')<>''
	BEGIN
		INSERT INTO #IPAddressTemp (
			IPAddress )
		SELECT DISTINCT val FROM fnc_strSplit (@IpAddresses, ',')
	END		
		
	DECLARE @ExistsIpAddress VARCHAR(500)
	
	SELECT @ExistsIpAddress = COALESCE(@ExistsIpAddress + ', ', '') + tempAdd.[IPAddress]
	FROM (  SELECT DISTINCT ipTemp.[IPAddress] 
			FROM [dbo].[SpmMachineIPAddress] AS maAdd WITH (NOLOCK)
			INNER JOIN #IPAddressTemp AS ipTemp ON maAdd.[IPAddress] = ipTemp.[IPAddress]	
			INNER JOIN [dbo].[SpmMachine] AS ma ON maAdd.[MachineId] = ma.[MachineId]
			WHERE ISNULL(ipTemp.[IPAddress],'') <> '' AND (@MachineId IS NULL OR ma.[MachineId] <> @MachineId)) AS tempAdd

	IF (ISNULL(@ExistsIpAddress,'') <> '')

	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = 'The IP Address (' + @ExistsIpAddress + ') already existed. Please try again.'
		RETURN
	END
	
	DROP TABLE #IPAddressTemp	
END

