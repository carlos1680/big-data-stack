CREATE DATABASE IF NOT EXISTS superset_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON superset_db.* TO 'bigdata_user'@'%' IDENTIFIED BY 'bigdata_pass';
FLUSH PRIVILEGES;
