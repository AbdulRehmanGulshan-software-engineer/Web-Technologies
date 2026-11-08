<?php
/**
 * Shared application helpers.
 *
 * Contains output escaping, redirects, flash messages, authentication and
 * authorization checks, CSRF protection, doctor lookups, and slot generation.
 */
function e($value): string { return htmlspecialchars((string)$value, ENT_QUOTES, 'UTF-8'); }
function redirect(string $to='index.php'): never { header('Location: '.$to); exit; }
function csrf_token(): string { if (empty($_SESSION['_csrf'])) $_SESSION['_csrf']=bin2hex(random_bytes(32)); return $_SESSION['_csrf']; }
function csrf_check(): void { if (!hash_equals($_SESSION['_csrf'] ?? '', $_POST['_csrf'] ?? '')) { http_response_code(419); exit('Invalid form token. Refresh the page and try again.'); } }
function flash(string $message, string $type='success'): void { $_SESSION['_flash']=['message'=>$message,'type'=>$type]; }
function current_user(): ?array { return $_SESSION['user'] ?? null; }
function require_login(): void { if (!current_user()) { flash('Please log in first.', 'error'); redirect('index.php?page=login'); } }
function require_role(string ...$roles): void { require_login(); if (!in_array(current_user()['role'], $roles, true)) { http_response_code(403); exit('Access denied.'); } }
function refresh_user(PDO $pdo): void {
    if (!empty($_SESSION['user']['user_id'])) {
        $q=$pdo->prepare('SELECT user_id, full_name, email, role, is_active FROM users WHERE user_id=?'); $q->execute([$_SESSION['user']['user_id']]); $u=$q->fetch();
        if (!$u || !(int)$u['is_active']) { unset($_SESSION['user']); flash('Your account is inactive.', 'error'); redirect('index.php?page=login'); }
        $_SESSION['user']=$u;
    }
}
function doctor_id_for_user(PDO $pdo, int $userId): ?int { $q=$pdo->prepare('SELECT doctor_id FROM doctors WHERE user_id=?'); $q->execute([$userId]); $v=$q->fetchColumn(); return $v===false ? null : (int)$v; }
function generate_slots(PDO $pdo, int $doctorId): void {
    // Generate 30-minute slots for today through the next 6 days in Asia/Karachi.
    $today=new DateTimeImmutable('today', new DateTimeZone('Asia/Karachi'));
    $schedule=$pdo->prepare('SELECT day_of_week,start_time,end_time,is_available FROM doctor_schedules WHERE doctor_id=?'); $schedule->execute([$doctorId]);
    $days=[]; foreach ($schedule->fetchAll() as $s) $days[(int)$s['day_of_week']]=$s;
    $insert=$pdo->prepare("INSERT IGNORE INTO appointment_slots (doctor_id,start_at,end_at,status) VALUES (?,?,?,'available')");
    for ($i=0;$i<7;$i++) {
        $date=$today->modify('+'.$i.' days'); $dow=(int)$date->format('N'); $s=$days[$dow] ?? null;
        if (!$s || !(int)$s['is_available']) continue;
        $start=new DateTimeImmutable($date->format('Y-m-d').' '.$s['start_time'], new DateTimeZone('Asia/Karachi'));
        $end=new DateTimeImmutable($date->format('Y-m-d').' '.$s['end_time'], new DateTimeZone('Asia/Karachi'));
        for ($t=$start; $t < $end; $t=$t->modify('+30 minutes')) {
            $slotEnd=$t->modify('+30 minutes'); if ($slotEnd>$end || $t <= new DateTimeImmutable('now', new DateTimeZone('Asia/Karachi'))) continue;
            $insert->execute([$doctorId,$t->format('Y-m-d H:i:s'),$slotEnd->format('Y-m-d H:i:s')]);
        }
    }
}
