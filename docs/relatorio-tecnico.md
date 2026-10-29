# Sistema de Gestão Bancária — Relatório técnico

**Relatório de Desenvolvimento de Software · ISMT · Engenharia de Software · 2026–27**  
**Versão:** 1.0 · **Data:** 2026-10-29  
**Autor:** Thaniel Jorge Guimarães Pedro · **N.º:** 13658 · **E-mail:** por preencher  
**Docente:** por preencher  
**Repositório indicado:** <https://github.com/supernova17-art/Sistema-de-gestao-Bancaria-.git>  
**Versão de código:** tag local `v1.0.0`; não sincronizada com o repositório remoto.

## Controlo do documento

| Versão | Data | Código | Alterações | Secções |
|---|---|---|---|---|
| 1.0 | 2026-10-29 | v1.0.0 (tag local) | Relatório final da versão funcional preparada localmente. | 1–10, anexos |

## Resumo

Este projeto responde à necessidade académica de organizar operações básicas de uma instituição bancária. A aplicação permite registar clientes, abrir contas, executar depósitos, levantamentos e transferências, emitir e bloquear cartões, acompanhar pedidos de empréstimo, registar funcionários e rever alertas de risco. A solução usa PHP 8.5, HTML, CSS, JavaScript e SQLite através de PDO. A arquitetura mantém a apresentação em páginas PHP, as regras de domínio no serviço BankService e a persistência numa base de dados relacional com restrições e consultas parametrizadas. A versão 1.0 inclui dados fictícios, validação no servidor, proteção CSRF e testes automatizados das regras principais. Foram executadas dezoito verificações automatizadas, todas com resultado positivo, além de verificações HTTP locais. A aplicação é uma demonstração didática e não é adequada a operações bancárias reais.

**Palavras-chave:** banca; PHP; SQLite; operações financeiras; testes de software.

## 1. Introdução

### 1.1 Problema e objetivo

Uma instituição bancária gere clientes, contas e operações que precisam de ficar relacionadas e consultáveis. Registos inconsistentes podem permitir operações inválidas, como levantamentos acima do saldo. O projeto demonstra regras de validação e persistência numa aplicação local de pequena dimensão.

O objetivo deste projeto é desenvolver uma aplicação didática que registe informação bancária fictícia e aplique regras básicas de gestão de contas e operações.

### 1.2 Utilizadores previstos

| Tipo | Descrição | Objetivos principais |
|---|---|---|
| Operador | Utilizador local que regista atividade corrente. | Consultar clientes e contas; registar operações; emitir cartões; abrir pedidos; rever alertas. |
| Gestor | Utilizador local que regista funcionários e decide pedidos. | Consultar o painel; registar funcionários; aprovar ou recusar empréstimos. |

Os perfis são usados para representar atores no modelo. A aplicação não implementa autenticação nem autorização por perfil.

### 1.3 Âmbito

| Incluído | Fora do âmbito |
|---|---|
| Clientes, funcionários e contas; depósitos, levantamentos e transferências; cartões demonstrativos; pedidos e decisão de empréstimos; painel, histórico e alertas. | Autenticação; integração com sistemas interbancários; pagamentos com cartão reais; juros e planos de amortização; operação em produção; múltiplas instituições; relatórios regulamentares. |

### 1.4 Organização do documento

O Capítulo 2 descreve o contexto e os pressupostos. O Capítulo 3 define os requisitos. Os Capítulos 4 e 5 apresentam os casos de uso e as histórias de utilizador. O Capítulo 6 documenta os modelos e as regras de negócio. O Capítulo 7 descreve a arquitetura e a implementação. O Capítulo 8 regista testes e rastreabilidade. Os Capítulos 9 e 10 apresentam a demonstração e as limitações.

## 2. Análise de Contexto

### 2.1 Situação atual

Não foi observada uma instituição bancária real nem um processo operacional existente. O cenário é um pressuposto académico: o operador necessita de um registo central para consultar contas e operações de demonstração. A aplicação não pretende representar processos regulamentares ou de produção.

### 2.2 Necessidades dos utilizadores

