<?php
declare(strict_types=1);

function h(mixed $value): string
{
    return htmlspecialchars((string) $value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function csrf_token(): string
{
    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf'];
}

function verify_csrf(): void
{
    $sent = (string) ($_POST['csrf'] ?? '');
    if ($sent === '' || !hash_equals(csrf_token(), $sent)) {
        throw new DomainException('O formulário expirou. Atualize a página e tente novamente.');
    }
}

function flash(string $message, string $kind = 'success'): void
{
    $_SESSION['flash'] = ['message' => $message, 'kind' => $kind];
}

function take_flash(): ?array
{
    $message = $_SESSION['flash'] ?? null;
    unset($_SESSION['flash']);
    return $message;
}

function money(int $cents): string
{
    return number_format($cents / 100, 2, ',', '.') . ' €';
}

function parse_amount(string $value): int
{
    $normalized = str_replace(',', '.', trim($value));
    if (!preg_match('/^\d{1,9}(?:\.\d{1,2})?$/', $normalized)) {
        throw new DomainException('Indique um montante positivo com, no máximo, duas casas decimais.');
    }
    $cents = (int) round((float) $normalized * 100);
    if ($cents <= 0) {
        throw new DomainException('O montante tem de ser superior a zero.');
    }
    return $cents;
}
