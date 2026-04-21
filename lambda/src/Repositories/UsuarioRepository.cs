using MySqlConnector;
using System;
using System.Threading.Tasks;
using TechChallenge5.Lambda.Auth.Models;

namespace TechChallenge5.Lambda.Auth.Repositories;

public class UsuarioRepository
{
    private readonly string _connectionString;
    private readonly string _tableUsuarios;

    public UsuarioRepository(string connectionString)
    {
        _connectionString = connectionString ?? throw new ArgumentNullException(nameof(connectionString));
        _tableUsuarios = Environment.GetEnvironmentVariable("TABLE_USUARIOS") ?? "usuarios";
    }

    public async Task<Usuario?> GetByUsuarioAsync(string usuario)
    {
        await using var connection = new MySqlConnection(_connectionString);
        await connection.OpenAsync();

        var query = $@"
            SELECT usuario_id, usuario_login, nome, senha_hash, ativo, ultimo_login
            FROM {_tableUsuarios}
            WHERE usuario_login = @Usuario
              AND ativo = 1
            LIMIT 1;";

        await using var command = new MySqlCommand(query, connection);
        command.Parameters.AddWithValue("@Usuario", usuario);

        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
        {
            return null;
        }

        return new Usuario
        {
            UsuarioId = reader.GetGuid("usuario_id"),
            UsuarioLogin = reader.GetString("usuario_login"),
            Nome = reader.GetString("nome"),
            SenhaHash = reader.GetString("senha_hash"),
            Ativo = reader.GetBoolean("ativo"),
            UltimoLogin = reader.IsDBNull(reader.GetOrdinal("ultimo_login"))
                ? null
                : reader.GetDateTime("ultimo_login")
        };
    }

    public async Task AtualizarUltimoLoginAsync(Guid usuarioId)
    {
        await using var connection = new MySqlConnection(_connectionString);
        await connection.OpenAsync();

        var query = $@"
            UPDATE {_tableUsuarios}
               SET ultimo_login = @UltimoLogin
             WHERE usuario_id = @UsuarioId;";

        await using var command = new MySqlCommand(query, connection);
        command.Parameters.AddWithValue("@UltimoLogin", DateTime.UtcNow);
        command.Parameters.AddWithValue("@UsuarioId", usuarioId);

        await command.ExecuteNonQueryAsync();
    }
}

