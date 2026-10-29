param(
    [string]$Template = (Join-Path $PSScriptRoot '..\docs\template\ModeloSWE-2627.docx'),
    [string]$Output = (Join-Path $PSScriptRoot '..\docs\Relatorio-SGB.docx')
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$source = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $Template))
$memory = [System.IO.MemoryStream]::new()
$entry = $source.GetEntry('word/document.xml')
$reader = [System.IO.StreamReader]::new($entry.Open())
try { [xml]$document = $reader.ReadToEnd() } finally { $reader.Dispose() }
$ns = [System.Xml.XmlNamespaceManager]::new($document.NameTable)
$ns.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
$body = $document.SelectSingleNode('/w:document/w:body', $ns)
$document.DocumentElement.SetAttribute('xmlns:wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')
$document.DocumentElement.SetAttribute('xmlns:a','http://schemas.openxmlformats.org/drawingml/2006/main')
$document.DocumentElement.SetAttribute('xmlns:pic','http://schemas.openxmlformats.org/drawingml/2006/picture')
$document.DocumentElement.SetAttribute('xmlns:r','http://schemas.openxmlformats.org/officeDocument/2006/relationships')

function Get-Text($node) {
    return (($node.SelectNodes('.//w:t', $script:ns) | ForEach-Object { $_.InnerText }) -join '')
}
function Set-Text($node, [string]$value) {
    $texts = $node.SelectNodes('.//w:t', $script:ns)
    if ($texts.Count -gt 0) {
        $texts[0].InnerText = $value
        for ($i = 1; $i -lt $texts.Count; $i++) { $texts[$i].InnerText = '' }
        if ($value.StartsWith(' ') -or $value.EndsWith(' ')) { $texts[0].SetAttribute('space', 'http://www.w3.org/XML/1998/namespace', 'preserve') }
        return
    }
    $p = $node.SelectSingleNode('.//w:p', $script:ns)
    if (-not $p) { return }
    $run = $document.CreateElement('w', 'r', $script:ns.LookupNamespace('w'))
    $textNode = $document.CreateElement('w', 't', $script:ns.LookupNamespace('w'))
    $textNode.InnerText = $value
    $run.AppendChild($textNode) | Out-Null
    $p.AppendChild($run) | Out-Null
}
function Make-Row([string[]]$cells) { return [pscustomobject]@{ Cells = $cells } }
function Set-TableRows([int]$number, [object[]]$data) {
    $table = $script:tables[$number - 1]
    $rows = $table.SelectNodes('./w:tr', $script:ns)
    if ($rows.Count -lt 2) { throw "Tabela $number não tem linha de dados para reutilizar." }
    $prototype = $rows[1].CloneNode($true)
    foreach ($row in @($rows | Select-Object -Skip 1)) { $table.RemoveChild($row) | Out-Null }
    foreach ($record in $data) {
        $newRow = $prototype.CloneNode($true)
        $cells = $newRow.SelectNodes('./w:tc', $script:ns)
        if ($cells.Count -ne $record.Cells.Count) { throw "Tabela ${number}: esperadas $($cells.Count) células, recebidas $($record.Cells.Count)." }
        for ($i = 0; $i -lt $cells.Count; $i++) { Set-Text $cells[$i] ([string]$record.Cells[$i]) }
        $table.AppendChild($newRow) | Out-Null
    }
}
function Set-OneCell([int]$number, [string]$value) {
    $cell = $script:tables[$number - 1].SelectSingleNode('.//w:tc', $script:ns)
    Set-Text $cell $value
}
function Add-XmlElement($parent, [string]$prefix, [string]$localName, [string]$namespace) {
    $element = $document.CreateElement($prefix, $localName, $namespace)
    $parent.AppendChild($element) | Out-Null
    return $element
}
function Set-CellImage([int]$number, [string]$relationshipId, [string]$imageName) {
    $cell = $script:tables[$number - 1].SelectSingleNode('.//w:tc', $script:ns)
    $paragraph = $cell.SelectSingleNode('./w:p', $script:ns)
    foreach ($child in @($paragraph.ChildNodes)) { if ($child.LocalName -ne 'pPr') { $paragraph.RemoveChild($child) | Out-Null } }
    $w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
    $wp = 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing'
    $a = 'http://schemas.openxmlformats.org/drawingml/2006/main'
    $pic = 'http://schemas.openxmlformats.org/drawingml/2006/picture'
    $r = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
    $drawing = Add-XmlElement $paragraph 'w' 'drawing' $w
    $inline = Add-XmlElement $drawing 'wp' 'inline' $wp
    foreach ($edge in @('T','B','L','R')) { $inline.SetAttribute('dist' + $edge, '0') }
    $extent = Add-XmlElement $inline 'wp' 'extent' $wp
    $extent.SetAttribute('cx','5669280'); $extent.SetAttribute('cy','3613150')
    $effect = Add-XmlElement $inline 'wp' 'effectExtent' $wp
    foreach ($edge in @('l','t','r','b')) { $effect.SetAttribute($edge,'0') }
    $docPr = Add-XmlElement $inline 'wp' 'docPr' $wp
    $docPr.SetAttribute('id',[string]$number); $docPr.SetAttribute('name',$imageName); $docPr.SetAttribute('descr',$imageName)
    $frame = Add-XmlElement $inline 'wp' 'cNvGraphicFramePr' $wp
    $locks = Add-XmlElement $frame 'a' 'graphicFrameLocks' $a; $locks.SetAttribute('noChangeAspect','1')
    $graphic = Add-XmlElement $inline 'a' 'graphic' $a
    $graphicData = Add-XmlElement $graphic 'a' 'graphicData' $a
    $graphicData.SetAttribute('uri',$pic)
    $picture = Add-XmlElement $graphicData 'pic' 'pic' $pic
    $nv = Add-XmlElement $picture 'pic' 'nvPicPr' $pic
    $cnv = Add-XmlElement $nv 'pic' 'cNvPr' $pic; $cnv.SetAttribute('id',[string]$number); $cnv.SetAttribute('name',$imageName)
    $cnvPic = Add-XmlElement $nv 'pic' 'cNvPicPr' $pic
    $picLocks = Add-XmlElement $cnvPic 'a' 'picLocks' $a; $picLocks.SetAttribute('noChangeAspect','1')
    $fill = Add-XmlElement $picture 'pic' 'blipFill' $pic
    $blip = Add-XmlElement $fill 'a' 'blip' $a; [void]$blip.SetAttribute('embed',$r,$relationshipId)
    $stretch = Add-XmlElement $fill 'a' 'stretch' $a; [void](Add-XmlElement $stretch 'a' 'fillRect' $a)
    $shape = Add-XmlElement $picture 'pic' 'spPr' $pic
    $transform = Add-XmlElement $shape 'a' 'xfrm' $a
    $offset = Add-XmlElement $transform 'a' 'off' $a; $offset.SetAttribute('x','0'); $offset.SetAttribute('y','0')
    $size = Add-XmlElement $transform 'a' 'ext' $a; $size.SetAttribute('cx','5669280'); $size.SetAttribute('cy','3613150')
    $geometry = Add-XmlElement $shape 'a' 'prstGeom' $a; $geometry.SetAttribute('prst','rect'); [void](Add-XmlElement $geometry 'a' 'avLst' $a)
}
function Add-Rows([int]$number, [object[]]$records) { $script:data[$number] = $records }

