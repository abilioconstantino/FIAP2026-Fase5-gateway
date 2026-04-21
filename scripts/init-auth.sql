-- Este arquivo representa o bootstrap executado automaticamente pelo
-- lambda inicializador de banco provisionado pelo Terraform.

CREATE DATABASE IF NOT EXISTS auth_db;
CREATE DATABASE IF NOT EXISTS upload_db;
CREATE DATABASE IF NOT EXISTS processamento_db;
CREATE DATABASE IF NOT EXISTS relatorio_db;

USE auth_db;

CREATE TABLE IF NOT EXISTS usuarios (
    usuario_id CHAR(36) NOT NULL PRIMARY KEY,
    usuario_login VARCHAR(100) NOT NULL UNIQUE,
    nome VARCHAR(150) NOT NULL,
    senha_hash VARCHAR(255) NOT NULL,
    ativo TINYINT(1) NOT NULL DEFAULT 1,
    ultimo_login DATETIME NULL,
    criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Usuario inicial para facilitar os testes de integracao do gateway.
-- Credenciais de referencia:
-- usuario: admin
-- senha: Admin@123456
INSERT INTO usuarios (
    usuario_id,
    usuario_login,
    nome,
    senha_hash,
    ativo
)
VALUES (
    '11111111-1111-1111-1111-111111111111',
    'admin',
    'Administrador Gateway',
    '$2a$11$CZNm30/WKAOfYODnrHtfZerNKp8ad6mdDMCcOqwbHMcJ4wmH.OyQW',
    1
)
ON DUPLICATE KEY UPDATE
    nome = VALUES(nome),
    senha_hash = VALUES(senha_hash),
    ativo = VALUES(ativo);