| ID | Necessidade | Utilizador | Fonte / estado |
|---|---|---|---|
| N01 | Registar clientes e consultar os respetivos dados de contacto. | Operador | Requisitos fornecidos no enunciado. |
| N02 | Criar contas associadas a um cliente e consultar o saldo. | Operador | Requisitos fornecidos no enunciado. |
| N03 | Registar depósitos, levantamentos e transferências com saldo coerente. | Operador | Requisitos fornecidos; regra de saldo assumida. |
| N04 | Emitir e bloquear cartões de demonstração associados a contas. | Operador | Requisitos fornecidos; sem processamento de pagamentos. |
| N05 | Registar pedidos e permitir a decisão por funcionário. | Operador / Gestor | Requisitos fornecidos; decisão didática. |
| N06 | Registar funcionários e consultar um resumo da atividade. | Gestor | Requisitos fornecidos. |
| N07 | Sinalizar operações de valor ou volume diário elevado para revisão. | Operador | Necessidade inferida de prevenção de fraude; limiares são pressupostos. |

### 2.3 Pressupostos e restrições

| ID | Tipo | Descrição |
|---|---|---|
| P01 | Pressuposto | A aplicação é executada localmente por um estudante em Windows 11. |
| P02 | Pressuposto | Nomes, contactos, contas e operações incluídos são dados fictícios. |
| P03 | Pressuposto | Os alertas com limiar de 3 000 EUR por operação ou 5 000 EUR de volume diário são apenas indicadores de revisão. |
| R01 | Restrição | A implementação usa PHP, HTML, CSS e JavaScript. |
| R02 | Restrição | A persistência usa SQLite local e não requer serviços externos. |
| R03 | Restrição | A solução não implementa autenticação e não pode ser usada em produção. |

### 2.4 Glossário

| Termo | Definição |
|---|---|
| PDO | PHP Data Objects, interface de acesso a bases de dados do PHP. |
| CSRF | Cross-Site Request Forgery; falsificação de pedidos entre sites. |
| PHP | PHP: Hypertext Preprocessor; linguagem usada no servidor. |
| HTML | HyperText Markup Language; linguagem de marcação de páginas Web. |
| CSS | Cascading Style Sheets; linguagem de estilos de páginas Web. |
| HTTP | HyperText Transfer Protocol; protocolo de comunicação Web. |
| SQL | Structured Query Language; linguagem de consulta a bases de dados relacionais. |
| UML | Unified Modeling Language; notação de modelação de software. |
| ISO/IEC/IEEE 29148 | Norma de engenharia de requisitos citada neste relatório. |
| ISO/IEC 25010 | Modelo de qualidade de produtos de software usado para classificar requisitos não funcionais. |
| Conta | Registo financeiro demonstrativo associado a um cliente. |
| Operação | Depósito, levantamento, transferência ou crédito de empréstimo registado. |
| Alerta | Registo que assinala uma operação para revisão humana; não declara fraude. |
| SQLite | Base de dados relacional embutida, guardada num ficheiro local. |

## 3. Requisitos

### 3.1 Critérios de prioridade

Os requisitos seguem as recomendações de redação verificável da ISO/IEC/IEEE 29148:2018 (International Organization for Standardization, 2018).

**Essencial** identifica funções centrais desta versão. **Importante** identifica funções incluídas para completar o percurso principal. **Opcional** identifica extensões futuras.

### 3.2 Requisitos funcionais

| ID | Descrição | Prioridade | Origem | Estado |
|---|---|---|---|---|
| RF01 | O sistema deve permitir que o Operador registe um cliente com nome, e-mail único e telefone válido. | Essencial | N01 | Implementado |
| RF02 | O sistema deve permitir que o Operador abra uma conta corrente ou poupança para um cliente existente. | Essencial | N02 | Implementado |
| RF03 | O sistema deve permitir que o Operador registe um depósito numa conta ativa, com montante positivo. | Essencial | N03 | Implementado |
| RF04 | O sistema deve permitir que o Operador registe um levantamento ou transferência, se a conta de origem tiver saldo suficiente. | Essencial | N03 | Implementado |
| RF05 | O sistema deve permitir que o Operador consulte saldos e as últimas 50 operações. | Essencial | N02, N03 | Implementado |
| RF06 | O sistema deve permitir que o Operador emita e bloqueie um cartão demonstrativo associado a uma conta ativa. | Importante | N04 | Implementado |
| RF07 | O sistema deve permitir que o Operador registe um pedido de empréstimo para uma conta do mesmo cliente. | Importante | N05 | Implementado |
| RF08 | O sistema deve permitir que o Gestor decida um pedido pendente e credite a conta se o aprovar. | Importante | N05 | Implementado |
| RF09 | O sistema deve permitir que o Gestor registe funcionários com um dos perfis definidos. | Importante | N06 | Implementado |
| RF10 | O sistema deve permitir que o Operador consulte totais de clientes, contas, empréstimos pendentes e alertas. | Essencial | N06 | Implementado |
| RF11 | O sistema deve criar um alerta quando uma operação atinge 3 000 EUR ou o volume diário da conta atinge 5 000 EUR. | Importante | N07 | Implementado |
| RF12 | O sistema deve permitir que o Operador marque um alerta como revisto. | Importante | N07 | Implementado |

