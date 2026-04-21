using System;

namespace TechChallenge5.Lambda.Auth.Models;

public class Usuario
{
    public Guid UsuarioId { get; set; }
    public string UsuarioLogin { get; set; } = string.Empty;
    public string Nome { get; set; } = string.Empty;
    public string SenhaHash { get; set; } = string.Empty;
    public bool Ativo { get; set; }
    public DateTime? UltimoLogin { get; set; }
}

