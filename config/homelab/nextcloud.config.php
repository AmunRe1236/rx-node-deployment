<?php
$CONFIG = array(
  'trusted_domains' => array(
    'cloud.gentleman.local',
    '192.168.68.111',
    'localhost'
  ),
  'overwrite.cli.url' => 'https://cloud.gentleman.local',
  'htaccess.RewriteBase' => '/',
  'memcache.local' => '\\OC\\Memcache\\APCu',
  'apps_paths' => array(
    array(
      'path' => '/var/www/html/apps',
      'url' => '/apps',
      'writable' => false,
    ),
    array(
      'path' => '/var/www/html/custom_apps',
      'url' => '/custom_apps',
      'writable' => true,
    ),
  ),
  'default_phone_region' => 'DE',
  'maintenance' => false,
);
