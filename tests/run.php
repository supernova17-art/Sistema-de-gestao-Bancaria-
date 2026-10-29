<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/app/BankService.php';

if (!in_array('sqlite', PDO::getAvailableDrivers(), true)) {
    fwrite(STDERR, "FALHA: o controlador PDO SQLite não está ativo.\n");
    exit(2);
}
$db = new PDO('sqlite::memory:');
$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$db->exec('PRAGMA foreign_keys = ON');
$db->exec((string) file_get_contents(dirname(__DIR__) . '/database/schema.sql'));
$service = new BankService($db);
$passed = 0;
$failed = 0;
$assert = static function (bool $condition, string $label) use (&$passed, &$failed): void {
    if ($condition) { echo "PASSOU: {$label}\n"; $passed++; }
    else { fwrite(STDERR, "FALHOU: {$label}\n"); $failed++; }
};
$throws = static function (callable $call, string $label) use ($assert): void {
    try { $call(); $assert(false, $label); }
    catch (DomainException) { $assert(true, $label); }
};

$service->createCustomer('Cliente Teste','cliente@example.test','910000010');
$assert(count($service->customers())===1,'cliente válido fica registado');
$throws(fn()=> $service->createCustomer('Duplicado Teste','cliente@example.test','910000012'),'e-mail de cliente repetido é rejeitado');
$service->createCustomer('Outro Cliente','outro@example.test','910000011');
$service->createEmployee('Operador Teste','Operador','operador@example.test');
$assert(count($service->employees())===1,'funcionário válido fica registado');
$service->createAccount(1,'Corrente');
$service->createAccount(1,'Poupança');
$service->createAccount(2,'Corrente');
$assert(count($service->accounts())===3,'contas ficam associadas a clientes existentes');
$throws(fn()=> $service->createAccount(999,'Corrente'),'conta sem cliente existente é rejeitada');
$accountIds = $db->query('SELECT id FROM accounts ORDER BY id')->fetchAll(PDO::FETCH_COLUMN);
$service->transact('Depósito',(int)$accountIds[0],null,100000,1);
$assert((int)$db->query('SELECT balance_cents FROM accounts WHERE id='.(int)$accountIds[0])->fetchColumn()===100000,'depósito aumenta o saldo');
$service->transact('Transferência',(int)$accountIds[0],(int)$accountIds[1],25000,1);
$assert((int)$db->query('SELECT balance_cents FROM accounts WHERE id='.(int)$accountIds[0])->fetchColumn()===75000,'transferência debita a origem');
$assert((int)$db->query('SELECT balance_cents FROM accounts WHERE id='.(int)$accountIds[1])->fetchColumn()===25000,'transferência credita o destino');
$throws(fn()=> $service->transact('Levantamento',(int)$accountIds[0],null,90000,1),'saldo insuficiente é rejeitado');
$assert((int)$db->query('SELECT balance_cents FROM accounts WHERE id='.(int)$accountIds[0])->fetchColumn()===75000,'saldo não muda quando o levantamento é rejeitado');
$throws(fn()=> $service->transact('Transferência',(int)$accountIds[0],(int)$accountIds[0],1000,1),'transferência para a própria conta é rejeitada');
$service->transact('Depósito',(int)$accountIds[1],null,300000,1);
$assert((int)$db->query("SELECT COUNT(*) FROM fraud_alerts WHERE status='Por rever'")->fetchColumn()===1,'operação acima do limiar gera alerta');
$service->markAlertReviewed(1);
$assert((string)$db->query('SELECT status FROM fraud_alerts WHERE id=1')->fetchColumn()==='Revisto','alerta pode ser marcado como revisto');
$service->createLoan(1,(int)$accountIds[0],50000,12);
$service->decideLoan(1,'Aprovado',1);
$assert((int)$db->query("SELECT balance_cents FROM accounts WHERE id=".(int)$accountIds[0])->fetchColumn()===125000,'empréstimo aprovado credita a conta');
$throws(fn()=> $service->decideLoan(1,'Recusado',1),'pedido decidido não pode ser decidido novamente');
$service->issueCard((int)$accountIds[0]);
$service->toggleCard(1);
$assert((string)$db->query('SELECT status FROM cards WHERE id=1')->fetchColumn()==='Bloqueado','cartão pode ser bloqueado');
$throws(fn()=> $service->createLoan(1,(int)$accountIds[2],10000,12),'conta de outro cliente não pode receber o pedido');
$assert((int)$service->summary()['customers']===2 && (int)$service->summary()['accounts']===3,'painel agrega clientes e contas');

echo "\nResultado: {$passed} passou; {$failed} falhou.\n";
exit($failed === 0 ? 0 : 1);