### 3.3 Requisitos não funcionais

| ID | Categoria ISO/IEC 25010 | Descrição e verificação | Prioridade |
|---|---|---|---|
| RNF01 | Segurança | Formulários POST validam token CSRF e o código escapa conteúdo apresentado. Inspeção de `helpers.php` e submissão local. | Essencial |
| RNF02 | Segurança | Consultas com dados variáveis usam parâmetros PDO. Inspeção de `BankService.php`. | Essencial |
| RNF03 | Fiabilidade | Operações financeiras usam transações SQLite; tentativa inválida não pode alterar saldo. Testes T03–T06. | Essencial |
| RNF04 | Compatibilidade | A aplicação deve iniciar com PHP 8.2+ e `pdo_sqlite`; inspeção e teste HTTP em PHP 8.5.12. | Essencial |
| RNF05 | Usabilidade | Cada campo de formulário tem rótulo e cada erro de domínio apresenta mensagem em português. Inspeção e roteiro manual. | Importante |
| RNF06 | Manutenibilidade | A apresentação, o serviço de domínio e a persistência estão em ficheiros separados. Inspeção da árvore do projeto. | Essencial |

## 4. Casos de Uso

### 4.1 Atores

| Ator | Tipo | Descrição |
|---|---|---|
| Operador | Primário | Regista e consulta operações correntes. |
| Gestor | Primário | Regista funcionários e decide pedidos de empréstimo. |

Os perfis são atores conceptuais. A aplicação não controla sessão de utilizador nem acesso por papel.

### 4.2 Diagrama de casos de uso UML

O diagrama está em `docs/diagramas/figura-1-casos-de-uso.puml`.

### 4.3 Especificação dos casos de uso essenciais

| ID | Nome / ator | Requisitos | Pré-condições | Fluxo principal | Alternativa ou exceção | Pós-condição |
|---|---|---|---|---|---|---|
| UC01 | Registar cliente / Operador | RF01 | Página Clientes disponível. | Preenche nome, e-mail e telefone; submete; o serviço valida e guarda. | Dados inválidos ou e-mail repetido: apresenta mensagem e não guarda. | Cliente fica persistido. |
| UC02 | Abrir conta / Operador | RF02 | Cliente existente. | Seleciona cliente e tipo; submete; sistema gera número e saldo zero. | Cliente inexistente ou tipo inválido: rejeita a operação. | Conta ativa associada ao cliente. |
| UC03 | Registar operação / Operador | RF03, RF04, RF05 | Conta ativa e funcionário registado. | Indica tipo, conta(s), montante e funcionário; confirma; sistema atualiza saldo e histórico. | Saldo insuficiente, conta bloqueada, montante inválido ou mesma origem/destino: rejeita sem alteração. | Saldos e operação ficam persistidos; pode ser criado alerta. |
| UC04 | Decidir empréstimo / Gestor | RF07, RF08 | Pedido pendente, conta ativa e funcionário registado. | Seleciona Aprovar ou Recusar; sistema regista decisão. | Pedido decidido anteriormente ou conta sem estado ativo: rejeita. | Pedido decidido; aprovação credita saldo e cria operação. |
| UC05 | Rever alerta / Operador | RF11, RF12 | Existe alerta por rever. | Consulta motivo e marca como revisto. | Alerta inexistente ou já revisto: informa que não pode atualizar. | Estado passa a Revisto. |

## 5. User Stories

