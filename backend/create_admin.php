<?php
/**
 * One-time CLI utility for creating the first administrator account.
 *
 * This file is intentionally restricted to command-line execution and stores
 * only a password hash through the shared PDO connection.
 */
require __DIR__.'/config.php';
if (PHP_SAPI !== 'cli') { http_response_code(403); exit("Run this script from the terminal only.\n"); }
if ($argc < 4) { echo "Usage: php backend/create_admin.php \"Full Name\" email@example.com 'StrongPassword'\n"; exit(1); }
$name=trim($argv[1]); $email=strtolower(trim($argv[2])); $password=$argv[3];
if ($name==='' || !filter_var($email,FILTER_VALIDATE_EMAIL) || strlen($password)<12) { fwrite(STDERR,"Name, valid email, and password of at least 12 characters are required.\n"); exit(1); }
try { $q=$pdo->prepare("INSERT INTO users(full_name,email,password_hash,role) VALUES(?,?,?,'admin')"); $q->execute([$name,$email,password_hash($password,PASSWORD_DEFAULT)]); echo "Admin account created.\n"; }
catch(PDOException $e) { fwrite(STDERR,"Could not create admin. The email may already exist.\n"); exit(1); }
