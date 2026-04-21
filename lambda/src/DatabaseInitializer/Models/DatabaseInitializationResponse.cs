namespace Tc5.DbInit.Models;

public record DatabaseInitializationResponse(
    bool Sucesso,
    string Mensagem
);
