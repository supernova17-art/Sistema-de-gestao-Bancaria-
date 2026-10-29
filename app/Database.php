<?php
declare(strict_types=1);

final class Database
{
    public static function connect(): PDO
    {
        $directory = dirname(__DIR__) . DIRECTORY_SEPARATOR . 'storage';
        if (!is_dir($directory) && !mkdir($directory, 0770, true) && !is_dir($directory)) {
            throw new RuntimeException('Não foi possível criar a pasta de dados.');
        }

        $pdo = new PDO('sqlite:' . $directory . DIRECTORY_SEPARATOR . 'banco.sqlite');
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
        $pdo->exec('PRAGMA foreign_keys = ON');
        $pdo->exec('PRAGMA journal_mode = WAL');
        self::initialize($pdo);
        return $pdo;
    }

    private static function initialize(PDO $pdo): void
    {
        $pdo->exec((string) file_get_contents(dirname(__DIR__) . '/database/schema.sql'));
        $count = (int) $pdo->query('SELECT COUNT(*) FROM customers')->fetchColumn();
        if ($count > 0) {
            return;
        }

        $pdo->beginTransaction();
        try {
            $pdo->exec("INSERT INTO customers (full_name,email,phone) VALUES
                ('Ana Silva','ana.silva@example.test','910000001'),
                ('João Costa','joao.costa@example.test','910000002')");
            $pdo->exec("INSERT INTO employees (full_name,role,email) VALUES
                ('Rita Gomes','Gestor','rita.gomes@example.test'),
                ('Paulo Reis','Operador','paulo.reis@example.test')");
            $pdo->exec("INSERT INTO accounts (customer_id,account_number,account_type,balance_cents) VALUES
                (1,'PT500001000000000001','Corrente',250000),
                (2,'PT500001000000000002','Poupança',125000)");
            $pdo->commit();
        } catch (Throwable $error) {
            $pdo->rollBack();
            throw $error;
        }
    }
}
