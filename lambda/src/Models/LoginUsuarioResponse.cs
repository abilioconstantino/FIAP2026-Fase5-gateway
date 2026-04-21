using System;

namespace TechChallenge5.Lambda.Auth.Models;

public record LoginUsuarioResponse(
    string Token,
    int ExpiresIn,
    string TokenType,
    UsuarioAutenticado Usuario
);

public record UsuarioAutenticado(
    Guid Id,
    string Usuario,
    string Nome
);