$script:tables = $document.SelectNodes('//w:tbl', $ns)
$script:data = @{}
Add-Rows 3 @((Make-Row @('1.0','2026-10-29','v1.0.0 (tag local)','Versão funcional; testes de domínio e documentação técnica.','1–10, anexos')))
Add-Rows 6 @(
    (Make-Row @('Operador','Regista atividade corrente no ambiente local.','Consultar clientes e contas; registar operações; emitir cartões; rever alertas.')),
    (Make-Row @('Gestor','Regista funcionários e decide pedidos.','Consultar painel; registar funcionários; aprovar ou recusar empréstimos.'))
)
Add-Rows 7 @((Make-Row @('Clientes, funcionários, contas, operações, cartões e empréstimos de demonstração.','Autenticação, redes bancárias, processamento de pagamentos reais e operação em produção.')))
Add-Rows 9 @(
    (Make-Row @('N01','Registar e consultar clientes.','Operador','Enunciado')),
    (Make-Row @('N02','Abrir contas e consultar saldos.','Operador','Enunciado')),
    (Make-Row @('N03','Registar operações com saldo coerente.','Operador','Enunciado; regra de saldo pressuposta')),
    (Make-Row @('N04','Emitir e bloquear cartões demonstrativos.','Operador','Enunciado')),
    (Make-Row @('N05','Registar e decidir pedidos de empréstimo.','Operador/Gestor','Enunciado')),
    (Make-Row @('N06','Registar funcionários e consultar resumo.','Gestor','Enunciado')),
    (Make-Row @('N07','Sinalizar operações de risco para revisão.','Operador','Necessidade inferida; limiares pressupostos'))
)
Add-Rows 10 @(
    (Make-Row @('P01','Pressuposto','Uso local por estudante em Windows 11.')),
    (Make-Row @('P02','Pressuposto','Todos os dados de demonstração são fictícios.')),
    (Make-Row @('P03','Pressuposto','Alertas usam limiares fixos e requerem revisão humana.')),
    (Make-Row @('R01','Restrição','Tecnologias exigidas: PHP, HTML, CSS e JavaScript.')),
    (Make-Row @('R02','Restrição','Persistência em SQLite local.')),
    (Make-Row @('R03','Restrição','A aplicação não inclui autenticação nem uso em produção.'))
)
Add-Rows 11 @(
    (Make-Row @('PDO','PHP Data Objects; interface de acesso a dados do PHP.')),
    (Make-Row @('CSRF','Cross-Site Request Forgery; falsificação de pedidos entre sites.')),
    (Make-Row @('PHP','PHP: Hypertext Preprocessor; linguagem de servidor.')),
    (Make-Row @('HTML','HyperText Markup Language; linguagem de marcação Web.')),
    (Make-Row @('CSS','Cascading Style Sheets; linguagem de estilos Web.')),
    (Make-Row @('HTTP','HyperText Transfer Protocol; protocolo Web.')),
    (Make-Row @('SQL','Structured Query Language; linguagem de bases de dados relacionais.')),
    (Make-Row @('UML','Unified Modeling Language; notação de modelação.')),
    (Make-Row @('ISO/IEC/IEEE 29148','Norma de engenharia de requisitos citada.')),
    (Make-Row @('ISO/IEC 25010','Modelo de qualidade de software usado para classificar requisitos.')),
    (Make-Row @('Conta','Registo financeiro demonstrativo associado a um cliente.')),
    (Make-Row @('Operação','Depósito, levantamento, transferência ou crédito de empréstimo.')),
    (Make-Row @('Alerta','Sinalização para revisão humana; não confirma fraude.')),
    (Make-Row @('SQLite','Base de dados relacional embutida num ficheiro local.'))
)
Add-Rows 13 @(
    (Make-Row @('Essencial','Capacidade central desta versão, implementada e associada a teste.')),
    (Make-Row @('Importante','Capacidade implementada para completar o percurso de demonstração.')),
    (Make-Row @('Opcional','Extensão proposta para trabalho futuro.'))
)
Add-Rows 14 @(
    (Make-Row @('RF01','O sistema deve permitir que o Operador registe cliente com e-mail único e telefone válido.','Essencial','N01','Implementado')),
    (Make-Row @('RF02','O sistema deve permitir que o Operador abra conta para cliente existente.','Essencial','N02','Implementado')),
    (Make-Row @('RF03','O sistema deve permitir que o Operador deposite montante positivo numa conta ativa.','Essencial','N03','Implementado')),
    (Make-Row @('RF04','O sistema deve permitir levantamento ou transferência se houver saldo suficiente.','Essencial','N03','Implementado')),
    (Make-Row @('RF05','O sistema deve permitir consulta de saldos e das últimas 50 operações.','Essencial','N02, N03','Implementado')),
    (Make-Row @('RF06','O sistema deve permitir emissão e bloqueio de cartão demonstrativo.','Importante','N04','Implementado')),
    (Make-Row @('RF07','O sistema deve permitir pedido associado a conta do mesmo cliente.','Importante','N05','Implementado')),
    (Make-Row @('RF08','O sistema deve permitir decisão de pedido pendente; aprovação credita a conta.','Importante','N05','Implementado')),
    (Make-Row @('RF09','O sistema deve permitir registo de funcionário com perfil definido.','Importante','N06','Implementado')),
    (Make-Row @('RF10','O sistema deve permitir consulta dos totais do painel.','Essencial','N06','Implementado')),
    (Make-Row @('RF11','O sistema deve criar alerta a partir de 3 000 EUR por operação ou 5 000 EUR diários.','Importante','N07','Implementado')),
    (Make-Row @('RF12','O sistema deve permitir que o Operador marque alerta como revisto.','Importante','N07','Implementado'))
)
Add-Rows 16 @(
    (Make-Row @('RNF01','Segurança','Tokens CSRF em POST e escape HTML.','Inspeção e teste HTTP.','Essencial')),
    (Make-Row @('RNF02','Segurança','Consultas variáveis parametrizadas.','Inspeção de BankService.','Essencial')),
    (Make-Row @('RNF03','Fiabilidade','Transações financeiras atómicas.','Testes T06–T10 e T13–T14.','Essencial')),
    (Make-Row @('RNF04','Compatibilidade','PHP 8.2+ com PDO_SQLITE.','Testado em PHP 8.5.12.','Essencial')),
    (Make-Row @('RNF05','Usabilidade','Campos rotulados e mensagens em português.','Inspeção da interface.','Importante')),
    (Make-Row @('RNF06','Manutenibilidade','Separação entre apresentação, domínio e persistência.','Inspeção da árvore.','Essencial'))
)
Add-Rows 18 @(
    (Make-Row @('Operador','Primário','Regista e consulta operações correntes.')),
    (Make-Row @('Gestor','Primário','Regista funcionários e decide pedidos de empréstimo.'))
)
Add-Rows 21 @(
    (Make-Row @('ID','UC01–UC05')),
    (Make-Row @('Nome','Registar cliente; abrir conta; registar operação; decidir empréstimo; rever alerta.')),
    (Make-Row @('Ator principal','Operador; Gestor nas decisões e registo de funcionários.')),
    (Make-Row @('Requisitos associados','RF01–RF12, conforme o percurso.')),
    (Make-Row @('Pré-condições','Base de dados inicializada; contas e funcionários existentes quando necessários.')),
    (Make-Row @('Fluxo principal','Introduzir dados; validar no serviço; persistir dados e apresentar resultado.')),
    (Make-Row @('Alternativas / exceções','Dados inválidos, saldo insuficiente, registo inexistente ou pedido já decidido: rejeitar sem alteração incompatível.')),
    (Make-Row @('Pós-condições','Registos e saldos coerentes ficam persistidos; alerta é revisto ou criado quando aplicável.'))
)
Add-Rows 23 @(
    (Make-Row @('US01','Como Operador, quero registar clientes, para associar contas.','RF01','Dado e-mail válido, quando submeto, então cria; e-mail repetido gera erro.')),
    (Make-Row @('US02','Como Operador, quero abrir contas, para guardar saldo.','RF02','Dado cliente existente, quando abro, então cria saldo zero; cliente inexistente é rejeitado.')),
    (Make-Row @('US03','Como Operador, quero registar operações, para manter o saldo atualizado.','RF03–RF05','Dado saldo suficiente, transferência atualiza duas contas; saldo insuficiente é rejeitado.')),
    (Make-Row @('US04','Como Operador, quero gerir cartões, para controlar o estado demonstrativo.','RF06','Conta ativa permite emitir; bloqueio requer confirmação.')),
    (Make-Row @('US05','Como Gestor, quero decidir empréstimos, para registar o resultado.','RF07–RF08','Aprovar credita conta; pedido decidido não pode ser repetido.')),
    (Make-Row @('US06','Como Operador, quero rever alertas, para analisar operações sinalizadas.','RF11–RF12','Limiar cria alerta; ação altera estado para Revisto.'))
)
Add-Rows 27 @(
    (Make-Row @('customers','id','INTEGER','PK','Identificador.')),
    (Make-Row @('customers','full_name, email, phone','TEXT','NOT NULL; e-mail UNIQUE','Nome e contacto fictícios.')),
    (Make-Row @('employees','id; full_name; role; email; active','INTEGER/TEXT','PK; papel restrito; e-mail UNIQUE','Funcionário e estado.')),
    (Make-Row @('accounts','id; customer_id','INTEGER','PK; FK customers','Conta e titular.')),
    (Make-Row @('accounts','account_number; account_type; balance_cents; status','TEXT/INTEGER','UNIQUE; valores limitados; saldo >= 0','Número, tipo, saldo em cêntimos e estado.')),
    (Make-Row @('transactions','id; from_account_id; to_account_id; employee_id','INTEGER','PK; FKs opcionais','Contas e funcionário associados.')),
    (Make-Row @('transactions','operation_type; amount_cents; description; created_at','TEXT/INTEGER','Tipo enumerado; montante > 0','Detalhe e data da operação.')),
    (Make-Row @('cards','id; account_id; card_number; status; issued_at','INTEGER/TEXT','PK; FK; número UNIQUE','Cartão demonstrativo mascarado.')),
    (Make-Row @('loans','id; customer_id; account_id; employee_id','INTEGER','PK; FKs','Pedido, cliente, conta e decisor.')),
    (Make-Row @('loans','amount_cents; term_months; status; created_at','INTEGER/TEXT','Montante > 0; prazo 1–360; estado enumerado','Condições e estado.')),
    (Make-Row @('fraud_alerts','id; transaction_id; reason; status; created_at','INTEGER/TEXT','PK; FK; estado enumerado','Motivo e revisão humana.'))
)
Add-Rows 29 @(
    (Make-Row @('RN01','Montante positivo; saldo nunca negativo.','BankService e CHECK SQLite.','T06, T09')),
    (Make-Row @('RN02','Transferência exige contas ativas distintas e saldo suficiente.','BankService e transação SQLite.','T07–T10')),
    (Make-Row @('RN03','Empréstimo liga cliente e conta do mesmo titular.','BankService e FKs.','T16')),
    (Make-Row @('RN04','Pedido aprovado só credita uma vez.','Decisão condicional e transação.','T13–T14')),
    (Make-Row @('RN05','Limiar de operação cria alerta para revisão.','BankService.','T11–T12'))
)
Add-Rows 32 @(
    (Make-Row @('PHP','8.5.12 testado; requisito 8.2+','Aplicação e domínio.','Tecnologia exigida.')),
    (Make-Row @('HTML5','Padrão do navegador','Formulários e páginas.','Sem dependência externa.')),
    (Make-Row @('CSS3','Padrão do navegador','Estilos responsivos.','Sem biblioteca externa.')),
    (Make-Row @('JavaScript','ES6 do navegador','Confirmação e melhoria de validação.','Sem dependência externa.')),
    (Make-Row @('SQLite / PDO_SQLITE','Versão distribuída com PHP','Persistência relacional local.','Restrições SQL sem servidor separado.'))
)
Add-Rows 34 @(
    (Make-Row @('public/index.php','Apresentação, navegação e formulários.','BankService, helpers.')),
    (Make-Row @('app/BankService.php','Regras de domínio e transações.','PDO.')),
    (Make-Row @('app/Database.php; database/schema.sql','Ligação, esquema e dados fictícios.','PDO_SQLITE.')),
    (Make-Row @('app/helpers.php; public/assets/*','Escape, CSRF, formatação e estilos.','Sessão PHP e navegador.')),
    (Make-Row @('tests; docs','Testes, relatório e fontes dos diagramas.','PHP CLI; PlantUML.'))
)
Add-Rows 37 @(
    (Make-Row @('DA01','Aplicação única, separada por responsabilidade.','Microserviços/framework.','Menos configuração; adequado a estudante.','Sem isolamento de serviços.')),
    (Make-Row @('DA02','SQLite via PDO.','MySQL ou JSON.','Ficheiro simples com relações SQL.','Limites de concorrência e operação.')),
    (Make-Row @('DA03','Dinheiro em cêntimos inteiros.','Ponto flutuante.','Evita erros binários de arredondamento.','Conversão de entrada necessária.')),
    (Make-Row @('DA04','Sem autenticação nesta versão.','Sessões e perfis.','Reduz âmbito de aprendizagem.','Não pode ser exposta nem usada em produção.'))
)
Add-Rows 38 @(
    (Make-Row @('Validação de entradas','Regras verificadas em BankService, além da interface.')),
    (Make-Row @('Acesso a dados','PDO com parâmetros; chaves estrangeiras e restrições SQLite.')),
    (Make-Row @('Credenciais','Não existem credenciais nem palavras-passe no código.')),
    (Make-Row @('Dados pessoais','Apenas nomes e contactos fictícios com domínio .test.')),
    (Make-Row @('Erros','Mensagens de domínio são apresentadas; detalhes PDO ficam ocultos.')),
    (Make-Row @('Qualidade','Ficheiros por responsabilidade; nomes claros; testes de regras.')),
    (Make-Row @('Interface','Navegação consistente, rótulos e confirmação para ações de estado.'))
)
Add-Rows 42 @(
    (Make-Row @('T01','RF01','Unidade','Cliente válido.','Registar e consultar.','Cliente disponível.','Passou.','Passou')),
    (Make-Row @('T02','RF01','Unidade','E-mail já usado.','Tentar repetir registo.','Rejeição sem duplicado.','Passou.','Passou')),
    (Make-Row @('T03','RF09','Unidade','Funcionário válido.','Registar funcionário.','Funcionário disponível.','Passou.','Passou')),
    (Make-Row @('T04','RF02','Unidade','Cliente existente.','Abrir contas corrente e poupança.','Contas associadas ao cliente.','Passou.','Passou')),
    (Make-Row @('T05','RF02','Unidade','Cliente 999 inexistente.','Tentar abrir conta.','Rejeição.','Passou.','Passou')),
    (Make-Row @('T06','RF03/RN01','Unidade','Conta ativa; 1 000 EUR.','Depositar.','Saldo aumenta.','Passou.','Passou')),
    (Make-Row @('T07','RF04/RN02','Unidade','Duas contas; 250 EUR.','Transferir.','Origem diminui.','Passou.','Passou')),
    (Make-Row @('T08','RF04/RN02','Unidade','Duas contas; 250 EUR.','Transferir.','Destino aumenta.','Passou.','Passou')),
    (Make-Row @('T09','RF04/RN01','Unidade','Montante acima do saldo.','Levantar.','Rejeita sem saldo negativo.','Passou.','Passou')),
    (Make-Row @('T10','RF04/RN02','Unidade','Origem igual a destino.','Transferir.','Rejeição.','Passou.','Passou')),
    (Make-Row @('T11','RF11/RN05','Unidade','Operação de 3 000 EUR.','Registar.','Alerta por rever.','Passou.','Passou')),
    (Make-Row @('T12','RF12','Unidade','Alerta por rever.','Marcar revisto.','Estado Revisto.','Passou.','Passou')),
    (Make-Row @('T13','RF08/RN04','Unidade','Pedido pendente.','Aprovar.','Conta creditada e estado aprovado.','Passou.','Passou')),
    (Make-Row @('T14','RF08/RN04','Unidade','Pedido já aprovado.','Tentar decidir novamente.','Rejeição.','Passou.','Passou')),
    (Make-Row @('T15','RF06','Unidade','Conta ativa.','Emitir e bloquear cartão.','Estado Bloqueado.','Passou.','Passou')),
    (Make-Row @('T16','RF07/RN03','Unidade','Conta de cliente diferente.','Criar pedido.','Rejeição.','Passou.','Passou')),
    (Make-Row @('T17','RF05/RF10','Unidade','Dois clientes, três contas.','Consultar totais.','Totais coerentes.','Passou.','Passou')),
    (Make-Row @('T18','RNF01','HTTP local','GET e levantamento sem saldo.','Submeter POST.','HTTP 200 e mensagem de erro.','HTTP 200; “Saldo insuficiente”.','Passou')),
    (Make-Row @('T19','RNF04','Sintaxe','Cinco ficheiros PHP.','Executar php -l.','Sem erros.','Sem erros nos cinco ficheiros.','Passou')),
    (Make-Row @('T20','RF01','Manual UI','Cliente fictício novo.','Preencher e submeter formulário.','Cliente listado.','Não executado.','Não executado')),
    (Make-Row @('T21','RF02','Manual UI','Cliente existente.','Abrir conta.','Conta ativa com saldo zero.','Não executado.','Não executado')),
    (Make-Row @('T22','RF03','Manual UI','Conta ativa.','Depositar e consultar saldo.','Saldo aumenta pelo montante.','Não executado.','Não executado')),
    (Make-Row @('T23','RF04','Manual UI','Saldo inferior ao levantamento.','Submeter levantamento.','Erro e saldo inalterado.','Não executado.','Não executado')),
    (Make-Row @('T24','RF04','Manual UI','Duas contas fictícias.','Registar transferência.','Saldos de origem e destino atualizados.','Não executado.','Não executado')),
    (Make-Row @('T25','RF06','Manual UI','Conta ativa.','Emitir e bloquear cartão; confirmar.','Cartão listado como Bloqueado.','Não executado.','Não executado')),
    (Make-Row @('T26','RF07/RF08','Manual UI','Cliente e conta existentes.','Criar pedido e aprovar.','Pedido aprovado e saldo creditado.','Não executado.','Não executado')),
    (Make-Row @('T27','RF11/RF12','Manual UI','Alerta por rever.','Consultar e marcar revisto.','Alerta passa a Revisto.','Não executado.','Não executado')),
    (Make-Row @('T28','RNF03','Manual UI','Dados criados localmente.','Reiniciar servidor e consultar.','Dados continuam persistidos.','Não executado.','Não executado'))
)
Add-Rows 43 @(
    (Make-Row @('Unidade (assertions)','18','18','0','0')),
    (Make-Row @('HTTP e sintaxe','2','2','0','0')),
    (Make-Row @('Roteiro manual','9','0','0','9'))
)
Add-Rows 45 @(
    (Make-Row @('RF01','Essencial','UC01','US01','BankService; Clientes','T01–T02','Verificado')),
    (Make-Row @('RF02','Essencial','UC02','US02','BankService; Contas','T04–T05','Verificado')),
    (Make-Row @('RF03','Essencial','UC03','US03','BankService::transact','T06','Verificado')),
    (Make-Row @('RF04','Essencial','UC03','US03','BankService::transact','T07–T10, T18','Verificado')),
    (Make-Row @('RF05','Essencial','UC03','US03','BankService; Painel/Operações','T17–T18','Verificado')),
    (Make-Row @('RF06','Importante','UC03','US04','BankService; Cartões','T15','Verificado')),
    (Make-Row @('RF07','Importante','UC04','US05','BankService::createLoan','T16','Verificado')),
    (Make-Row @('RF08','Importante','UC04','US05','BankService::decideLoan','T13–T14','Verificado')),
    (Make-Row @('RF09','Importante','UC01','US01','BankService; Funcionários','T03','Verificado')),
    (Make-Row @('RF10','Essencial','UC03','US03','BankService::summary; Painel','T17','Verificado')),
    (Make-Row @('RF11','Importante','UC05','US06','BankService::alertReason','T11','Verificado')),
    (Make-Row @('RF12','Importante','UC05','US06','BankService::markAlertReviewed','T12','Verificado'))
)
Add-Rows 48 @(
    (Make-Row @('L01','Sem autenticação ou autorização por perfil.','Acesso local sem identidade.','Acrescentar se exigido pelo âmbito.')),
    (Make-Row @('L02','Alertas usam limiares fixos e não detetam fraude.','Falsos positivos/negativos.','Definir regras com especialista.')),
    (Make-Row @('L03','Só há captura do painel e falta roteiro manual completo.','Evidência visual parcial.','Executar percurso e capturar outros ecrãs.')),
    (Make-Row @('L04','Algumas ações não têm teste automático individual.','Cobertura de regressão limitada.','Ampliar testes de integração.')),
    (Make-Row @('L05','Empréstimo não calcula juros nem solvabilidade.','Crédito apenas demonstrativo.','Implementar regras académicas controladas.')),
    (Make-Row @('L06','Repositório remoto não foi obtido.','Sem commit remoto associado.','Sincronizar quando houver acesso.'))
)
Add-Rows 52 @((Make-Row @('ChatGPT / Codex','2026-10-29','Apoio à implementação, testes, diagramas e redação.','Código, testes e relatório.','Revisão de código; execução de 18 verificações; registo de limites.')))
Add-Rows 53 @(
    (Make-Row @('PHP Manual','php.net','CC BY 3.0 (texto do manual)','Consulta de PDO_SQLITE.')),
    (Make-Row @('SQLite documentation','sqlite.org','Domínio público','Consulta de restrições e esquema.')),
    (Make-Row @('ISO/IEC/IEEE 29148:2018','ISO','Publicação protegida; apenas citada','Referência de engenharia de requisitos.'))
)