| ID | User story | Requisitos | Critérios de aceitação |
|---|---|---|---|
| US01 | Como Operador, quero registar um cliente, para associar-lhe contas. | RF01 | Dado um e-mail válido e único, quando submeto, então surge na lista. Dado um e-mail repetido, quando submeto, então aparece erro e não é criado. |
| US02 | Como Operador, quero abrir uma conta para um cliente, para guardar o seu saldo. | RF02 | Dado um cliente existente, quando escolho tipo e submeto, então a conta surge com saldo zero. Dado um cliente inexistente, quando a operação é enviada, então o serviço rejeita-a. |
| US03 | Como Operador, quero registar operações, para manter o saldo atualizado. | RF03–RF05 | Dado saldo suficiente, quando faço transferência, então a origem diminui e o destino aumenta pelo mesmo valor. Dado saldo insuficiente, quando tento levantar, então o saldo não muda e recebo erro. |
| US04 | Como Operador, quero emitir e bloquear cartões de demonstração, para gerir o seu estado. | RF06 | Dada uma conta ativa, quando emito cartão, então surge na lista. Quando bloqueio o cartão, então o estado muda para Bloqueado e a interface pede confirmação. |
| US05 | Como Gestor, quero decidir pedidos de empréstimo, para registar a decisão e o crédito correspondente. | RF07, RF08 | Dado pedido pendente, quando aprovo, então a conta recebe o montante e o pedido fica Aprovado. Dado pedido decidido, quando tento decidir de novo, então o sistema rejeita. |
| US06 | Como Operador, quero rever alertas, para analisar operações sinalizadas. | RF11, RF12 | Dada operação de 3 000 EUR, quando é registada, então há alerta por rever. Quando marco o alerta como revisto, então deixa de constar como aberto. |

## 6. Modelo de Domínio e Modelo de Dados

### 6.1 Modelo de domínio

O modelo conceptual inclui Cliente, Conta, Operação, Cartão, Empréstimo, Funcionário e Alerta. O diagrama está em `docs/diagramas/figura-2-modelo-dominio.puml`.

### 6.2 Modelo de dados

A aplicação persiste dados num ficheiro SQLite (`storage/banco.sqlite`). O esquema usa chaves estrangeiras, campos únicos, valores restringidos e valores monetários inteiros em cêntimos. A ligação ativa `PRAGMA foreign_keys=ON`. SQLite verifica as restrições durante alterações de dados (SQLite Consortium, s.d.).

O diagrama entidade-relação está em `docs/diagramas/figura-3-modelo-dados.puml`.

| Tabela | Atributo | Tipo | Restrições | Descrição |
|---|---|---|---|---|
| customers | id | INTEGER | PK | Identificador do cliente. |
| customers | full_name, email, phone | TEXT | Nome obrigatório; e-mail único | Identificação e contacto fictícios. |
| employees | id | INTEGER | PK | Identificador do funcionário. |
| employees | full_name, role, email, active | TEXT/INTEGER | Papel limitado a Operador/Gestor; e-mail único | Funcionário que regista ou decide. |
| accounts | id, customer_id | INTEGER | PK, FK para customers | Identificador e titular da conta. |
| accounts | account_number, account_type, balance_cents, status | TEXT/INTEGER | Número único; tipo e estado enumerados; saldo >= 0 | Conta e saldo atual em cêntimos. |
| transactions | id | INTEGER | PK | Identificador da operação. |
| transactions | from_account_id, to_account_id, employee_id | INTEGER | FK opcionais | Contas e funcionário associados. |
| transactions | operation_type, amount_cents, description, created_at | TEXT/INTEGER | Tipo enumerado; valor > 0 | Detalhe e data da operação. |
| cards | id, account_id | INTEGER | PK, FK | Identificador e conta associada. |
| cards | card_number, status, issued_at | TEXT | Número único mascarado; estado enumerado | Cartão de demonstração. |
| loans | id, customer_id, account_id, employee_id | INTEGER | PK, FKs | Pedido, cliente, conta e decisor. |
| loans | amount_cents, term_months, status, created_at | INTEGER/TEXT | Montante > 0; prazo 1–360; estado enumerado | Condições e estado do pedido. |
| fraud_alerts | id, transaction_id | INTEGER | PK, FK | Alerta ligado a uma operação. |
| fraud_alerts | reason, status, created_at | TEXT | Estado enumerado | Motivo e revisão humana. |

### 6.3 Regras de negócio

| ID | Regra | Garantia | Testes |
|---|---|---|---|
| RN01 | O montante de cada operação é positivo; o saldo não pode ficar negativo. | Serviço e CHECK da base de dados. | T01, T04 |
| RN02 | Transferência exige contas ativas distintas e saldo suficiente na origem. | BankService, transação SQLite. | T02–T05 |
| RN03 | Um pedido de empréstimo associa uma conta ativa ao mesmo cliente. | BankService e FKs. | T10 |
| RN04 | Empréstimo aprovado credita a conta uma única vez. | Decisão condicional, transação SQLite. | T07–T08 |
| RN05 | Uma operação pode gerar alerta a partir dos limiares configurados. | BankService. | T06 |

