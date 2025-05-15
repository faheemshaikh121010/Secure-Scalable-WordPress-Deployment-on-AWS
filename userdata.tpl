#!/bin/bash
yum update -y
amazon-linux-extras install -y php8.0 nginx1
yum install -y amazon-efs-utils php-mysqlnd

# Mount EFS
mkdir -p /var/www/html
mount -t efs ${efs_id}:/ /var/www/html

# Install WordPress
curl -O https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz -C /var/www/html --strip-components=1

# Configure WordPress
cat > /var/www/html/wp-config.php << EOF
<?php
define('DB_NAME', '${db_name}');
define('DB_USER', '${db_user}');
define('DB_PASSWORD', '${db_password}');
define('DB_HOST', '${db_endpoint}');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');
EOF

# Set permissions
chown -R nginx:nginx /var/www/html
systemctl start nginx
systemctl enable nginx