foreach ($number in $script:data.Keys) { Set-TableRows ([int]$number) $script:data[$number] }
Set-OneCell 19 'Diagrama de casos de uso UML; fonte: docs/diagramas/figura-1-casos-de-uso.puml.'
Set-OneCell 25 'Modelo conceptual de Cliente, Conta, Operação, Cartão, Empréstimo, Funcionário e Alerta; fonte: docs/diagramas/figura-2-modelo-dominio.puml.'
Set-OneCell 26 'Diagrama entidade-relação SQLite com chaves e cardinalidades; fonte: docs/diagramas/figura-3-modelo-dados.puml.'
Set-OneCell 31 'Arquitetura em camadas: apresentação PHP, serviço BankService e persistência PDO/SQLite; fonte docs/diagramas/figura-4-arquitetura.puml.'
Set-OneCell 33 'app/  BankService.php (domínio) · Database.php (persistência) · helpers.php; database/schema.sql; public/index.php e assets (apresentação); tests/run.php; docs/diagramas; README.md.'
Set-OneCell 35 'Sequência da operação: Operador → Página Operações → BankService → SQLite → resultado. Fonte: docs/diagramas/figura-6-sequencia-operacao.puml.'
Set-OneCell 40 'Instalar PHP 8.2+ com pdo_sqlite e sqlite3; executar php -S 127.0.0.1:8000 -t public; abrir http://127.0.0.1:8000; executar php tests/run.php. O código corresponde à tag local v1.0.0.'
Set-CellImage 19 'rId91' 'figura-1.png'
Set-CellImage 25 'rId92' 'figura-2.png'
Set-CellImage 26 'rId93' 'figura-3.png'
Set-CellImage 31 'rId94' 'figura-4-arquitetura.png'
Set-CellImage 33 'rId95' 'figura-5-estrutura.png'
Set-CellImage 35 'rId96' 'figura-6-sequencia.png'
Set-CellImage 47 'rId97' 'painel.png'
Set-OneCell 54 'Fontes dos diagramas: docs/diagramas/figura-1-casos-de-uso.puml; figura-2-modelo-dominio.puml; figura-3-modelo-dados.puml; figura-4-arquitetura.puml; figura-5-estrutura.svg; figura-6-sequencia-operacao.puml.'