## 7. Arquitetura e Implementação

### 7.1 Visão geral

A aplicação única separa apresentação, regras de domínio e persistência. A Figura 4 apresenta as camadas e a Figura 5 resume a estrutura de pastas. As fontes encontram-se em `docs/diagramas/figura-4-arquitetura.puml` e `docs/diagramas/figura-5-estrutura.svg`.

### 7.2 Tecnologias

| Tecnologia | Versão | Finalidade | Justificação |
|---|---|---|---|
| PHP | 8.5.12 testado; requisito 8.2+ | Aplicação e validação no servidor | Tecnologia exigida no contexto do projeto. |
| HTML | HTML5 | Formulários e páginas | Nativo no navegador. |
| CSS | CSS3 | Apresentação responsiva | Sem biblioteca externa. |
| JavaScript | ES6 do navegador | Confirmações e ajuda visual à validação | Sem dependências externas. |
| SQLite | Versão fornecida pelo PHP | Persistência relacional local | Instalação simples para projeto académico. |
| PDO_SQLITE | Extensão PDO | Consultas parametrizadas | Acesso à base de dados integrado no PHP (PHP Documentation Group, s.d.). |
| PlantUML | Fonte `.puml` | Diagramas editáveis | Permite manter os diagramas em texto. |

### 7.3 Estrutura do projeto

```text
app/BankService.php       regras e operações
app/Database.php          ligação, esquema e dados de demonstração
app/helpers.php           escape, CSRF, mensagens e formatação
database/schema.sql       esquema relacional
docs/diagramas/*.puml     fontes de diagramas
public/index.php          interface e encaminhamento POST
public/assets/app.css     estilos responsivos
public/assets/app.js      confirmações e atributos de formulário
tests/run.php             testes automatizados de domínio
```

### 7.4 Percurso de uma operação

O formulário envia um pedido POST com token CSRF. `public/index.php` interpreta a ação e converte o montante. `BankService` valida contas, funcionário, saldo e regra de negócio. O serviço atualiza saldos e histórico na mesma transação SQLite. Se o limiar for atingido, cria o alerta. O fluxo é representado na Figura 6 e em `docs/diagramas/figura-6-sequencia-operacao.puml`.

### 7.5 Decisões de arquitetura

| ID | Decisão | Alternativas | Justificação e consequências |
|---|---|---|---|
| DA01 | Aplicação PHP única com ficheiros por responsabilidade. | Microserviços ou framework. | Menor complexidade; facilita seguir o fluxo, mas não oferece isolamento de serviço. |
| DA02 | SQLite via PDO. | MySQL ou ficheiro JSON. | Relações e restrições SQL sem servidor adicional; não é opção para operação bancária concorrente de produção. |
| DA03 | Valores monetários em cêntimos inteiros. | Números de vírgula flutuante. | Evita erro de arredondamento binário em operações simples. |
| DA04 | Sem autenticação nesta versão. | Sessões com palavras-passe e perfis. | Reduz âmbito; qualquer pessoa com acesso local pode executar operações, pelo que a aplicação não é segura para produção. |

### 7.6 Segurança, privacidade e qualidade do código

O serviço valida os dados mesmo que o pedido não venha de um formulário. PDO parametriza dados variáveis e as transações financeiras são atómicas. A interface escapa texto com `htmlspecialchars`. Os formulários POST usam token CSRF. A base de dados mantém relações e restrições de domínio. Não há credenciais nem palavras-passe. Os contactos da demonstração usam domínios reservados `.test` e são fictícios. Os erros de validação são apresentados sem expor mensagens internas de PDO. Os nomes de funções e tabelas são consistentes e as funções de serviço concentram regras específicas.

Limite: não existe autenticação, autorização, encriptação do ficheiro SQLite, política de retenção, auditoria imutável ou avaliação regulamentar. A aplicação só deve ser usada localmente para fins de aprendizagem.

### 7.7 Instalação e execução

