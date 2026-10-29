# Sistema de Gestão Bancária

Aplicação didática para gerir clientes, contas, operações, cartões, empréstimos e funcionários. Foi concebida para execução local em Windows 11 com PHP e SQLite. Usa exclusivamente dados fictícios.

## Âmbito

Inclui criação e consulta de clientes, abertura de contas, depósitos, levantamentos e transferências, registo e bloqueio de cartões, pedidos e decisão de empréstimos, gestão de funcionários, painel de resumo e alertas de operações de valor elevado. Os alertas são indicadores para revisão manual; não constituem um sistema de deteção de fraude de produção.

Não inclui autenticação, integração com redes bancárias, processamento de cartões, crédito real, contabilidade regulamentar, notificações, múltiplos bancos ou utilização de dados pessoais reais. Não é adequado para produção.

## Pré-requisitos

- Windows 11.
- PHP 8.2 ou superior com `pdo_sqlite` e `sqlite3` ativos (`php -m` deve listar ambas).
- PowerShell ou terminal Windows.

Não são necessárias dependências PHP externas nem um servidor de base de dados separado.

## Instalação e execução

1. Instale PHP 8.2+ e confirme que as extensões SQLite estão ativas em `php -m`. Se os DLLs estiverem instalados mas desativados, configure no `php.ini`:

```ini
extension=pdo_sqlite
extension=sqlite3
```

Em algumas instalações Windows também é necessário configurar `extension_dir` para a pasta `ext` da instalação PHP.
2. Abra PowerShell na pasta do projeto.
3. Execute:

```powershell
php -S 127.0.0.1:8000 -t public
```

4. Abra `http://127.0.0.1:8000` no navegador.

Na primeira execução, a aplicação cria `storage/banco.sqlite` e carrega dados de demonstração. A pasta `storage` deve ser gravável pelo utilizador que executa PHP e não deve ser publicada na Web. Para repor a demonstração, pare o servidor e elimine `storage/banco.sqlite`; a base de dados será recriada no arranque seguinte.

## Testes

Com PHP e SQLite instalados:

```powershell
php tests/run.php
```

Os testes exercitam regras de domínio usando uma base de dados SQLite temporária. Na execução de preparação foi usado PHP 8.5.12 com `pdo_sqlite` e `sqlite3` carregados por configuração temporária. Resultado observado: 18 passaram, 0 falharam. A validação de sintaxe e uma verificação HTTP local também foram executadas.

## Organização

```text
app/
  BankService.php       regras e operações bancárias
  Database.php          ligação, esquema e dados fictícios
  helpers.php           escape HTML, CSRF e mensagens
public/
  index.php             páginas, formulários e encaminhamento
  assets/app.css        apresentação
  assets/app.js         confirmação e interações pequenas
docs/
  Relatorio-SGB.docx    relatório final sobre o modelo fornecido
  relatorio-tecnico.md  versão textual do relatório
  diagramas/            fontes PlantUML
  capturas/             capturas reais da aplicação
  registo-testes.txt    saída das verificações executadas
database/
  schema.sql            esquema SQLite
tests/run.php           testes de regras de domínio
tools/                  scripts de geração e verificação do relatório
storage/                base de dados local criada no primeiro arranque
```

O relatório foi preenchido sobre a cópia incluída em `docs/template/ModeloSWE-2627.docx`. Para o regenerar, executar `powershell -ExecutionPolicy Bypass -File tools/fill-report.ps1`.

## Segurança e dados

Os formulários usam token contra CSRF, validação no servidor, consultas PDO parametrizadas e escape de conteúdo HTML. As operações financeiras são atómicas e impedem saldo negativo. Os alertas são gerados para operações a partir de 3 000 EUR e para atividade diária acima do limiar definido no serviço. Não há credenciais no código, porque a aplicação não implementa autenticação. Os registos de exemplo são inventados.

SQLite é uma decisão de simplicidade adequada a uma demonstração local de estudante. Não oferece as garantias operacionais, disponibilidade, controlo de acesso e auditoria necessárias para um banco real.

## Versão do código

Versão local `v1.0.0`. O repositório foi preparado localmente; não foi possível sincronizar com o URL indicado devido à indisponibilidade da ligação externa.
