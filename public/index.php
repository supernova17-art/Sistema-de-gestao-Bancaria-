<?php
declare(strict_types=1);

session_start();
require_once dirname(__DIR__) . '/app/helpers.php';
require_once dirname(__DIR__) . '/app/Database.php';
require_once dirname(__DIR__) . '/app/BankService.php';

try {
    $service = new BankService(Database::connect());
} catch (Throwable $error) {
    http_response_code(500);
    exit('Não foi possível abrir a base de dados. Confirme se pdo_sqlite está ativo e se a pasta storage tem permissões de escrita.');
}

$page = (string) ($_GET['page'] ?? 'dashboard');
$allowedPages = ['dashboard','customers','accounts','operations','cards','loans','employees','alerts'];
if (!in_array($page, $allowedPages, true)) $page = 'dashboard';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        verify_csrf();
        $action = (string) ($_POST['action'] ?? '');
        switch ($action) {
            case 'customer':
                $service->createCustomer((string)($_POST['name'] ?? ''),(string)($_POST['email'] ?? ''),(string)($_POST['phone'] ?? ''));
                $page='customers'; flash('Cliente registado.'); break;
            case 'employee':
                $service->createEmployee((string)($_POST['name'] ?? ''),(string)($_POST['role'] ?? ''),(string)($_POST['email'] ?? ''));
                $page='employees'; flash('Funcionário registado.'); break;
            case 'account':
                $service->createAccount((int)($_POST['customer_id'] ?? 0),(string)($_POST['type'] ?? ''));
                $page='accounts'; flash('Conta aberta com saldo inicial de 0,00 €.'); break;
            case 'transaction':
                $type=(string)($_POST['type'] ?? '');
                $service->transact($type,(int)($_POST['from_id'] ?? 0),isset($_POST['to_id'])?(int)$_POST['to_id']:null,parse_amount((string)($_POST['amount'] ?? '')),(int)($_POST['employee_id'] ?? 0));
                $page='operations'; flash('Operação registada.'); break;
            case 'issue_card':
                $service->issueCard((int)($_POST['account_id'] ?? 0)); $page='cards'; flash('Cartão emitido.'); break;
            case 'toggle_card':
                $service->toggleCard((int)($_POST['card_id'] ?? 0)); $page='cards'; flash('Estado do cartão atualizado.'); break;
            case 'loan':
                $service->createLoan((int)($_POST['customer_id'] ?? 0),(int)($_POST['account_id'] ?? 0),parse_amount((string)($_POST['amount'] ?? '')),(int)($_POST['term'] ?? 0));
                $page='loans'; flash('Pedido de empréstimo registado.'); break;
            case 'decide_loan':
                $service->decideLoan((int)($_POST['loan_id'] ?? 0),(string)($_POST['decision'] ?? ''),(int)($_POST['employee_id'] ?? 0));
                $page='loans'; flash('Decisão registada.'); break;
            case 'review_alert':
                $service->markAlertReviewed((int)($_POST['alert_id'] ?? 0)); $page='alerts'; flash('Alerta marcado como revisto.'); break;
            default: throw new DomainException('Ação desconhecida.');
        }
    } catch (DomainException $error) {
        flash($error->getMessage(), 'error');
    } catch (PDOException $error) {
        flash('Não foi possível guardar os dados. Verifique se os campos são únicos e se as relações são válidas.', 'error');
    } catch (Throwable $error) {
        flash('Ocorreu um erro inesperado. Tente novamente.', 'error');
    }
    header('Location: ?page=' . urlencode($page));
    exit;
}

$customers=$service->customers(); $accounts=$service->accounts(); $employees=$service->employees();
$summary=$service->summary(); $flash=take_flash();
$titleMap=['dashboard'=>'Painel de controlo','customers'=>'Clientes','accounts'=>'Contas','operations'=>'Operações','cards'=>'Cartões','loans'=>'Empréstimos','employees'=>'Funcionários','alerts'=>'Alertas'];
$title=$titleMap[$page];

