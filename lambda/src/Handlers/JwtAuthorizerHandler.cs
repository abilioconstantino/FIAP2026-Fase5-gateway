using Amazon.Lambda.APIGatewayEvents;
using Amazon.Lambda.Core;
using Amazon.Lambda.Serialization.SystemTextJson;
using Microsoft.IdentityModel.Tokens;
using System;
using System.Collections.Generic;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

[assembly: LambdaSerializer(typeof(DefaultLambdaJsonSerializer))]

namespace TechChallenge5.Lambda.Authorizer.Handlers;

public class JwtAuthorizerHandler
{
    private readonly string _jwtSecret;
    private readonly string _jwtIssuer;
    private readonly string _jwtAudience;
    private readonly JwtSecurityTokenHandler _tokenHandler;

    public JwtAuthorizerHandler()
    {
        _jwtSecret = Environment.GetEnvironmentVariable("JWT_SECRET")
            ?? throw new InvalidOperationException("JWT_SECRET nao configurada");

        _jwtIssuer = Environment.GetEnvironmentVariable("JWT_ISSUER")
            ?? throw new InvalidOperationException("JWT_ISSUER nao configurada");

        _jwtAudience = Environment.GetEnvironmentVariable("JWT_AUDIENCE")
            ?? throw new InvalidOperationException("JWT_AUDIENCE nao configurada");

        _tokenHandler = new JwtSecurityTokenHandler();
    }

    public APIGatewayCustomAuthorizerResponse HandleAuthorization(
        APIGatewayCustomAuthorizerRequest request,
        ILambdaContext context)
    {
        try
        {
            LambdaLogger.Log($"[Authorizer] Validando token para {request.MethodArn}");

            var token = ExtractToken(request.AuthorizationToken);
            if (string.IsNullOrWhiteSpace(token))
            {
                LambdaLogger.Log("[Authorizer] Token nao informado");
                return GenerateDenyPolicy("anonimo", request.MethodArn);
            }

            var principal = ValidateToken(token);
            if (principal == null)
            {
                LambdaLogger.Log("[Authorizer] Token invalido");
                return GenerateDenyPolicy("anonimo", request.MethodArn);
            }

            var usuarioId = principal.FindFirst(JwtRegisteredClaimNames.Sub)?.Value ?? "usuario";
            LambdaLogger.Log($"[Authorizer] Token valido para usuario {usuarioId}");

            return GenerateAllowPolicy(usuarioId, request.MethodArn);
        }
        catch (Exception ex)
        {
            LambdaLogger.Log($"[Authorizer] Erro ao validar token: {ex.Message}");
            return GenerateDenyPolicy("anonimo", request.MethodArn);
        }
    }

    private string ExtractToken(string authorizationToken)
    {
        if (string.IsNullOrWhiteSpace(authorizationToken))
        {
            return string.Empty;
        }

        return authorizationToken.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase)
            ? authorizationToken[7..]
            : authorizationToken;
    }

    private ClaimsPrincipal? ValidateToken(string token)
    {
        try
        {
            var validationParameters = new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,
                IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwtSecret)),
                ValidateIssuer = true,
                ValidIssuer = _jwtIssuer,
                ValidateAudience = true,
                ValidAudience = _jwtAudience,
                ValidateLifetime = true,
                ClockSkew = TimeSpan.Zero
            };

            return _tokenHandler.ValidateToken(token, validationParameters, out _);
        }
        catch (Exception ex)
        {
            LambdaLogger.Log($"[Authorizer] Falha na validacao do token: {ex.Message}");
            return null;
        }
    }

    private APIGatewayCustomAuthorizerResponse GenerateAllowPolicy(string principalId, string resource)
    {
        return CreatePolicy(principalId, "Allow", resource);
    }

    private APIGatewayCustomAuthorizerResponse GenerateDenyPolicy(string principalId, string resource)
    {
        return CreatePolicy(principalId, "Deny", resource);
    }

    private APIGatewayCustomAuthorizerResponse CreatePolicy(string principalId, string effect, string resource)
    {
        return new APIGatewayCustomAuthorizerResponse
        {
            PrincipalID = principalId,
            PolicyDocument = new APIGatewayCustomAuthorizerPolicy
            {
                Version = "2012-10-17",
                Statement = new List<APIGatewayCustomAuthorizerPolicy.IAMPolicyStatement>
                {
                    new APIGatewayCustomAuthorizerPolicy.IAMPolicyStatement
                    {
                        Effect = effect,
                        Action = new HashSet<string> { "execute-api:Invoke" },
                        Resource = new HashSet<string> { GetResourceArn(resource) }
                    }
                }
            }
        };
    }

    private string GetResourceArn(string methodArn)
    {
        var parts = methodArn.Split('/');
        return parts.Length >= 3
            ? $"{parts[0]}/{parts[1]}/*/*"
            : methodArn;
    }
}
