<?php
declare(strict_types=1);

final class BankService
{
    public function __construct(private PDO $db) {}

    public function customers(): array
    {
        return $this->db->query('SELECT * FROM customers ORDER BY full_name')->fetchAll();
    }

    public function accounts(): array
    {
        return $this->db->query('SELECT a.*, c.full_name AS customer_name FROM accounts a JOIN customers c ON c.id=a.customer_id ORDER BY a.id DESC')->fetchAll();
    }

    public function employees(): array
    {
        return $this->db->query('SELECT * FROM employees ORDER BY full_name')->fetchAll();
    }

    public function createCustomer(string $name, string $email, string $phone): void
    {
        $name = $this->requiredText($name, 'Nome', 3, 100);
        $email = filter_var(trim($email), FILTER_VALIDATE_EMAIL);
        if (!$email || strlen($email) > 150) throw new DomainException('Indique um endereço de e-mail válido.');
        $phone = trim($phone);
        if (!preg_match('/^[0-9 +()-]{6,20}$/', $phone)) throw new DomainException('Indique um telefone válido.');
        $this->insert('INSERT INTO customers(full_name,email,phone) VALUES(?,?,?)', [$name, $email, $phone], 'Esse e-mail já está registado.');
    }

    public function createEmployee(string $name, string $role, string $email): void
    {
        $name = $this->requiredText($name, 'Nome', 3, 100);
        if (!in_array($role, ['Operador', 'Gestor'], true)) throw new DomainException('Selecione um perfil válido.');
        $email = filter_var(trim($email), FILTER_VALIDATE_EMAIL);
        if (!$email) throw new DomainException('Indique um endereço de e-mail válido.');
        $this->insert('INSERT INTO employees(full_name,role,email) VALUES(?,?,?)', [$name, $role, $email], 'Esse e-mail já está registado.');
    }

    public function createAccount(int $customerId, string $type): void
    {
        if (!$this->exists('customers', $customerId)) throw new DomainException('O cliente selecionado não existe.');
        if (!in_array($type, ['Corrente', 'Poupança'], true)) throw new DomainException('Selecione um tipo de conta válido.');
        $number = 'PT50' . str_pad((string) random_int(1, 99999999999999), 14, '0', STR_PAD_LEFT);
        $this->db->prepare('INSERT INTO accounts(customer_id,account_number,account_type) VALUES(?,?,?)')->execute([$customerId, $number, $type]);
    }

    public function transact(string $type, int $fromId, ?int $toId, int $amount, int $employeeId): void
    {
        if (!in_array($type, ['Depósito', 'Levantamento', 'Transferência'], true)) throw new DomainException('Operação inválida.');
        if ($amount <= 0 || $amount > 100000000) throw new DomainException('O montante tem de ser positivo e não pode exceder 1 000 000 €.');
        $from = $this->account($fromId);
        if (!$from || $from['status'] !== 'Ativa') throw new DomainException('A conta de origem não existe ou está bloqueada.');
        if (!$this->exists('employees', $employeeId, ' AND active=1')) throw new DomainException('Selecione um funcionário ativo.');
        $to = null;
        if ($type === 'Transferência') {
            $to = $this->account((int) $toId);
            if (!$to || $to['status'] !== 'Ativa') throw new DomainException('A conta de destino não existe ou está bloqueada.');
            if ($fromId === (int) $toId) throw new DomainException('A origem e o destino têm de ser diferentes.');
        }
        if ($type === 'Levantamento' || $type === 'Transferência') {
            if ((int) $from['balance_cents'] < $amount) throw new DomainException('Saldo insuficiente.');
        }

        $this->db->beginTransaction();
        try {
            if ($type !== 'Depósito') $this->changeBalance($fromId, -$amount);
            if ($type === 'Depósito') $this->changeBalance($fromId, $amount);
            if ($type === 'Transferência') $this->changeBalance((int) $toId, $amount);
            $stmt = $this->db->prepare('INSERT INTO transactions(from_account_id,to_account_id,employee_id,operation_type,amount_cents,description) VALUES(?,?,?,?,?,?)');
            $stmt->execute([$fromId, $type === 'Transferência' ? $toId : null, $employeeId, $type, $amount, $type . ' registado']);
            $transactionId = (int) $this->db->lastInsertId();
            $reason = $this->alertReason($fromId, $amount, $transactionId);
            if ($reason !== null) $this->db->prepare('INSERT INTO fraud_alerts(transaction_id,reason) VALUES(?,?)')->execute([$transactionId, $reason]);
            $this->db->commit();
        } catch (Throwable $error) {
            if ($this->db->inTransaction()) $this->db->rollBack();
            throw $error;
        }
    }