function field(string $label, string $name, string $type='text', string $required='required'): void
{
    echo '<label>' . h($label) . '<input name="' . h($name) . '" type="' . h($type) . '" ' . $required . '></label>';
}
function select_field(string $label,string $name,array $items,string $valueKey,string $labelKey,?string $empty=null): void
{
    echo '<label>'.h($label).'<select name="'.h($name).'" required>';
    if($empty!==null) echo '<option value="">'.h($empty).'</option>';
    foreach($items as $item) {
        $optionLabel=$item[$labelKey]??null;
        if($optionLabel===null && isset($item['account_number'],$item['customer_name'])) $optionLabel=$item['account_number'].' · '.$item['customer_name'];
        echo '<option value="'.h($item[$valueKey]).'">'.h($optionLabel??'').'</option>';
    }
    echo '</select></label>';
}
function start_form(string $action): void { echo '<form method="post" class="form-grid"><input type="hidden" name="csrf" value="'.h(csrf_token()).'"><input type="hidden" name="action" value="'.h($action).'">'; }
function end_form(string $caption): void { echo '<button class="button" type="submit">'.h($caption).'</button></form>'; }
function table(array $headers,array $rows): void
{
    echo '<div class="table-wrap"><table><thead><tr>'; foreach($headers as $header) echo '<th>'.h($header).'</th>'; echo '</tr></thead><tbody>';
    if(!$rows) echo '<tr><td colspan="'.count($headers).'" class="empty">Sem registos.</td></tr>';
    foreach($rows as $row){ echo '<tr>'; foreach($row as $cell) echo '<td>'.$cell.'</td>'; echo '</tr>'; }
    echo '</tbody></table></div>';
}
function badge(string $text): string { $class=$text==='Ativo'||$text==='Ativa'||$text==='Aprovado'||$text==='Revisto'?'good':($text==='Por rever'||$text==='Pendente'?'warn':'muted'); return '<span class="badge '.$class.'">'.h($text).'</span>'; }
function op_form(string $type,array $accounts,array $employees): void
{
    start_form('transaction'); echo '<input type="hidden" name="type" value="'.h($type).'">';
    select_field($type==='Transferência'?'Conta de origem':'Conta',$type==='Transferência'?'from_id':'from_id',$accounts,'id','account_number · customer_name','Selecione uma conta');
    if($type==='Transferência') select_field('Conta de destino','to_id',$accounts,'id','account_number · customer_name','Selecione uma conta');
    field('Montante (€)','amount','number'); select_field('Funcionário','employee_id',$employees,'id','full_name','Selecione um funcionário');
    end_form($type);
}
?>
<!doctype html>
<html lang="pt-PT"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title><?=h($title)?> · Gestão Bancária</title><link rel="stylesheet" href="assets/app.css"><script defer src="assets/app.js"></script></head>
<body><div class="shell"><aside class="sidebar"><a class="brand" href="?page=dashboard"><span class="brand-mark">S</span><span>Sistema Bancário<small>Área de demonstração</small></span></a><nav><?php foreach($titleMap as $key=>$label): ?><a class="nav-link <?= $page===$key?'active':'' ?>" href="?page=<?=h($key)?>"><span class="nav-dot"></span><?=h($label)?></a><?php endforeach; ?></nav><p class="side-note">Dados fictícios<br>Ambiente local · sem autenticação</p></aside>
<main class="main"><header class="topbar"><div><div class="eyebrow">SISTEMA DE GESTÃO BANCÁRIA</div><h1><?=h($title)?></h1></div><span class="user-pill">TG <span>Operador de demonstração</span></span></header>
<?php if($flash): ?><div class="notice <?=h($flash['kind'])?>" role="status"><?=h($flash['message'])?></div><?php endif; ?>
<?php if($page==='dashboard'): ?>
<section class="welcome"><div><div class="eyebrow light">VISÃO GERAL</div><h2>Operações claras.<br>Contas sob controlo.</h2><p>Resumo local dos registos e atividade recente.</p></div><div class="welcome-art"><div class="art-card"><span>Saldo agregado</span><strong><?=money($summary['balance'])?></strong><small>em contas registadas</small><i>↗</i></div><div class="art-orbit"></div></div></section>
<section class="stats"><article class="stat-card"><span>Clientes</span><strong><?=h($summary['customers'])?></strong><small>registados</small></article><article class="stat-card"><span>Contas ativas</span><strong><?=h($summary['accounts'])?></strong><small>disponíveis</small></article><article class="stat-card"><span>Pedidos pendentes</span><strong><?=h($summary['pending_loans'])?></strong><small>por decidir</small></article><article class="stat-card"><span>Alertas por rever</span><strong><?=h($summary['open_alerts'])?></strong><small>requerem análise</small></article></section>
<section class="panel"><div class="panel-heading"><div><div class="eyebrow">MOVIMENTO</div><h2>Operações recentes</h2></div><a class="text-link" href="?page=operations">Ver operações →</a></div><?php $rows=[]; foreach($service->dashboardTransactions() as $r) $rows[]=[h($r['operation_type']),h($r['source_number']??'—'),money((int)$r['amount_cents']),h($r['employee_name']??'—'),h($r['created_at'])]; table(['Tipo','Conta origem','Montante','Funcionário','Data'],$rows); ?></section>
<?php elseif($page==='customers'): ?>
<section class="panel"><div class="panel-heading"><div><div class="eyebrow">REGISTO</div><h2>Novo cliente</h2></div></div><?php start_form('customer'); field('Nome completo','name'); field('E-mail','email','email'); field('Telefone','phone','tel'); end_form('Registar cliente'); ?></section>
<section class="panel"><div class="panel-heading"><div><div class="eyebrow">CARTEIRA</div><h2>Clientes registados</h2></div></div><?php $rows=[]; foreach($customers as $r)$rows[]=[h($r['full_name']),h($r['email']),h($r['phone']),h($r['created_at'])]; table(['Nome','E-mail','Telefone','Data de registo'],$rows); ?></section>
<?php elseif($page==='accounts'): ?>
<section class="panel"><div class="panel-heading"><div><div class="eyebrow">ABERTURA</div><h2>Nova conta</h2></div></div><?php start_form('account'); select_field('Cliente','customer_id',$customers,'id','full_name','Selecione um cliente'); echo '<label>Tipo de conta<select name="type"><option>Corrente</option><option>Poupança</option></select></label>'; end_form('Abrir conta'); ?></section>
<section class="panel"><div class="panel-heading"><div><div class="eyebrow">CONTAS</div><h2>Contas registadas</h2></div></div><?php $rows=[]; foreach($accounts as $r)$rows[]=[h($r['account_number']),h($r['customer_name']),h($r['account_type']),money((int)$r['balance_cents']),badge($r['status'])]; table(['Número','Cliente','Tipo','Saldo','Estado'],$rows); ?></section>
<?php elseif($page==='operations'): ?>
<div class="stats op-stats"><section class="panel op-panel"><div class="eyebrow">ENTRADA</div><h2>Depósito</h2><?php op_form('Depósito',$accounts,$employees); ?></section><section class="panel op-panel"><div class="eyebrow">SAÍDA</div><h2>Levantamento</h2><?php op_form('Levantamento',$accounts,$employees); ?></section><section class="panel op-panel"><div class="eyebrow">ENTRE CONTAS</div><h2>Transferência</h2><?php op_form('Transferência',$accounts,$employees); ?></section></div>
<section class="panel"><div class="panel-heading"><div><div class="eyebrow">HISTÓRICO</div><h2>Operações registadas</h2></div></div><?php $rows=[]; foreach($service->transactions() as $r)$rows[]=[h($r['operation_type']),h(($r['source_number']??'—').' → '.($r['target_number']??'')),money((int)$r['amount_cents']),h($r['employee_name']??'—'),h($r['created_at'])]; table(['Tipo','Contas','Montante','Funcionário','Data'],$rows); ?></section>
<?php elseif($page==='cards'): ?>
<section class="panel"><div class="panel-heading"><div><div class="eyebrow">EMISSÃO</div><h2>Novo cartão</h2></div></div><?php start_form('issue_card'); select_field('Conta ativa','account_id',array_values(array_filter($accounts,fn($a)=>$a['status']==='Ativa')),'id','account_number · customer_name','Selecione uma conta'); end_form('Emitir cartão de demonstração'); ?></section>
<section class="panel"><div class="panel-heading"><div><div class="eyebrow">CARTÕES</div><h2>Cartões emitidos</h2></div></div><?php $rows=[]; foreach($service->cards() as $r){$act='<form method="post" class="inline-form" data-confirm="Confirma a alteração do estado deste cartão?"><input type="hidden" name="csrf" value="'.h(csrf_token()).'"><input type="hidden" name="action" value="toggle_card"><input type="hidden" name="card_id" value="'.h($r['id']).'"><button class="button small" type="submit">'.($r['status']==='Ativo'?'Bloquear':'Ativar').'</button></form>';$rows[]=[h($r['card_number']),h($r['customer_name']),h($r['account_number']),badge($r['status']),$act];} table(['Cartão','Cliente','Conta','Estado','Ação'],$rows); ?></section>
<?php elseif($page==='loans'): ?>
<section class="panel"><div class="panel-heading"><div><div class="eyebrow">PEDIDO</div><h2>Novo empréstimo</h2></div></div><?php start_form('loan'); select_field('Cliente','customer_id',$customers,'id','full_name','Selecione um cliente'); select_field('Conta de crédito','account_id',$accounts,'id','account_number · customer_name','Selecione uma conta'); field('Montante (€)','amount','number'); field('Prazo (meses)','term','number'); end_form('Registar pedido'); ?></section>
<section class="panel"><div class="panel-heading"><div><div class="eyebrow">ANÁLISE</div><h2>Pedidos de empréstimo</h2></div></div><?php $rows=[]; foreach($service->loans() as $r){$action='—';if($r['status']==='Pendente'){$action='<form method="post" class="inline-form" data-confirm="Confirma a decisão do pedido?"><input type="hidden" name="csrf" value="'.h(csrf_token()).'"><input type="hidden" name="action" value="decide_loan"><input type="hidden" name="loan_id" value="'.h($r['id']).'"><select aria-label="Funcionário responsável" name="employee_id" required>';foreach($employees as $employee)$action.='<option value="'.h($employee['id']).'">'.h($employee['full_name']).'</option>';$action.='</select><button class="button small" name="decision" value="Aprovado">Aprovar</button><button class="button small secondary" name="decision" value="Recusado">Recusar</button></form>';}$rows[]=[h($r['customer_name']),money((int)$r['amount_cents']),h($r['term_months']).' meses',badge($r['status']),h($r['employee_name']??'—'),$action];} table(['Cliente','Montante','Prazo','Estado','Responsável','Ação'],$rows); ?></section>
<?php elseif($page==='employees'): ?>
<section class="panel"><div class="panel-heading"><div><div class="eyebrow">EQUIPA</div><h2>Novo funcionário</h2></div></div><?php start_form('employee'); field('Nome completo','name'); field('E-mail','email','email'); echo '<label>Perfil<select name="role"><option>Operador</option><option>Gestor</option></select></label>'; end_form('Registar funcionário'); ?></section>
<section class="panel"><div class="panel-heading"><div><div class="eyebrow">FUNCIONÁRIOS</div><h2>Equipa registada</h2></div></div><?php $rows=[]; foreach($employees as $r)$rows[]=[h($r['full_name']),h($r['email']),h($r['role']),badge($r['active']?'Ativo':'Inativo')]; table(['Nome','E-mail','Perfil','Estado'],$rows); ?></section>
<?php elseif($page==='alerts'): ?>
<section class="panel"><div class="panel-heading"><div><div class="eyebrow">REVISÃO MANUAL</div><h2>Alertas de risco</h2></div></div><p class="muted-text">Os limiares geram alertas para revisão. Não confirmam fraude nem substituem controlos bancários.</p><?php $rows=[]; foreach($service->alerts() as $r){$action=$r['status']==='Por rever'?'<form method="post" class="inline-form" data-confirm="Marcar este alerta como revisto?"><input type="hidden" name="csrf" value="'.h(csrf_token()).'"><input type="hidden" name="action" value="review_alert"><input type="hidden" name="alert_id" value="'.h($r['id']).'"><button class="button small" type="submit">Marcar revisto</button></form>':'—';$rows[]=[h($r['account_number']??'—'),h($r['operation_type']),money((int)$r['amount_cents']),h($r['reason']),badge($r['status']),$action];} table(['Conta','Operação','Montante','Motivo','Estado','Ação'],$rows); ?></section>
<?php endif; ?>
<footer>Projeto académico · Dados fictícios · <?=date('Y')?></footer></main></div></body></html>
