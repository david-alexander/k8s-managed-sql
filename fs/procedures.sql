USE [master]
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'CreateDB')
BEGIN
	DROP PROCEDURE [dbo].[CreateDB]
END
GO

CREATE PROCEDURE [dbo].[CreateDB]
	@DbName SYSNAME,
	@FirstPort INT,
	@LastPort INT
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @DbNameQuoted SYSNAME = QUOTENAME(@DbName);
	DECLARE @DbNameQuotedString SYSNAME = QUOTENAME(@DbName, '''');

	IF NOT EXISTS (SELECT name FROM master.sys.server_principals WHERE name = @DbName)
	BEGIN
		EXEC ('CREATE LOGIN ' + @DbNameQuoted + ' WITH PASSWORD = ''password'', CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF')
	END

	IF NOT EXISTS (SELECT * FROM master.sys.databases WHERE name = @DbName)
	BEGIN
		EXEC ('CREATE DATABASE ' + @DbNameQuoted + '')
	END

	DECLARE @AllPorts TABLE (port INT);
	WITH Series(a) AS
	(
		SELECT @FirstPort
		UNION ALL
		SELECT a + 1 FROM Series WHERE a <= @LastPort
	)
	INSERT INTO @AllPorts
	SELECT * FROM Series;

	IF NOT EXISTS (SELECT * FROM master.sys.tcp_endpoints WHERE name = @DbName)
	BEGIN
		DECLARE @Port INT = (SELECT TOP 1 port FROM @AllPorts WHERE port NOT IN (SELECT port FROM master.sys.tcp_endpoints));
		EXEC ('CREATE ENDPOINT ' + @DbNameQuoted + ' AS TCP (LISTENER_PORT = ' + @Port + ') FOR TSQL ()')
	END

	EXEC ('ALTER ENDPOINT ' + @DbNameQuoted + ' STATE = STARTED');
	EXEC ('GRANT CONNECT ON ENDPOINT::' + @DbNameQuoted + ' TO ' + @DbNameQuoted);

	EXEC ('USE ' + @DbNameQuoted + '; IF EXISTS (SELECT * FROM ' + @DbNameQuoted + '.sys.database_principals WHERE name = ' + @DbNameQuotedString + ' AND NOT (type = ''S'' AND authentication_type = 1)) BEGIN DROP USER ' + @DbNameQuoted + '; END')
	EXEC ('USE ' + @DbNameQuoted + '; IF NOT EXISTS (SELECT * FROM ' + @DbNameQuoted + '.sys.database_principals WHERE name = ' + @DbNameQuotedString + ' AND (type = ''S'' AND authentication_type = 1)) BEGIN CREATE USER ' + @DbNameQuoted + ' FOR LOGIN ' + @DbNameQuoted + '; END')
	
	EXEC ('USE ' + @DbNameQuoted + '; ALTER USER ' + @DbNameQuoted + ' WITH LOGIN = ' + @DbNameQuoted)
	EXEC ('USE ' + @DbNameQuoted + '; ALTER ROLE [db_owner] ADD MEMBER ' + @DbNameQuoted)

	SELECT port FROM master.sys.tcp_endpoints WHERE name = @DbName
END
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'RemoveDB')
BEGIN
	DROP PROCEDURE [dbo].[RemoveDB]
END
GO

CREATE PROCEDURE [dbo].[RemoveDB]
	@DbName SYSNAME
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @DbNameQuoted SYSNAME = QUOTENAME(@DbName);
	DECLARE @DbNameQuotedString SYSNAME = QUOTENAME(@DbName, '''');

	IF EXISTS (SELECT name FROM master.sys.server_principals WHERE name = @DbName)
	BEGIN
		EXEC ('DROP LOGIN ' + @DbNameQuoted)
	END

	IF EXISTS (SELECT * FROM master.sys.databases WHERE name = @DbName)
	BEGIN
		EXEC ('DROP DATABASE ' + @DbNameQuoted + '')
	END

	IF EXISTS (SELECT * FROM master.sys.tcp_endpoints WHERE name = @DbName)
	BEGIN
		EXEC ('DROP ENDPOINT ' + @DbNameQuoted)
	END
END
GO

GRANT CONNECT ON ENDPOINT::[TSQL Default TCP] TO [public];
GO
