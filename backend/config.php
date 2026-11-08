<?php
declare(strict_types=1);
/**
 * Application bootstrap and database configuration.
 *
 * Defines environment-specific MySQL credentials, application settings,
 * timezone/session setup, and the shared PDO connection used by the app.
 */
// Update these credentials for your local MySQL setup.
define('DB_HOST', 'localhost');
define('DB_NAME', 'doctor_appointment_system');
define('DB_USER', 'das_app');
define('DB_PASS', 'ChangeThisPassword123!');
define('APP_NAME', 'Doctor Appointment System');
date_default_timezone_set('Asia/Karachi');
if (session_status() !== PHP_SESSION_ACTIVE) { session_start(); }
try {
    $pdo = new PDO('mysql:host='.DB_HOST.';dbname='.DB_NAME.';charset=utf8mb4', DB_USER, DB_PASS, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    exit('Database connection failed. Check backend/config.php and follow README.md setup instructions.');
}
