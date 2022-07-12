USE [master]
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'CreateDB')
BEGIN
	DROP PROCEDURE [dbo].[CreateDB]
END
GO

CREATE PROCEDURE [dbo].[CreateDB]
	@DbName SYSNAME,
	@Password NVARCHAR(MAX),
	@FirstPort INT,
	@LastPort INT
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @DbNameQuoted SYSNAME = QUOTENAME(@DbName);
	DECLARE @DbNameQuotedString SYSNAME = QUOTENAME(@DbName, '''');
	DECLARE @PasswordQuotedString SYSNAME = QUOTENAME(@Password, '''');

	IF NOT EXISTS (SELECT name FROM master.sys.server_principals WHERE name = @DbName)
	BEGIN
		EXEC ('CREATE LOGIN ' + @DbNameQuoted + ' WITH PASSWORD = ' + @PasswordQuotedString + ', CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF')
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

IF EXISTS (SELECT * FROM sys.credentials WHERE NAME = '__BACKUPS_AZURE_BLOB_CONTAINER_URL__')
BEGIN
	DROP CREDENTIAL [__BACKUPS_AZURE_BLOB_CONTAINER_URL__]
END
GO

CREATE CREDENTIAL [__BACKUPS_AZURE_BLOB_CONTAINER_URL__] WITH IDENTITY = 'Shared Access Signature', SECRET = '__BACKUPS_AZURE_BLOB_CONTAINER_SAS__'
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'Backup')
BEGIN
	DROP PROCEDURE [dbo].[Backup]
END
GO

CREATE PROCEDURE [Backup]
WITH EXECUTE AS OWNER
AS
BEGIN
	DECLARE @Sql NVARCHAR(MAX) = (SELECT 'BACKUP LOG [' + ORIGINAL_LOGIN() + '] TO URL = N''__BACKUPS_AZURE_BLOB_CONTAINER_URL__/' + ORIGINAL_LOGIN() + '-TransactionLog-' + CONVERT(NVARCHAR(MAX), GETUTCDATE(), 126) + 'Z.bak'';');
	EXEC(@Sql);
END
GO

GRANT EXEC ON [Backup] TO PUBLIC
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'FullBackup')
BEGIN
	DROP PROCEDURE [dbo].[FullBackup]
END
GO

CREATE PROCEDURE [FullBackup]
WITH EXECUTE AS OWNER
AS
BEGIN
	DECLARE @Sql NVARCHAR(MAX) = (SELECT 'BACKUP DATABASE [' + ORIGINAL_LOGIN() + '] TO URL = N''__BACKUPS_AZURE_BLOB_CONTAINER_URL__/' + ORIGINAL_LOGIN() + '-Full-' + CONVERT(NVARCHAR(MAX), GETUTCDATE(), 126) + 'Z.bak'';');
	EXEC(@Sql);
END
GO

GRANT EXEC ON [FullBackup] TO PUBLIC
GO

CREATE PROCEDURE [RestoreSnapshot]
	@SnapshotID NVARCHAR(MAX)
WITH EXECUTE AS OWNER
AS
BEGIN
	DECLARE @Sql NVARCHAR(MAX) = (SELECT 'RESTORE DATABASE [' + ORIGINAL_LOGIN() + '] FROM DATABASE_SNAPSHOT = ''' + ORIGINAL_LOGIN() + '_ss_' + @SnapshotID + ''';');
	EXEC(@Sql);
END
GO

GRANT EXEC ON [RestoreSnapshot] TO PUBLIC
GO

CREATE PROCEDURE [CreateSnapshot]
	@SnapshotID NVARCHAR(MAX)
WITH EXECUTE AS OWNER
AS
BEGIN
	DECLARE @Sql NVARCHAR(MAX) = (SELECT 'CREATE DATABASE [' + ORIGINAL_LOGIN() + '_ss_' + @SnapshotID + '] ON ( NAME = ''dbo'', FILENAME = ''/' + ORIGINAL_LOGIN() + '_ss_' + @SnapshotID + ''' ) AS SNAPSHOT OF [' + ORIGINAL_LOGIN() + ']');
	EXEC(@Sql);
END
GO

GRANT EXEC ON [CreateSnapshot] TO PUBLIC
GO

CREATE PROCEDURE [DeleteSnapshot]
	@SnapshotID NVARCHAR(MAX)
WITH EXECUTE AS OWNER
AS
BEGIN
	DECLARE @Sql NVARCHAR(MAX) = (SELECT 'DROP DATABASE [' + ORIGINAL_LOGIN() + '_ss_' + @SnapshotID + ']');
	EXEC(@Sql);
END
GO

GRANT EXEC ON [DeleteSnapshot] TO PUBLIC
GO


ALTER DATABASE [master] SET TRUSTWORTHY ON
GO
