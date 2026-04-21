using Amazon.Lambda.Core;
using Amazon.Lambda.Serialization.SystemTextJson;
using MySqlConnector;
using System;
using System.Threading.Tasks;
using Tc5.DbInit.Models;

[assembly: LambdaSerializer(typeof(DefaultLambdaJsonSerializer))]

namespace Tc5.DbInit.Handlers;

public class DatabaseInitializerHandler
{
    private readonly string _dbServer;
    private readonly string _dbPort;
    private readonly string _dbUser;
    private readonly string _dbPassword;

    public DatabaseInitializerHandler()
    {
        _dbServer = Environment.GetEnvironmentVariable("DB_SERVER")
            ?? throw new InvalidOperationException("DB_SERVER nao configurada");

        _dbPort = Environment.GetEnvironmentVariable("DB_PORT")
            ?? "3306";

        _dbUser = Environment.GetEnvironmentVariable("DB_USER")
            ?? throw new InvalidOperationException("DB_USER nao configurada");

        _dbPassword = Environment.GetEnvironmentVariable("DB_PASSWORD")
            ?? throw new InvalidOperationException("DB_PASSWORD nao configurada");
    }

    public async Task<DatabaseInitializationResponse> HandleAsync(
        DatabaseInitializationRequest request,
        ILambdaContext context)
    {
        if (request == null)
        {
            throw new ArgumentNullException(nameof(request));
        }

        LambdaLogger.Log("[DbInit] Iniciando preparacao do banco compartilhado");

        var connectionStringAdmin =
            $"Server={_dbServer};Port={_dbPort};User ID={_dbUser};Password={_dbPassword};SslMode=Preferred;";

        await using var adminConnection = new MySqlConnection(connectionStringAdmin);
        await adminConnection.OpenAsync();

        await ExecuteNonQueryAsync(adminConnection, $"CREATE DATABASE IF NOT EXISTS `{request.SchemaAutenticacao}`;");
        await ExecuteNonQueryAsync(adminConnection, $"CREATE DATABASE IF NOT EXISTS `{request.SchemaUpload}`;");
        await ExecuteNonQueryAsync(adminConnection, $"CREATE DATABASE IF NOT EXISTS `{request.SchemaProcessamento}`;");
        await ExecuteNonQueryAsync(adminConnection, $"CREATE DATABASE IF NOT EXISTS `{request.SchemaRelatorio}`;");

        await using var authConnection = new MySqlConnection(
            $"{connectionStringAdmin}Database={request.SchemaAutenticacao};");
        await authConnection.OpenAsync();

        const string createUsuariosTable = @"
            CREATE TABLE IF NOT EXISTS usuarios (
                usuario_id CHAR(36) NOT NULL PRIMARY KEY,
                usuario_login VARCHAR(100) NOT NULL UNIQUE,
                nome VARCHAR(150) NOT NULL,
                senha_hash VARCHAR(255) NOT NULL,
                ativo TINYINT(1) NOT NULL DEFAULT 1,
                ultimo_login DATETIME NULL,
                criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            );";

        await ExecuteNonQueryAsync(authConnection, createUsuariosTable);

        const string upsertUsuarioInicial = @"
            INSERT INTO usuarios (
                usuario_id,
                usuario_login,
                nome,
                senha_hash,
                ativo
            ) VALUES (
                '11111111-1111-1111-1111-111111111111',
                @UsuarioInicial,
                @NomeInicial,
                @SenhaHashInicial,
                1
            )
            ON DUPLICATE KEY UPDATE
                nome = VALUES(nome),
                senha_hash = VALUES(senha_hash),
                ativo = VALUES(ativo);";

        await using (var command = new MySqlCommand(upsertUsuarioInicial, authConnection))
        {
            command.Parameters.AddWithValue("@UsuarioInicial", request.UsuarioInicial);
            command.Parameters.AddWithValue("@NomeInicial", request.NomeInicial);
            command.Parameters.AddWithValue("@SenhaHashInicial", request.SenhaHashInicial);
            await command.ExecuteNonQueryAsync();
        }

        LambdaLogger.Log("[DbInit] Banco compartilhado preparado com sucesso");

        return new DatabaseInitializationResponse(
            Sucesso: true,
            Mensagem: "Schemas e usuario inicial garantidos com sucesso");
    }

    private static async Task ExecuteNonQueryAsync(MySqlConnection connection, string sql)
    {
        await using var command = new MySqlCommand(sql, connection);
        await command.ExecuteNonQueryAsync();
    }
}
