namespace Tc5.DbInit.Models;

public record DatabaseInitializationRequest(
    string SchemaAutenticacao,
    string SchemaUpload,
    string SchemaProcessamento,
    string SchemaRelatorio,
    string UsuarioInicial,
    string NomeInicial,
    string SenhaHashInicial
);
