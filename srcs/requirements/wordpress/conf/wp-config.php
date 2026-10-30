<?php
// Read configuration at runtime; never write the database password into this file.
define('DB_NAME', getenv('DB_NAME'));
define('DB_USER', getenv('DB_USER'));
define('DB_PASSWORD', rtrim(file_get_contents(getenv('DB_PASSWORD_FILE')), "\r\n"));
define('DB_HOST', getenv('DB_HOST'));
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');
$table_prefix = 'wp_';

// Random authentication keys persist with the website, preserving login sessions.
require __DIR__ . '/.inception-salts.php';
define('WP_DEBUG', false);
define('FORCE_SSL_ADMIN', true);

if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}
require_once ABSPATH . 'wp-settings.php';