$replacements = [ordered]@{
    '[Nome do Projeto]'='Sistema de Gestão Bancária'; '[Curso]'='Engenharia de Software'; '[x.y]'='1.0'; '[aaaa-mm-dd]'='2026-10-29';
    '[Nome do aluno]'='Thaniel Jorge Guimarães Pedro'; '[número do aluno]'='13658'; '[e-mail do aluno]'='por preencher';
    '[Nome do docente]'='por preencher'; '[URL do repositório]'='https://github.com/supernova17-art/Sistema-de-gestao-Bancaria-.git'; '[tag ou commit]'='tag local v1.0.0 (não sincronizada)';
    '[Resumo]'='Este projeto demonstra a gestão local de clientes, contas e operações bancárias fictícias. A aplicação permite criar clientes e contas, registar depósitos, levantamentos e transferências, emitir e bloquear cartões, decidir pedidos de empréstimo, gerir funcionários e rever alertas de risco. Foi desenvolvida com PHP, HTML, CSS, JavaScript e SQLite através de PDO. A arquitetura separa a interface em páginas PHP, as regras no serviço BankService e a persistência em tabelas relacionais com restrições e consultas parametrizadas. A versão 1.0 inclui validação no servidor, proteção CSRF, dados fictícios e operações financeiras atómicas. Foram executadas 18 verificações automatizadas, sem falhas, além de testes HTTP e validação de sintaxe. A aplicação é didática, não possui autenticação e não deve ser usada em produção.';
    '[3 a 5 palavras-chave, separadas por ponto e vírgula]'='banca; PHP; SQLite; operações financeiras; testes de software';
    'Índice por gerar: selecione esta linha e prima F9 (ou clique com o botão direito › Atualizar campo).'='1. Introdução; 2. Análise de Contexto; 3. Requisitos; 4. Casos de Uso; 5. User Stories; 6. Modelo de Domínio e Modelo de Dados; 7. Arquitetura e Implementação; 8. Testes e Validação; 9. Apresentação do Produto Final; 10. Conclusão e Reflexão; Referências; Anexos.';
    'Lista de figuras por gerar: selecione esta linha e prima F9.'='Figura 1. Casos de uso; Figura 2. Modelo de domínio; Figura 3. Modelo de dados; Figura 4. Arquitetura; Figura 5. Estrutura do projeto; Figura 6. Sequência de operação; Figura 7. Painel de controlo.';
    'Lista de tabelas por gerar: selecione esta linha e prima F9.'='Tabelas: Controlo do documento; utilizadores; âmbito; necessidades; pressupostos; glossário; prioridades; requisitos; atores; casos de uso; histórias; dicionário; regras; tecnologias; módulos; decisões; segurança; testes; resultados; rastreabilidade; limitações; utilização de IA; recursos externos.';
    '[Descreva o problema em 2 a 4 frases. Indique o objetivo numa frase iniciada por «O objetivo deste projeto é…».]'='Uma instituição bancária gere clientes, contas e operações que precisam de ficar relacionados e consultáveis. Registos inconsistentes podem permitir operações inválidas, como levantamentos acima do saldo. Este projeto demonstra validações e persistência numa aplicação local. O objetivo deste projeto é desenvolver uma aplicação didática que registe informação bancária fictícia e aplique regras básicas de gestão.';
    '[Frase de introdução que refira a Tabela N.]'='A tabela seguinte apresenta os elementos desta secção.';
    '[Funcionalidade incluída]'='Clientes, contas, operações, cartões, empréstimos, funcionários, painel e alertas.';
    '[Funcionalidade excluída]'='Autenticação, redes bancárias, processamento real de pagamentos e produção.';
    '[Descreva a situação em que a aplicação será usada e de onde vêm os requisitos. Distinga o que foi confirmado (por entrevista, observação ou documento) do que é um pressuposto.]'='O cenário é um pressuposto académico baseado no enunciado. Não foram observados processos de uma instituição bancária real. Os limiares dos alertas e os detalhes das regras são pressupostos de demonstração.';
    '[Como é realizada atualmente a tarefa, que ferramentas são usadas e que problemas existem.]'='Não foi observada uma instituição bancária real. O projeto assume um registo central de demonstração para consultar contas e operações; os problemas e regras são pressupostos académicos.';
    '[Termo ou sigla]'='PDO'; '[Definição]'='PHP Data Objects; interface de acesso a dados do PHP.';
    '[Descreva as prioridades]'='Essencial indica requisitos implementados e testados nesta versão; Importante identifica funções de apoio ao percurso; Opcional identifica trabalho futuro.';
    '[Categoria]'='Segurança'; '[Critério]'='Inspeção do código e execução local.';
    '[Inserir aqui o diagrama de casos de uso]'='';
    '[Breve introdução ao percurso apresentado.]'='A Figura 7 mostra o Painel de controlo com dados fictícios carregados pela aplicação em execução.';
    '[Frase de introdução que refira a Figura N.]'='A figura seguinte apresenta o modelo ou percurso descrito nesta secção.';
    '[Frase de introdução que refira a Figura N e a Tabela N.]'='A Figura 3 e a Tabela 13 apresentam o esquema SQLite e os atributos persistidos.';
    '[Descrição dos conceitos principais e das suas relações, com referência à Figura N.]'='A Figura 2 apresenta Cliente, Conta, Operação, Cartão, Empréstimo, Funcionário e Alerta e as respetivas relações.';
    '[Descrição do modelo de dados, com referência à Figura N e à Tabela N.]'='A Figura 3 apresenta as tabelas relacionais; a Tabela 9 resume atributos e restrições. Os valores monetários são guardados em cêntimos.';
    '[Descrição da arquitetura: camadas de apresentação, de lógica de aplicação e domínio, e de persistência, com referência à Figura N.]'='A Figura 4 apresenta a apresentação HTML/PHP, as regras em BankService e a persistência SQLite por PDO.';
    '[Descreva, passo a passo, uma operação completa desde a interface até à persistência, com referência à Figura N.]'='A Figura 6 mostra o formulário a enviar POST com CSRF; BankService valida e inicia transação; PDO atualiza saldo e histórico e cria alerta se necessário; a interface apresenta o resultado.';
    '[nome da operação]'='transferência';
    '[Pré-requisitos: software necessário e respetivas versões]'='PHP 8.2+ com pdo_sqlite e sqlite3; Windows 11; navegador atualizado.';
    '[software necessário e respetivas versões]'='PHP 8.2+ com pdo_sqlite e sqlite3; Windows 11; navegador atualizado.';
    '[Indique o que é testado automaticamente e o que é testado manualmente, as ferramentas usadas e o ambiente de execução (sistema operativo e versões).]'='As regras principais são testadas automaticamente em SQLite em memória. A interface foi verificada por HTTP local; o roteiro manual completo fica por executar. Ambiente: Windows 11 e PHP 8.5.12.';
    '[data; sistema operativo; versões]'='2026-10-29; Windows 11; PHP 8.5.12 com PDO_SQLITE.';
    '[Resuma o que foi concretizado face ao objetivo da secção 1.1, com base na matriz de rastreabilidade (por exemplo, «Foram implementados e testados 8 dos 9 requisitos essenciais»).]'='Foram implementados RF01–RF12; as verificações e o estado observado de cada requisito constam na matriz de rastreabilidade. O roteiro manual completo permanece por executar.';
    '[Nome] · 2026-10-29'='[Nome] · [data]';
    '[Inserir aqui a captura de ecrã]'='docs/capturas/painel.png';
    '[Nome do ecrã]'='Painel de controlo'; '[requisitos ilustrados]'='RF05, RF10';
    '[O que a figura mostra e como o utilizador interage com o ecrã.]'='A página resume clientes, contas ativas, pedidos pendentes, alertas e operações recentes.';
    '[Objetivos alcançados]'='Foram implementadas as funcionalidades RF01–RF12; os testes e o estado de cada requisito constam na matriz de rastreabilidade.';
    '[Limitações e problemas conhecidos]'='As limitações principais são ausência de autenticação, alertas demonstrativos, cobertura manual incompleta e falta de commit remoto.';
    '[Melhorias e funcionalidades a desenvolver, por ordem de prioridade.]'='Completar o roteiro manual; ampliar testes; adicionar relatórios filtráveis; avaliar autenticação apenas se exigida; sincronizar o repositório.';
    '[Reflexão pessoal]'='A preencher pelo estudante. O que aprendi de mais importante com este projeto? Que decisão técnica consigo justificar melhor, e porquê? Qual foi a principal dificuldade e como a resolvi? Que sugestões das ferramentas de IA tive de corrigir, adaptar ou rejeitar, e porquê? O que faria de forma diferente num próximo projeto?';
    '[Referência]'='PHP Documentation Group. (s.d.). SQLite PDO driver. PHP Manual. https://www.php.net/manual/en/ref.pdo-sqlite.php';
    '[Ferramenta]'='ChatGPT / Codex'; '[Versão ou data]'='2026-10-29'; '[Finalidade]'='Apoio à implementação e documentação.'; '[Partes]'='Código, testes, diagramas e relatório.'; '[Verificação]'='Revisão e testes executados.';
    '[Recurso]'='Documentação oficial'; '[Origem]'='php.net, sqlite.org e iso.org'; '[Licença]'='Documentação'; '[Utilização]'='Referências técnicas.';
    '[Nome] · [aaaa-mm-dd]'='Por preencher · por preencher';
    '[Código PlantUML (ou equivalente) de cada diagrama, identificado pelo número da figura. Os ficheiros devem estar também no repositório, na pasta docs/diagramas.]'='Fontes PlantUML identificadas pelas Figuras 1–4 em docs/diagramas/.';
    '[Saída da ferramenta de testes, em texto, com a data e a versão do código.]'='2026-10-29 · PHP 8.5.12 · 18 verificações passaram; 0 falharam. Registo completo: docs/registo-testes.txt.';
    '[Descrição dos dados fictícios utilizados e da forma de os carregar.]'='Ana Silva, João Costa, Rita Gomes, Paulo Reis e duas contas; são criados automaticamente no primeiro arranque.'
}
foreach ($paragraph in $document.SelectNodes('//w:p', $ns)) {
    $oldText = Get-Text $paragraph
    if ($oldText.StartsWith('Sommerville, I. (2016).')) { $paragraph.ParentNode.RemoveChild($paragraph) | Out-Null; continue }
    if ($oldText.StartsWith('Exemplo:')) { $paragraph.ParentNode.RemoveChild($paragraph) | Out-Null; continue }
    $newText = $oldText
    foreach ($key in $replacements.Keys) { $newText = $newText.Replace([string]$key, [string]$replacements[$key]) }
    $newText = $newText.Replace('Tabela 11. Especificação do caso de uso [UC01]', 'Tabela 11. Especificação dos casos de uso essenciais')
    $newText = $newText.Replace('Use a forma «O sistema deve permitir que [ator] [ação] [objeto] [condição]». Evite termos vagos como «rápido», «fácil», «intuitivo», «adequado», «etc.» e «e/ou». Referência: ISO/IEC/IEEE 29148.', 'Os requisitos são redigidos como capacidades verificáveis, com ator e condição, e usam identificadores estáveis RF01–RF12.')
    $newText = $newText.Replace('Use o formato «Como [tipo de utilizador], quero [objetivo], para [benefício]». Cada história deve ser pequena, ter valor para o utilizador e ser testável.', 'As histórias de utilizador e os critérios de aceitação estão identificados na Tabela 12.')
    if ($newText -ne $oldText) { Set-Text $paragraph $newText }
}
$phpReference = $null
foreach ($paragraph in $document.SelectNodes('//w:p', $ns)) { if ((Get-Text $paragraph).StartsWith('PHP Documentation Group. (s.d.).')) { $phpReference = $paragraph; break } }
if ($phpReference) {
    $afterReference = $phpReference
    $extraReferences = @(
        'PHP Documentation Group. (s.d.). PHP Licensing. https://www.php.net/license/',
        'SQLite Consortium. (s.d.). CREATE TABLE. SQLite documentation. https://www.sqlite.org/lang_createtable.html',
        'SQLite Consortium. (s.d.). Copyright. https://www.sqlite.org/copyright.html'
    )
    foreach ($referenceText in $extraReferences) {
        $newReference = $phpReference.CloneNode($true)
        Set-Text $newReference $referenceText
        $phpReference.ParentNode.InsertAfter($newReference, $afterReference) | Out-Null
        $afterReference = $newReference
    }
}

