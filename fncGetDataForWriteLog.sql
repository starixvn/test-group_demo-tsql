CREATE FUNCTION [dbo].[fncGetDataForWriteLog]
(
	@ObjectId INT,
	@ObjectType INT
)
RETURNS VARCHAR(MAX)
AS
BEGIN
    DECLARE @Data VARCHAR(MAX), @Tags VARCHAR(500), @EnvironmentIdsOld VARCHAR(50), @NestedSp VARCHAR(MAX)
	SELECT @Tags = '', @NestedSp ='', @EnvironmentIdsOld = ''

	IF(@ObjectType = 1)
	BEGIN
		DECLARE @IpAddressesOld NVARCHAR(500)
		SET @IpAddressesOld = ''

		SELECT @IpAddressesOld = @IpAddressesOld + '<ip>' + IPAddress + '</ip>'
		FROM dbo.SpmMachineIPAddress WITH (NOLOCK)
		WHERE MachineId = @ObjectId

		SELECT @EnvironmentIdsOld = CASE WHEN ISNULL(@EnvironmentIdsOld, '') = '' THEN '' ELSE (@EnvironmentIdsOld + ',') END + CAST(EnvironmentId AS VARCHAR(1))
		FROM dbo.SpmMachineEnvironment WITH (NOLOCK)
		WHERE MachineId = @ObjectId
		SELECT @Data = CONCAT(
			'<r><n>'
			,dbo.fncEncodeXmlSpecialCharacter(mc.Name),'</n><ips>'
			,@IpAddressesOld,'</ips><d>'
			,dbo.fncEncodeXmlSpecialCharacter(mc.[Description]),'</d><a>'
			,mc.IsActive,'</a><ev>'
			,@EnvironmentIdsOld,'</ev></r>'
		)
		FROM dbo.SpmMachine AS mc WITH (NOLOCK)
		WHERE [MachineId] = @ObjectId
	END
	ELSE IF(@ObjectType = 2)
	BEGIN		
		SELECT @Data = CONCAT(
				'<r><n>'
				,dbo.fncEncodeXmlSpecialCharacter(sv.Name),'</n><mc>'
				,dbo.fncEncodeXmlSpecialCharacter(mc.Name),'</mc><p>'
				,IsPrimary,'</p><bks></bks><a>'
				,sv.IsActive,'</a><de>'
				,dbo.fncEncodeXmlSpecialCharacter(sv.[Description]),'</de></r>'
			)
		FROM [dbo].[SpmDbServer] AS sv WITH (NOLOCK)
		INNER JOIN [dbo].[SpmMachine] AS mc WITH (NOLOCK) ON sv.MachineId = mc.MachineId
		WHERE [DbServerId] = @ObjectId
	END
	ELSE IF(@ObjectType = 3)
	BEGIN
		SELECT @Data = CONCAT(
			'<r><n>'
			,dbo.fncEncodeXmlSpecialCharacter(Name),'</n><d>'
			,dbo.fncEncodeXmlSpecialCharacter([Description]),'</d><a>'
			,IsActive,'</a></r>'
		)
		FROM [dbo].[SpmDatabase] WITH (NOLOCK)
		WHERE [DatabaseId] = @ObjectId
	END
	ELSE IF(@ObjectType = 4)
	BEGIN
		DECLARE @DbServerOld VARCHAR(5000), @DatabaseOld VARCHAR(200)
		SELECT @DbServerOld = '', @DatabaseOld = ''

		SELECT @DbServerOld = @DbServerOld 
			+ '<sv><n>' + dbo.fncEncodeXmlSpecialCharacter(sv.Name) + '</n>'
			+ '<ev>' + CAST(EnvironmentId AS VARCHAR(10)) + '</ev></sv>'
		FROM [dbo].[SpmAliasServerEnvironment] AS aev WITH (NOLOCK)
		INNER JOIN [dbo].[SpmDbServer] AS sv WITH (NOLOCK) ON aev.DbServerId = sv.DbServerId
		WHERE aev.AliasServerId = @ObjectId

		SELECT @DatabaseOld = @DatabaseOld + '<db>' + dbo.fncEncodeXmlSpecialCharacter(db.Name) + '</db>'
		FROM [dbo].[SpmAliasServerDatabase] AS adb WITH (NOLOCK)
		INNER JOIN [dbo].[SpmDatabase] AS db WITH (NOLOCK) ON adb.DatabaseId = db.DatabaseId
		WHERE adb.AliasServerId = @ObjectId		

		SELECT @Data = '<r><n>'+ dbo.fncEncodeXmlSpecialCharacter(Name) + '</n>' 
				+ '<svs>' + @DbServerOld + '</svs>'
				+  '<dbs>' + @DatabaseOld + '</dbs>'
				+  '<bks></bks>'
				+  '<d>' + dbo.fncEncodeXmlSpecialCharacter([Description]) + '</d>'
				+  '<a>' + CAST(IsActive AS VARCHAR(10)) + '</a></r>'
		FROM [dbo].[SpmAliasServer] WITH (NOLOCK)
		WHERE AliasServerId = @ObjectId
	END
	ELSE IF(@ObjectType = 5)
	BEGIN
	     DECLARE @WebPIC VARCHAR(MAX) = ''		
          DECLARE @GroupName VARCHAR(100) = ''

		SELECT @Tags = @Tags + '<tg>' + dbo.fncEncodeXmlSpecialCharacter(tg.Name) + '</tg>'
		FROM [dbo].[SpmTagDetail] AS tgdt WITH (NOLOCK)
		INNER JOIN [dbo].[SpmTag] AS tg WITH (NOLOCK) ON tgdt.TagId = tg.TagId
		WHERE tgdt.ObjectId = @ObjectId
			AND tgdt.[Type] = 5
	     
		SELECT @WebPIC = @WebPIC + '<pic>' + dbo.fncEncodeXmlSpecialCharacter(e.NickName) + '</pic>'
		FROM dbo.SpmSystem AS s WITH (NOLOCK)
		  INNER JOIN dbo.SpmSystemPersonInCharge AS pic WITH (NOLOCK)
			 ON pic.SystemId = s.SystemId
		  INNER JOIN dbo.Employee AS e WITH (NOLOCK)
			 ON e.EmployeeId = pic.UserId
	     WHERE s.SystemId = @ObjectId
          
          SELECT @GroupName = dbo.fncEncodeXmlSpecialCharacter(g.Name)
          FROM dbo.SpmSystem AS s WITH (NOLOCK)
            INNER JOIN dbo.SpmSystemGroup AS g WITH (NOLOCK) ON s.GroupId = g.GroupId
            WHERE s.SystemId = @ObjectId            			  

		SELECT @Data = CONCAT(
			'<r><n>'
			,dbo.fncEncodeXmlSpecialCharacter(Name),'</n><tgs>'
			,@Tags,'</tgs><g>'
               ,@GroupName,'</g><pics>'
			,@WebPIC,'</pics><d>'
			,dbo.fncEncodeXmlSpecialCharacter([Description]),'</d><a>'
			,IsActive,'</a></r>'
		)
		FROM [dbo].[SpmSystem] WITH (NOLOCK)
		WHERE SystemId = @ObjectId
	END
	ELSE IF(@ObjectType = 6)
	BEGIN
		SELECT @Tags = @Tags + '<tg>' + dbo.fncEncodeXmlSpecialCharacter(tg.Name) + '</tg>'
		FROM [dbo].[SpmTagDetail] AS tgdt WITH (NOLOCK)
		INNER JOIN [dbo].[SpmTag] AS tg WITH (NOLOCK) ON tgdt.TagId = tg.TagId
		WHERE tgdt.ObjectId = @ObjectId
			AND tgdt.[Type] = 6

		SELECT @Data = CONCAT(
			'<r><n>'
			,dbo.fncEncodeXmlSpecialCharacter(Name),'</n><tgs>'
			,@Tags,'</tgs><d>'
			,dbo.fncEncodeXmlSpecialCharacter([Description]),'</d><a>'
			,IsActive,'</a></r>'
		)
		FROM [dbo].[SpmProduct] WITH (NOLOCK)
		WHERE ProductId = @ObjectId
	END
	ELSE IF(@ObjectType = 7)
	BEGIN
		DECLARE @SystemProduct VARCHAR(5000)
          DECLARE @ParentFunctions VARCHAR(5000) = ''
		SET @SystemProduct = ''		

		SELECT @Tags = @Tags + '<tg>' + dbo.fncEncodeXmlSpecialCharacter(tg.Name) + '</tg>'
		FROM [dbo].[SpmTagDetail] AS tgdt WITH (NOLOCK)
		INNER JOIN [dbo].[SpmTag] AS tg WITH (NOLOCK) ON tgdt.TagId = tg.TagId
		WHERE tgdt.ObjectId = @ObjectId
			AND tgdt.[Type] = 7

		SELECT @SystemProduct = @SystemProduct 
			+ '<stp><s>' + dbo.fncEncodeXmlSpecialCharacter(st.Name) + '</s>'
			+ '<p>' + dbo.fncEncodeXmlSpecialCharacter(ISNULL(pr.Name, '')) + '</p></stp>'
		FROM [dbo].[SpmFunctionSystemProduct] AS fsp WITH (NOLOCK)
		INNER JOIN [dbo].[SpmSystem] AS st WITH (NOLOCK) ON fsp.SystemId = st.SystemId
		LEFT JOIN [dbo].[SpmProduct] AS pr WITH (NOLOCK) ON fsp.ProductId = pr.ProductId
		WHERE fsp.FunctionId = @ObjectId

          SELECT @ParentFunctions = @ParentFunctions
                + '<pf><s>' + dbo.fncEncodeXmlSpecialCharacter(s.Name) + '</s><f>' + dbo.fncEncodeXmlSpecialCharacter(parent.Name) + '</f></pf>'
          FROM dbo.SpmFunctionRelation AS fr WITH (NOLOCK)
            INNER JOIN dbo.SpmFunction AS parent WITH (NOLOCK) ON fr.ParentId = parent.FunctionId
            INNER JOIN dbo.SpmSystem AS s WITH (NOLOCK) ON fr.SystemId = s.SystemId
          WHERE fr.FunctionId = @ObjectId             

		SELECT @Data = CONCAT(
			'<r><n>'
			,dbo.fncEncodeXmlSpecialCharacter(Name),'</n><fg>'
			,FunctionGroupId,'</fg><tgs>'
			,@Tags,'</tgs><d>'
			,dbo.fncEncodeXmlSpecialCharacter([Description]),'</d><a>'
			,IsActive,'</a><ev>'
			,@EnvironmentIdsOld,'</ev><stps>'
			,@SystemProduct,'</stps><pfs>'
               ,@ParentFunctions,'</pfs></r>'
		)
		FROM [dbo].[SpmFunction] WITH (NOLOCK)
		WHERE FunctionId = @ObjectId
	END
	ELSE IF(@ObjectType = 8)
	BEGIN
		DECLARE @RedmineIssue VARCHAR(MAX), @FunctionSystemProduct VARCHAR(MAX)
		SELECT @FunctionSystemProduct = '', @RedmineIssue = ''

		SELECT @Tags = @Tags + '<tg>' + dbo.fncEncodeXmlSpecialCharacter(tg.Name) + '</tg>'
		FROM [dbo].[SpmTagDetail] AS tgdt WITH (NOLOCK)
		INNER JOIN [dbo].[SpmTag] AS tg WITH (NOLOCK) ON tgdt.TagId = tg.TagId
		WHERE tgdt.ObjectId = @ObjectId
			AND tgdt.[Type] = 8

		SELECT @NestedSp = @NestedSp 
			+ '<ne><sp>' + CAST(rl.StoredProcedureId AS VARCHAR(10)) + '</sp><n>' + dbo.fncEncodeXmlSpecialCharacter(nest.Name) + '</n></ne>'
		FROM [dbo].[SpmSpRelation] AS rl WITH (NOLOCK)
		INNER JOIN [dbo].[SpmStoredProcedure] AS nest WITH (NOLOCK) ON rl.NestedSpId = nest.StoredProcedureId
		WHERE rl.StoredProcedureId = @ObjectId

		SELECT @RedmineIssue = @RedmineIssue 
			+ '<iss><i>' + CAST(iss.IssueId AS VARCHAR(10)) + '</i>'
			+ '<sp>' + CAST(iss.StoredProcedureId AS VARCHAR(10)) + '</sp>'
			+ '<de>' + dbo.fncEncodeXmlSpecialCharacter(e.NickName) + '</de>'
			+ '<a>' + dbo.fncEncodeXmlSpecialCharacter(iss.ActionName) + '</a>'
			+ '<s>' + dbo.fncEncodeXmlSpecialCharacter(CAST(iss.[Status] AS VARCHAR(10))) + '</s>'
			+ '<v>' + CAST(iss.VersionId AS VARCHAR(10)) + '</v>'
			+ '<d>' + dbo.fncEncodeXmlSpecialCharacter(iss.[Description]) + '</d></iss>'
		FROM [dbo].[SpmSpIssue] AS iss WITH (NOLOCK)
		INNER JOIN [dbo].[Employee] AS e WITH (NOLOCK) ON iss.DeveloperId = e.EmployeeId
		WHERE iss.StoredProcedureId = @ObjectId

		SELECT @FunctionSystemProduct = @FunctionSystemProduct 
			+ '<fsp><s>' + dbo.fncEncodeXmlSpecialCharacter(sy.Name) + '</s>'
			+ '<p>' + dbo.fncEncodeXmlSpecialCharacter(ISNULL(pr.Name,'')) + '</p>'
			+ '<f>' + dbo.fncEncodeXmlSpecialCharacter(fn.Name) + '</f></fsp>'
		FROM [dbo].[SpmSpFunction] AS spf WITH (NOLOCK)
		INNER JOIN [dbo].[SpmSystem] AS sy WITH (NOLOCK) ON spf.SystemId = sy.SystemId
		LEFT JOIN [dbo].[SpmFunction] AS fn WITH (NOLOCK) ON spf.FunctionId = fn.FunctionId
		LEFT JOIN [dbo].[SpmProduct] AS pr WITH (NOLOCK) ON spf.ProductId = pr.ProductId
		WHERE spf.StoredProcedureId = @ObjectId

		SELECT @Data = CONCAT(
			'<r><id>'
			,sp.StoredProcedureId, '</id><n>'
			,dbo.fncEncodeXmlSpecialCharacter(sp.Name), '</n><al>'
			,dbo.fncEncodeXmlSpecialCharacter(al.Name), '</al><db>'
			,dbo.fncEncodeXmlSpecialCharacter(db.Name), '</db><ty>'
			,sp.SpTypeId, '</ty><cbw>'
			,sp.CallByWeb, '</cbw><cbe>'
			,sp.CallByExecRef, '</cbe><tgs>'
			,@Tags, '</tgs><d>'
			,dbo.fncEncodeXmlSpecialCharacter(sp.[Description]), '</d><a>'
			,sp.IsActive, '</a><reds>'
			,@RedmineIssue, '</reds><nests>'
			,@NestedSp, '</nests><fsps>'
			,@FunctionSystemProduct, '</fsps></r>'
		)
		FROM [dbo].[SpmStoredProcedure] AS sp WITH (NOLOCK)
		INNER JOIN [dbo].[SpmAliasServer] AS al WITH (NOLOCK) ON sp.AliasServerId = al.AliasServerId
		INNER JOIN [dbo].[SpmDatabase] AS db WITH (NOLOCK) ON sp.DatabaseId = db.DatabaseId
		WHERE sp.StoredProcedureId = @ObjectId
	END
	ELSE IF(@ObjectType = 9)
	BEGIN
		SELECT @Data = CONCAT(
			'<r><n>'
			,dbo.fncEncodeXmlSpecialCharacter(Name),'</n><d>'
			,dbo.fncEncodeXmlSpecialCharacter([Description]),'</d><a>'
			,IsActive,'</a></r>'
		)
		FROM [dbo].[SpmTag] WITH (NOLOCK)
		WHERE TagId = @ObjectId
	END
	ELSE IF(@ObjectType = 10)
	BEGIN
		DECLARE @StoredProcedures VARCHAR(MAX)
		SELECT @StoredProcedures = ''

		SELECT @StoredProcedures = @StoredProcedures
			+ '<sp><id>' + CAST(sp.StoredProcedureId AS VARCHAR(10)) + '</id>'
			+ '<n>' + dbo.fncEncodeXmlSpecialCharacter(sp.Name) + '</n>'
			+ '<al>' + dbo.fncEncodeXmlSpecialCharacter(al.Name) + '</al>'
			+ '<db>' + dbo.fncEncodeXmlSpecialCharacter(db.Name) + '</db>'
			+ '<ty>' + CAST(sp.SpTypeId AS VARCHAR(10)) + '</ty>'
			+ '<cbw>' + CAST(sp.CallByWeb AS VARCHAR(10)) + '</cbw>'
			+ '<cbe>' + CAST(sp.CallByExecRef AS VARCHAR(10))  + '</cbe>'
			+ '<de>' + dbo.fncEncodeXmlSpecialCharacter(e.NickName) + '</de>'
			+ '<a>' + dbo.fncEncodeXmlSpecialCharacter(iss.ActionName) + '</a>'
			+ '<s>' + dbo.fncEncodeXmlSpecialCharacter(CAST(iss.[Status] AS VARCHAR(10))) + '</s>' 
			+ '<v>' + CAST(iss.VersionId AS VARCHAR(10)) + '</v>'
			+ '<d>' + dbo.fncEncodeXmlSpecialCharacter(iss.[Description]) + '</d>'
			+ '</sp>'
		FROM [dbo].[SpmSpIssue] AS iss WITH (NOLOCK)
		INNER JOIN [dbo].[SpmStoredProcedure] AS sp WITH (NOLOCK) ON iss.StoredProcedureId = sp.StoredProcedureId
		INNER JOIN [dbo].[SpmAliasServer] AS al WITH (NOLOCK) ON sp.AliasServerId = al.AliasServerId
		INNER JOIN [dbo].[SpmDatabase] AS db WITH (NOLOCK) ON sp.DatabaseId = db.DatabaseId
		INNER JOIN [dbo].[Employee] AS e WITH (NOLOCK) ON iss.DeveloperId = e.EmployeeId
		WHERE iss.IssueId = @ObjectId
			AND sp.IsDeleted = 0
		
		SELECT @Data = '<r><iss>' + CAST(@ObjectId AS VARCHAR(10)) + '</iss><sps>' + @StoredProcedures + '</sps></r>'
	END
	ELSE IF(@ObjectType = 11)
	BEGIN
		SELECT @Data = CONCAT(
			'<r><n>'
			,dbo.fncEncodeXmlSpecialCharacter(Name),'</n><d>'
			,dbo.fncEncodeXmlSpecialCharacter([Description]),'</d><a>'
			,IsActive,'</a></r>'
		)
		FROM [dbo].[SpmFunctionGroup] WITH (NOLOCK)
		WHERE FunctionGroupId = @ObjectId
	END
    ELSE IF(@ObjectType = 12)
	BEGIN
		SELECT @Data = CONCAT(
			'<r><n>'
			,dbo.fncEncodeXmlSpecialCharacter(Name),'</n><d>'
			,dbo.fncEncodeXmlSpecialCharacter([Description]),'</d><a>'
			,IsActive,'</a></r>'
		)
		FROM [dbo].[SpmSystemGroup] WITH (NOLOCK)
		WHERE GroupId = @ObjectId
	END
    ELSE IF(@ObjectType = 13)
	BEGIN
		DECLARE @StandbyDatabase VARCHAR(5000) = ''
        DECLARE @LookupEnvironmentId INT = 1
		
		SELECT @StandbyDatabase = @StandbyDatabase 
			+ '<sb><dbs>' + dbo.fncEncodeXmlSpecialCharacter(ds.Name) + '</dbs>'
			+ '<db>' + dbo.fncEncodeXmlSpecialCharacter(db.Name) + '</db></sb>'
		FROM [dbo].SpmDatabaseStandbyRelation AS sbr WITH(NOLOCK)
            INNER JOIN dbo.SpmDbServer AS ds WITH(NOLOCK) ON sbr.DbServerId = ds.DbServerId
            INNER JOIN dbo.SpmDatabase AS db WITH(NOLOCK) ON sbr.DatabaseId = db.DatabaseId
		WHERE sbr.StandbyId = @ObjectId
        
		SELECT @Data = CONCAT(
			'<r><al>'
			,dbo.fncEncodeXmlSpecialCharacter(al.Name),'</al><dbs>'
			,dbo.fncEncodeXmlSpecialCharacter(ds.Name + ' (' + ld.Name+ ')'),'</dbs><db>'
            ,dbo.fncEncodeXmlSpecialCharacter(db.Name),'</db><a>'
			,sb.IsActive,'</a><sbs>'
            ,@StandbyDatabase,'</sbs></r>'
		)
		FROM [dbo].SpmDatabaseStandby AS sb WITH (NOLOCK)
            INNER JOIN dbo.SpmAliasServer AS al WITH(NOLOCK) ON sb.AliasServerId = al.AliasServerId
            INNER JOIN dbo.SpmAliasServerEnvironment AS ae WITH(NOLOCK) ON ae.AliasServerId = al.AliasServerId AND ae.EnvironmentId = sb.EnvironmentId
            INNER JOIN dbo.SpmDbServer AS ds WITH(NOLOCK) ON ae.DbServerId = ds.DbServerId
            INNER JOIN dbo.LookupData AS ld WITH(NOLOCK) ON ld.[Value] = ae.EnvironmentId AND ld.LookupId = @LookupEnvironmentId
            INNER JOIN dbo.SpmDatabase AS db WITH(NOLOCK) ON sb.DatabaseId = db.DatabaseId
		WHERE sb.StandbyId = @ObjectId
	END

	RETURN @Data
END