    public function issueCard(int $accountId): void
    {
        $account = $this->account($accountId);
        if (!$account || $account['status'] !== 'Ativa') throw new DomainException('Selecione uma conta ativa.');
        $number = '**** **** **** ' . str_pad((string) random_int(0, 9999), 4, '0', STR_PAD_LEFT);
        $this->db->prepare('INSERT INTO cards(account_id,card_number) VALUES(?,?)')->execute([$accountId, $number]);
    }

    public function toggleCard(int $cardId): void
    {
        $stmt = $this->db->prepare("UPDATE cards SET status=CASE status WHEN 'Ativo' THEN 'Bloqueado' ELSE 'Ativo' END WHERE id=?");
        $stmt->execute([$cardId]);
        if ($stmt->rowCount() !== 1) throw new DomainException('O cartão selecionado não existe.');
    }

    public function createLoan(int $customerId, int $accountId, int $amount, int $term): void
    {
        $account = $this->account($accountId);
        if (!$account || (int) $account['customer_id'] !== $customerId || $account['status'] !== 'Ativa') throw new DomainException('A conta ativa tem de pertencer ao cliente selecionado.');
        if ($amount <= 0 || $amount > 50000000) throw new DomainException('O empréstimo deve ser superior a zero e não exceder 500 000 €.');
        if ($term < 1 || $term > 360) throw new DomainException('O prazo deve estar entre 1 e 360 meses.');
        $this->db->prepare('INSERT INTO loans(customer_id,account_id,amount_cents,term_months) VALUES(?,?,?,?)')->execute([$customerId, $accountId, $amount, $term]);
    }

    public function decideLoan(int $loanId, string $decision, int $employeeId): void
    {
        if (!in_array($decision, ['Aprovado', 'Recusado'], true)) throw new DomainException('Decisão inválida.');
        if (!$this->exists('employees', $employeeId, ' AND active=1')) throw new DomainException('Selecione um funcionário ativo.');
        $loan = $this->one('SELECT * FROM loans WHERE id=?', [$loanId]);
        if (!$loan || $loan['status'] !== 'Pendente') throw new DomainException('O pedido não existe ou já foi decidido.');
        $this->db->beginTransaction();
        try {
            $stmt = $this->db->prepare("UPDATE loans SET status=?, employee_id=? WHERE id=? AND status='Pendente'");
            $stmt->execute([$decision, $employeeId, $loanId]);
            if ($stmt->rowCount() !== 1) throw new DomainException('O pedido já foi decidido.');
            if ($decision === 'Aprovado') {
                $account = $this->account((int) $loan['account_id']);
                if (!$account || $account['status'] !== 'Ativa') throw new DomainException('A conta associada não está ativa.');
                $this->changeBalance((int) $loan['account_id'], (int) $loan['amount_cents']);
                $this->db->prepare("INSERT INTO transactions(to_account_id,employee_id,operation_type,amount_cents,description) VALUES(?,?,'Crédito de empréstimo',?,?)")
                    ->execute([$loan['account_id'], $employeeId, $loan['amount_cents'], 'Empréstimo #' . $loanId]);
            }
            $this->db->commit();
        } catch (Throwable $error) {
            if ($this->db->inTransaction()) $this->db->rollBack();
            throw $error;
        }
    }

    public function markAlertReviewed(int $alertId): void
    {
        $stmt = $this->db->prepare("UPDATE fraud_alerts SET status='Revisto' WHERE id=? AND status='Por rever'");
        $stmt->execute([$alertId]);
        if ($stmt->rowCount() !== 1) throw new DomainException('O alerta não existe ou já foi revisto.');
    }