1. Instalar PHP 8.2 ou superior, incluindo `pdo_sqlite` e `sqlite3`.
2. Confirmar com `php -m` que aparecem `PDO`, `pdo_sqlite` e `sqlite3`.
3. Na pasta do projeto, executar `php -S 127.0.0.1:8000 -t public`.
4. Abrir `http://127.0.0.1:8000`.
5. Executar `php tests/run.php` para os testes.

Na máquina de preparação foi usado PHP 8.5.12. A instalação tinha os ficheiros DLL das extensões SQLite, mas não as carregava na configuração por omissão. Foi necessário fornecer `extension_dir`, `extension=pdo_sqlite` e `extension=sqlite3` ao PHP durante a verificação. A configuração habitual de outro computador pode ativar essas extensões no respetivo `php.ini`.

## 8. Testes e Validação

### 8.1 Estratégia

Os testes automatizados criam uma base SQLite em memória e exercitam regras de domínio sem alterar dados de utilização. Foi usado PHP CLI 8.5.12, PDO_SQLITE e SQLite3. Foi iniciado o servidor local PHP e inspecionada uma resposta HTTP. A inspeção manual completa em navegador fica por realizar.

### 8.2 Casos de teste

| ID | Requisito / regra | Tipo / pré-condição / passos | Resultado esperado | Resultado obtido | Estado |
|---|---|---|---|---|---|
| T01 | RF01 | Unidade; registar cliente válido. | Cliente fica disponível na consulta. | Passou. | Passou |
| T02 | RF01 | Unidade; repetir e-mail de cliente. | Registo duplicado é rejeitado. | Passou. | Passou |
| T03 | RF09 | Unidade; registar funcionário. | Funcionário fica disponível. | Passou. | Passou |
| T04 | RF02 | Unidade; abrir contas para clientes existentes. | Contas ficam associadas ao titular. | Passou. | Passou |
| T05 | RF02 | Unidade; abrir conta para cliente inexistente. | Operação é rejeitada. | Passou. | Passou |
| T06 | RF03, RN01 | Unidade; depositar 1 000,00 EUR. | Saldo aumenta pelo montante. | Passou. | Passou |
| T07 | RF04, RN02 | Unidade; transferir entre contas. | Saldo da origem diminui pelo montante. | Passou. | Passou |
| T08 | RF04, RN02 | Unidade; transferir entre contas. | Saldo do destino aumenta pelo montante. | Passou. | Passou |
| T09 | RF04, RN01 | Unidade; levantar acima do saldo. | Erro; saldo mantém-se inalterado. | Passou. | Passou |
| T10 | RF04, RN02 | Unidade; transferir para a mesma conta. | Operação é rejeitada. | Passou. | Passou |
| T11 | RF11, RN05 | Unidade; registar operação de 3 000 EUR. | Cria alerta por rever. | Passou. | Passou |
| T12 | RF12 | Unidade; marcar alerta aberto como revisto. | Estado passa a Revisto. | Passou. | Passou |
| T13 | RF08, RN04 | Unidade; aprovar pedido pendente. | Conta é creditada e pedido aprovado. | Passou. | Passou |
| T14 | RF08, RN04 | Unidade; decidir de novo pedido aprovado. | Segunda decisão é rejeitada. | Passou. | Passou |
| T15 | RF06 | Unidade; emitir e bloquear cartão. | Estado passa a Bloqueado. | Passou. | Passou |
| T16 | RF07, RN03 | Unidade; associar empréstimo à conta de outro cliente. | Pedido é rejeitado. | Passou. | Passou |
| T17 | RF05, RF10 | Unidade; consultar totais do painel. | Totais correspondem aos registos. | Passou. | Passou |
| T18 | RNF01, RF04 | Interface; submeter levantamento acima do saldo. | HTTP 200 e mensagem de validação. | Página servida com HTTP 200 e mensagem “Saldo insuficiente”. | Passou |
| T19 | RNF04 | CLI; validar sintaxe dos ficheiros PHP. | Todos sem erro de sintaxe. | Cinco ficheiros sem erro de sintaxe. | Passou |
| T20 | RF01 | Manual UI; criar cliente fictício. | Cliente fica na lista. | Não executado. | Não executado |
| T21 | RF02 | Manual UI; abrir conta para cliente existente. | Conta ativa com saldo zero. | Não executado. | Não executado |
| T22 | RF03 | Manual UI; depositar e consultar saldo. | Saldo aumenta pelo montante. | Não executado. | Não executado |
| T23 | RF04 | Manual UI; levantar acima do saldo. | Erro e saldo inalterado. | Não executado. | Não executado |
| T24 | RF04 | Manual UI; transferir entre duas contas. | Origem e destino atualizados. | Não executado. | Não executado |
| T25 | RF06 | Manual UI; emitir e bloquear cartão. | Cartão fica bloqueado após confirmação. | Não executado. | Não executado |
| T26 | RF07, RF08 | Manual UI; criar e aprovar empréstimo. | Pedido aprovado e conta creditada. | Não executado. | Não executado |
| T27 | RF11, RF12 | Manual UI; rever alerta existente. | Estado passa a Revisto. | Não executado. | Não executado |
| T28 | RNF03 | Manual UI; reiniciar servidor após registos. | Dados continuam persistidos. | Não executado. | Não executado |

