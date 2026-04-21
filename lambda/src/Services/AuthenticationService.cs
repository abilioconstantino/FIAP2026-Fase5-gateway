using System;
using System.Threading.Tasks;
using TechChallenge5.Lambda.Auth.Models;
using TechChallenge5.Lambda.Auth.Repositories;

namespace TechChallenge5.Lambda.Auth.Services;

public class AuthenticationService
{
    private readonly UsuarioRepository _usuarioRepository;
    private readonly JwtService _jwtService;

    public AuthenticationService(UsuarioRepository usuarioRepository, JwtService jwtService)
    {
        _usuarioRepository = usuarioRepository ?? throw new ArgumentNullException(nameof(usuarioRepository));
        _jwtService = jwtService ?? throw new ArgumentNullException(nameof(jwtService));
    }

    public async Task<(bool Success, LoginUsuarioResponse? Response, string? ErrorMessage)> AuthenticateAsync(string usuario, string senha)
    {
        try
        {
            var usuarioEncontrado = await _usuarioRepository.GetByUsuarioAsync(usuario);
            if (usuarioEncontrado == null || !usuarioEncontrado.Ativo)
            {
                return (false, null, "Credenciais invalidas");
            }

            if (!BCrypt.Net.BCrypt.Verify(senha, usuarioEncontrado.SenhaHash))
            {
                return (false, null, "Credenciais invalidas");
            }

            await _usuarioRepository.AtualizarUltimoLoginAsync(usuarioEncontrado.UsuarioId);

            var token = _jwtService.GenerateToken(
                usuarioEncontrado.UsuarioId,
                usuarioEncontrado.UsuarioLogin,
                usuarioEncontrado.Nome);

            var response = new LoginUsuarioResponse(
                Token: token,
                ExpiresIn: _jwtService.GetExpiresInSeconds(),
                TokenType: "Bearer",
                Usuario: new UsuarioAutenticado(
                    Id: usuarioEncontrado.UsuarioId,
                    Usuario: usuarioEncontrado.UsuarioLogin,
                    Nome: usuarioEncontrado.Nome));

            return (true, response, null);
        }
        catch (Exception)
        {
            return (false, null, "Erro interno ao processar autenticacao");
        }
    }
}