# Remove the instruction page and final checklist while retaining the template body and section properties.
$children = @($body.ChildNodes)
$coverIndex = -1
$checkIndex = -1
for ($i = 0; $i -lt $children.Count; $i++) {
    if ($children[$i].LocalName -eq 'p') {
        $text = Get-Text $children[$i]
        if ($text -eq 'Sistema de Gestão Bancária') { $coverIndex = $i; break }
    }
}
if ($coverIndex -gt 0) { for ($i = 0; $i -lt $coverIndex; $i++) { $body.RemoveChild($children[$i]) | Out-Null } }
$children = @($body.ChildNodes)
for ($i = 0; $i -lt $children.Count; $i++) {
    if ($children[$i].LocalName -eq 'p' -and (Get-Text $children[$i]) -eq 'Lista de verificação final') { $checkIndex = $i; break }
}
if ($checkIndex -ge 0) { for ($i = $children.Count - 1; $i -ge $checkIndex; $i--) { if ($children[$i].LocalName -ne 'sectPr') { $body.RemoveChild($children[$i]) | Out-Null } } }

# Delete all blue instruction callout tables from the retained report.
foreach ($table in @($document.SelectNodes('//w:tbl', $ns))) {
    if ((Get-Text $table).StartsWith('ORIENTAÇÕES')) { $table.ParentNode.RemoveChild($table) | Out-Null }
}