Roteiro manual ainda necessário: (1) criar cliente com dados fictícios; (2) abrir conta; (3) depositar e verificar saldo; (4) levantar acima do saldo e verificar mensagem; (5) transferir entre contas; (6) emitir e bloquear cartão e confirmar a ação; (7) criar e aprovar empréstimo; (8) rever alerta; (9) reiniciar o servidor e confirmar persistência.

### 8.3 Resumo dos resultados

Na execução de 2026-10-29 em Windows 11, PHP 8.5.12: 18 verificações de domínio, uma verificação HTTP e uma verificação de sintaxe passaram. Não houve falhas. Os nove casos manuais T20–T28 não foram executados.

### 8.4 Matriz de rastreabilidade

| RF | Prioridade | UC | US | Implementação | Testes | Estado |
|---|---|---|---|---|---|---|
| RF01 | Essencial | UC01 | US01 | BankService, página Clientes | T01–T02 | Verificado |
| RF02 | Essencial | UC02 | US02 | BankService, página Contas | T04–T05 | Verificado |
| RF03 | Essencial | UC03 | US03 | BankService::transact | T06 | Verificado |
| RF04 | Essencial | UC03 | US03 | BankService::transact | T07–T10, T18 | Verificado |
| RF05 | Essencial | UC03 | US03 | Consultas do BankService, Painel/Operações | T17–T18 | Verificado |
| RF06 | Importante | UC03 | US04 | BankService cartões, página Cartões | T15 | Verificado |
| RF07 | Importante | UC04 | US05 | BankService::createLoan | T16 | Verificado |
| RF08 | Importante | UC04 | US05 | BankService::decideLoan | T13–T14 | Verificado |
| RF09 | Importante | UC01 | US01 | BankService, página Funcionários | T03 | Verificado |
| RF10 | Essencial | UC03 | US03 | BankService::summary, Painel | T17 | Verificado |
| RF11 | Importante | UC05 | US06 | BankService::alertReason | T11 | Verificado |
| RF12 | Importante | UC05 | US06 | BankService::markAlertReviewed | T12 | Verificado |

## 9. Apresentação do Produto Final

A Figura 7 apresenta a captura real do Painel de controlo, obtida no Microsoft Edge headless em 2026-10-29 a partir do servidor PHP local. A captura usa os dados fictícios carregados pela aplicação e está guardada em `docs/capturas/painel.png`. O ecrã mostra saldo agregado, totais e operações recentes. A inspeção manual completa dos restantes percursos continua pendente.

## 10. Conclusão e Reflexão

### 10.1 Objetivos alcançados

A versão implementa as operações principais e conserva os dados após reinício. Dez testes automatizados e uma verificação HTTP passaram. RF01 e RF02 foram implementados mas carecem de testes automatizados. RF04 tem uma exceção adicional ainda por testar. Por isso, não se declara que todos os requisitos essenciais estejam totalmente verificados.

### 10.2 Limitações e problemas conhecidos

| ID | Descrição | Impacto | Possível solução |
|---|---|---|---|
| L01 | Não há autenticação nem perfis de acesso aplicados. | Qualquer utilizador local pode operar a aplicação. | Implementar autenticação segura se o âmbito académico o exigir. |
| L02 | Alertas usam limiares fixos e não detetam fraude real. | Pode haver falsos positivos ou operações não sinalizadas. | Definir regras com especialista e avaliar dados controlados. |
| L03 | Só foi capturado o Painel de controlo; o teste manual completo continua pendente. | Evidência visual parcial. | Executar o roteiro e guardar capturas reais adicionais com dados fictícios. |
| L04 | Alguns requisitos implementados não têm testes automáticos dedicados. | Cobertura de regressão limitada. | Acrescentar testes de cliente, conta, funcionário e revisão de alerta. |
| L05 | Decisão de empréstimo não avalia taxa, solvabilidade ou plano de pagamento. | Crédito é apenas demonstrativo. | Acrescentar regras académicas de cálculo, sem dados reais. |
| L06 | Não foi possível sincronizar o repositório remoto. | A versão só está disponível localmente. | Sincronizar `v1.0.0` quando houver ligação ao repositório. |

