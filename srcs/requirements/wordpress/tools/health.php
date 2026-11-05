<?php
header('Content-Type: application/json');
try {
    $secret = file_get_contents(getenv('DB_PASSWORD_FILE'));
    if ($secret === false) {
        throw new RuntimeException('Cannot read secret');
    }
    $db = new PDO(
        'mysql:host=' . getenv('DB_HOST') . ';dbname=' . getenv('DB_NAME') . ';charset=utf8mb4',
        getenv('DB_USER'),
        rtrim($secret, "\r\n"),
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_TIMEOUT => 2]
    );

    // We apply this endpoint to test the health of wordpress page
    $value = (int) $db->query('SELECT 1')->fetchColumn();

    echo json_encode(['status' => 'ok', 'database' => $value]) . "\n";
} catch (Throwable $error) {
    http_response_code(503);
    echo json_encode(['status' => 'unavailable']) . "\n";
}