    public function summary(): array
    {
        return [
            'customers' => (int) $this->db->query('SELECT COUNT(*) FROM customers')->fetchColumn(),
            'accounts' => (int) $this->db->query("SELECT COUNT(*) FROM accounts WHERE status='Ativa'")->fetchColumn(),
            'balance' => (int) $this->db->query('SELECT COALESCE(SUM(balance_cents),0) FROM accounts')->fetchColumn(),
            'pending_loans' => (int) $this->db->query("SELECT COUNT(*) FROM loans WHERE status='Pendente'")->fetchColumn(),
            'open_alerts' => (int) $this->db->query("SELECT COUNT(*) FROM fraud_alerts WHERE status='Por rever'")->fetchColumn(),
        ];
    }

    public function transactions(): array
    {
        return $this->db->query('SELECT t.*, a.account_number AS source_number, b.account_number AS target_number, e.full_name AS employee_name FROM transactions t LEFT JOIN accounts a ON a.id=t.from_account_id LEFT JOIN accounts b ON b.id=t.to_account_id LEFT JOIN employees e ON e.id=t.employee_id ORDER BY t.id DESC LIMIT 50')->fetchAll();
    }

    public function cards(): array
    {
        return $this->db->query('SELECT c.*, a.account_number, u.full_name AS customer_name FROM cards c JOIN accounts a ON a.id=c.account_id JOIN customers u ON u.id=a.customer_id ORDER BY c.id DESC')->fetchAll();
    }

    public function loans(): array
    {
        return $this->db->query('SELECT l.*, c.full_name AS customer_name, a.account_number, e.full_name AS employee_name FROM loans l JOIN customers c ON c.id=l.customer_id JOIN accounts a ON a.id=l.account_id LEFT JOIN employees e ON e.id=l.employee_id ORDER BY l.id DESC')->fetchAll();
    }

    public function alerts(): array
    {
        return $this->db->query("SELECT f.*, t.amount_cents,t.operation_type,t.created_at AS transaction_date,a.account_number FROM fraud_alerts f JOIN transactions t ON t.id=f.transaction_id LEFT JOIN accounts a ON a.id=t.from_account_id ORDER BY f.id DESC")->fetchAll();
    }

    public function dashboardTransactions(): array { return array_slice($this->transactions(), 0, 6); }

    private function alertReason(int $accountId, int $amount, int $transactionId): ?string
    {
        if ($amount >= 300000) return 'Operação igual ou superior a 3 000 EUR; requer revisão do operador.';
        $stmt = $this->db->prepare("SELECT COALESCE(SUM(amount_cents),0) FROM transactions WHERE from_account_id=? AND id<>? AND date(created_at)=date('now')");
        $stmt->execute([$accountId, $transactionId]);
        if ((int) $stmt->fetchColumn() + $amount >= 500000) return 'Atividade diária igual ou superior a 5 000 EUR; requer revisão do operador.';
        return null;
    }

    private function account(int $id): ?array { return $this->one('SELECT * FROM accounts WHERE id=?', [$id]); }
    private function one(string $sql, array $values): ?array { $stmt=$this->db->prepare($sql); $stmt->execute($values); $row=$stmt->fetch(); return $row ?: null; }
    private function exists(string $table, int $id, string $extra = ''): bool { if (!in_array($table, ['customers','employees'], true)) return false; return $this->one("SELECT id FROM {$table} WHERE id=?{$extra}", [$id]) !== null; }
    private function changeBalance(int $accountId, int $delta): void { $stmt=$this->db->prepare('UPDATE accounts SET balance_cents=balance_cents+? WHERE id=? AND status=\'Ativa\' AND balance_cents+?>=0'); $stmt->execute([$delta,$accountId,$delta]); if ($stmt->rowCount() !== 1) throw new DomainException('A conta deixou de estar ativa ou não tem saldo suficiente.'); }
    private function insert(string $sql, array $values, string $duplicateMessage): void { try { $this->db->prepare($sql)->execute($values); } catch (PDOException $error) { if (str_contains($error->getMessage(), 'UNIQUE')) throw new DomainException($duplicateMessage); throw $error; } }
    private function requiredText(string $value, string $label, int $min, int $max): string { $value=trim($value); $length=preg_match_all('/./us',$value,$matches); if ($length === false || $length < $min || $length > $max) throw new DomainException($label . " deve ter entre {$min} e {$max} caracteres."); return $value; }
}