### 10.3 Trabalho futuro

Prioridades: automatizar testes de clientes, contas, funcionários e revisão de alertas; completar roteiro manual e capturas reais; adicionar filtros e exportação de relatório; avaliar autenticação e autorização apenas se forem requisito da unidade curricular; ligar o código a um commit do repositório indicado.

### 10.4 Reflexão pessoal

**A preencher pelo estudante.** O que aprendi de mais importante com este projeto? Que decisão técnica consigo justificar melhor, e porquê? Qual foi a principal dificuldade e como a resolvi? Que sugestões das ferramentas de IA tive de corrigir, adaptar ou rejeitar, e porquê? O que faria de forma diferente num próximo projeto?

## Referências

International Organization for Standardization. (2018). *Systems and software engineering—Life cycle processes—Requirements engineering* (ISO/IEC/IEEE Standard No. 29148:2018). <https://committee.iso.org/standard/72089.html>

PHP Documentation Group. (s.d.). *SQLite PDO driver*. PHP Manual. <https://www.php.net/manual/en/ref.pdo-sqlite.php>

PHP Documentation Group. (s.d.). *PHP Licensing*. <https://www.php.net/license/>

SQLite Consortium. (s.d.). *CREATE TABLE*. SQLite documentation. <https://www.sqlite.org/lang_createtable.html>

SQLite Consortium. (s.d.). *Copyright*. <https://www.sqlite.org/copyright.html>

## Declaração de utilização de IA e recursos externos

| Ferramenta | Versão/data | Finalidade | Partes | Verificação |
|---|---|---|---|---|
| ChatGPT / Codex | 2026-10-29 | Apoio à implementação, testes, diagramas e redação técnica. | Código, testes e relatório. | Revisão do código; execução local dos testes registados; confirmação das limitações. |

| Recurso | Origem | Licença | Utilização |
|---|---|---|---|
| PHP Manual | php.net | CC BY 3.0 (texto do manual) | Consulta de PDO_SQLITE. |
| SQLite documentation | sqlite.org | Domínio público | Consulta de restrições e esquema relacional. |
| ISO/IEC/IEEE 29148:2018 | ISO | Publicação protegida; apenas citada | Referência para requisitos verificáveis. |

**Declaração:** Declaro que assumo a autoria e a responsabilidade pelo trabalho apresentado, que identifiquei as ferramentas e os recursos utilizados e que sou capaz de explicar o conteúdo do relatório e do código entregue.  
**Nome e data:** por preencher.

## Anexos

### Anexo A — Código-fonte dos diagramas

Fontes editáveis disponíveis em `docs/diagramas/`: casos de uso, domínio, dados, arquitetura, estrutura de pastas e sequência.

### Anexo B — Registo da execução dos testes

Executado em 2026-10-29 com PHP 8.5.12 e `pdo_sqlite`/`sqlite3` ativados. Resultado: 18 verificações de domínio, uma HTTP e uma sintaxe passaram. O registo completo está em `docs/registo-testes.txt`; a validação de sintaxe reportou cinco ficheiros PHP sem erros.

### Anexo C — Dados de demonstração

A primeira execução cria Ana Silva (`ana.silva@example.test`) e João Costa (`joao.costa@example.test`), dois funcionários fictícios e duas contas com saldos de 2 500,00 EUR e 1 250,00 EUR. A base de dados é criada automaticamente em `storage/banco.sqlite`.

## Perguntas de compreensão para preparação da defesa

1. Porque são guardados os valores monetários em cêntimos inteiros?
2. Em que camada são aplicadas as regras de saldo e por que não basta validar no navegador?
3. Como garante uma transferência que o débito e o crédito são persistidos em conjunto?
4. O que representa um alerta de risco e que limitações tem a regra atual?
5. Que alterações seriam necessárias antes de permitir utilizadores autenticados ou dados bancários reais?
