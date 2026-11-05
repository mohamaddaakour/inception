// Configures WordPress like its database connection, security settings, Redis caching, and WordPress initialization.

<?php
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
define('DISALLOW_FILE_EDIT', true);

// Redis Object Cache configuration.
if (getenv('REDIS_HOST')) {
    define('WP_REDIS_HOST', getenv('REDIS_HOST'));
    define('WP_REDIS_PORT', (int) (getenv('REDIS_PORT') ?: 6379));
    define('WP_REDIS_TIMEOUT', 1);
    define('WP_REDIS_READ_TIMEOUT', 1);
    define('WP_REDIS_DATABASE', 0);
    if (getenv('REDIS_PASSWORD_FILE') && file_exists(getenv('REDIS_PASSWORD_FILE'))) {
        define('WP_REDIS_PASSWORD', rtrim(file_get_contents(getenv('REDIS_PASSWORD_FILE')), "\r\n"));
    }
    // Instruct WordPress core to load the wp-content/object-cache.php drop-in.
    define('WP_CACHE', true);
}

if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}
require_once ABSPATH . 'wp-settings.php';