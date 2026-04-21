using Amazon.Lambda.APIGatewayEvents;
using Amazon.Lambda.Core;
using Amazon.Lambda.Serialization.SystemTextJson;
using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Threading.Tasks;
using TechChallenge5.Lambda.Auth.Models;
using TechChallenge5.Lambda.Auth.Repositories;
using TechChallenge5.Lambda.Auth.Services;

[assembly: LambdaSerializer(typeof(DefaultLambdaJsonSerializer))]

namespace TechChallenge5.Lambda.Auth.Handlers;

public class AuthUsuarioHandler
{
    private readonly AuthenticationService _authenticationService;

    public AuthUsuarioHandler()
    {
        var dbConnectionString = Environment.GetEnvironmentVariable("DB_CONNECTION_STRING")
            ?? throw new InvalidOperationException("DB_CONNECTION_STRING nao configurada");

        var jwtSecret = Environment.GetEnvironmentVariable("JWT_SECRET")
            ?? throw new InvalidOperationException("JWT_SECRET nao configurada");

        var jwtIssuer = Environment.GetEnvironmentVariable("JWT_ISSUER")
            ?? throw new InvalidOperationException("JWT_ISSUER nao configurada");

        var jwtAudience = Environment.GetEnvironmentVariable("JWT_AUDIENCE")
            ?? throw new InvalidOperationException("JWT_AUDIENCE nao configurada");

        var usuarioRepository = new UsuarioRepository(dbConnectionString);
        var jwtService = new JwtService(jwtSecret, jwtIssuer, jwtAudience, expiresInHours: 8);
        _authenticationService = new AuthenticationService(usuarioRepository, jwtService);
    }

    public async Task<APIGatewayProxyResponse> HandleLoginAsync(APIGatewayProxyRequest request, ILambdaContext context)
    {
        try
        {
            LambdaLogger.Log("[Auth] Requisicao de login recebida");

            if (!string.Equals(request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase))
            {
                return BadRequest("Metodo HTTP deve ser POST");
            }

            LoginUsuarioRequest? loginRequest;
            try
            {
                loginRequest = JsonSerializer.Deserialize<LoginUsuarioRequest>(
                    request.Body,
                    new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
            }
            catch (JsonException)
            {
                return BadRequest("Corpo da requisicao invalido. Esperado: { \"usuario\": \"admin\", \"senha\": \"Admin@123\" }");
            }

            if (loginRequest == null ||
                string.IsNullOrWhiteSpace(loginRequest.Usuario) ||
                string.IsNullOrWhiteSpace(loginRequest.Senha))
            {
                return BadRequest("Usuario e senha sao obrigatorios");
            }

            LambdaLogger.Log($"[Auth] Tentando autenticar usuario {MaskUsuario(loginRequest.Usuario)}");

            var (success, response, errorMessage) =
                await _authenticationService.AuthenticateAsync(loginRequest.Usuario, loginRequest.Senha);

            if (!success || response == null)
            {
                LambdaLogger.Log($"[Auth] Falha de autenticacao para {MaskUsuario(loginRequest.Usuario)}");
                return Unauthorized(errorMessage ?? "Credenciais invalidas");
            }

            LambdaLogger.Log($"[Auth] Usuario autenticado com sucesso: {MaskUsuario(loginRequest.Usuario)}");
            return Ok(response);
        }
        catch (Exception ex)
        {
            LambdaLogger.Log($"[Auth] Erro nao tratado: {ex.Message}");
            return InternalServerError("Erro interno ao processar requisicao");
        }
    }

    private static APIGatewayProxyResponse Ok<T>(T data)
    {
        return CriarResposta(200, JsonSerializer.Serialize(data));
    }

    private static APIGatewayProxyResponse BadRequest(string message)
    {
        return CriarResposta(400, JsonSerializer.Serialize(new ErroAutenticacao("INVALID_REQUEST", message)));
    }

    private static APIGatewayProxyResponse Unauthorized(string message)
    {
        return CriarResposta(401, JsonSerializer.Serialize(new ErroAutenticacao("UNAUTHORIZED", message)));
    }

    private static APIGatewayProxyResponse InternalServerError(string message)
    {
        return CriarResposta(500, JsonSerializer.Serialize(new ErroAutenticacao("INTERNAL_ERROR", message)));
    }

    private static APIGatewayProxyResponse CriarResposta(int statusCode, string body)
    {
        return new APIGatewayProxyResponse
        {
            StatusCode = statusCode,
            Body = body,
            Headers = new Dictionary<string, string>
            {
                { "Content-Type", "application/json" },
                { "Access-Control-Allow-Origin", "*" },
                { "Access-Control-Allow-Headers", "Content-Type,Authorization" },
                { "Access-Control-Allow-Methods", "POST,OPTIONS" }
            }
        };
    }

    private static string MaskUsuario(string usuario)
    {
        if (string.IsNullOrWhiteSpace(usuario))
        {
            return "***";
        }

        if (usuario.Length <= 2)
        {
            return "**";
        }

        return $"{usuario[..2]}***";
    }
}