$memory = [System.IO.MemoryStream]::new()
$settings = [System.Xml.XmlWriterSettings]::new(); $settings.Encoding = [System.Text.UTF8Encoding]::new($false); $settings.Indent = $false
$writer = [System.Xml.XmlWriter]::Create($memory, $settings)
try { $document.Save($writer); $writer.Flush(); $memory.Position = 0 } finally { $writer.Dispose() }

$outPath = [System.IO.Path]::GetFullPath($Output)
if (Test-Path $outPath) { Remove-Item -LiteralPath $outPath -Force }
$outStream = [System.IO.File]::Open($outPath, [System.IO.FileMode]::CreateNew)
$target = [System.IO.Compression.ZipArchive]::new($outStream, [System.IO.Compression.ZipArchiveMode]::Create, $true)
try {
    foreach ($item in $source.Entries) {
        if ($item.FullName -eq 'word/media/painel.png') { continue }
        $newEntry = $target.CreateEntry($item.FullName, [System.IO.Compression.CompressionLevel]::Optimal)
        $destination = $newEntry.Open()
        try {
            if ($item.FullName -eq 'word/document.xml') { $memory.Position = 0; $memory.CopyTo($destination) }
            elseif ($item.FullName -eq 'word/_rels/document.xml.rels') {
                $relStream = $item.Open(); $relReader = [IO.StreamReader]::new($relStream); try { [xml]$rels = $relReader.ReadToEnd() } finally { $relReader.Dispose(); $relStream.Dispose() }
                $relNs = 'http://schemas.openxmlformats.org/package/2006/relationships'
                $imageRelationships = @(
                    @{Id='rId91';Target='media/figura-1.png'},@{Id='rId92';Target='media/figura-2.png'},@{Id='rId93';Target='media/figura-3.png'},
                    @{Id='rId94';Target='media/figura-4-arquitetura.png'},@{Id='rId95';Target='media/figura-5-estrutura.png'},@{Id='rId96';Target='media/figura-6-sequencia.png'},@{Id='rId97';Target='media/painel.png'}
                )
                foreach ($imageRelationship in $imageRelationships) {
                    $relationship = $rels.CreateElement('Relationship',$relNs); $relationship.SetAttribute('Id',$imageRelationship.Id); $relationship.SetAttribute('Type','http://schemas.openxmlformats.org/officeDocument/2006/relationships/image'); $relationship.SetAttribute('Target',$imageRelationship.Target); $rels.DocumentElement.AppendChild($relationship) | Out-Null
                }
                $rels.Save($destination)
            }
            elseif ($item.FullName -eq '[Content_Types].xml') {
                $typeStream = $item.Open(); $typeReader = [IO.StreamReader]::new($typeStream); try { [xml]$types = $typeReader.ReadToEnd() } finally { $typeReader.Dispose(); $typeStream.Dispose() }
                $typeNs = 'http://schemas.openxmlformats.org/package/2006/content-types'
                $default = $types.CreateElement('Default',$typeNs); $default.SetAttribute('Extension','png'); $default.SetAttribute('ContentType','image/png'); $types.DocumentElement.AppendChild($default) | Out-Null
                $types.Save($destination)
            }
            elseif ($item.FullName -eq 'word/settings.xml') {
                $settingsStream = $item.Open(); $settingsReader = [IO.StreamReader]::new($settingsStream); try { [xml]$settingsXml = $settingsReader.ReadToEnd() } finally { $settingsReader.Dispose(); $settingsStream.Dispose() }
                $settingsNs = [Xml.XmlNamespaceManager]::new($settingsXml.NameTable); $settingsNs.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main')
                $updateFields = $settingsXml.SelectSingleNode('/w:settings/w:updateFields',$settingsNs)
                if (-not $updateFields) { $updateFields = $settingsXml.CreateElement('w','updateFields','http://schemas.openxmlformats.org/wordprocessingml/2006/main'); $settingsXml.DocumentElement.AppendChild($updateFields) | Out-Null }
                [void]$updateFields.SetAttribute('val','http://schemas.openxmlformats.org/wordprocessingml/2006/main','true')
                $settingsXml.Save($destination)
            }
            else { $stream = $item.Open(); try { $stream.CopyTo($destination) } finally { $stream.Dispose() } }
        } finally { $destination.Dispose() }
    }
    $images = @(
        @{Name='figura-1.png';Path=(Join-Path $PSScriptRoot '..\docs\diagramas\png\figura-1.png')},
        @{Name='figura-2.png';Path=(Join-Path $PSScriptRoot '..\docs\diagramas\png\figura-2.png')},
        @{Name='figura-3.png';Path=(Join-Path $PSScriptRoot '..\docs\diagramas\png\figura-3.png')},
        @{Name='figura-4-arquitetura.png';Path=(Join-Path $PSScriptRoot '..\docs\diagramas\png\figura-4-arquitetura.png')},
        @{Name='figura-5-estrutura.png';Path=(Join-Path $PSScriptRoot '..\docs\diagramas\png\figura-5-estrutura.png')},
        @{Name='figura-6-sequencia.png';Path=(Join-Path $PSScriptRoot '..\docs\diagramas\png\figura-6-sequencia.png')},
        @{Name='painel.png';Path=(Join-Path $PSScriptRoot '..\docs\capturas\painel.png')}
    )
    foreach ($image in $images) {
        $imageEntry = $target.CreateEntry('word/media/' + $image.Name, [System.IO.Compression.CompressionLevel]::Optimal)
        $imageStream = $imageEntry.Open(); $fileStream = [IO.File]::OpenRead((Resolve-Path $image.Path))
        try { $fileStream.CopyTo($imageStream) } finally { $fileStream.Dispose(); $imageStream.Dispose() }
    }
} finally { $target.Dispose(); $outStream.Dispose(); $source.Dispose(); $memory.Dispose() }
Write-Output "Relatório criado: $outPath"
