-- =====================================================
-- SCRIPT DE INICIALIZACIÓN DE BASES DE DATOS BIGDATASTACK
-- =====================================================
-- Autor: Carlos Piriz
-- Fecha: $(date)
-- Descripción: Inicializa todas las bases del entorno BIGDATASTACK:
--              - bigdata_db
--              - superset_db
--              - airflow_db
--              Crea usuario, permisos y datos de ejemplo.
-- =====================================================

-- ==========================
-- USUARIO GLOBAL
-- ==========================
CREATE USER IF NOT EXISTS 'bigdata_user'@'%' IDENTIFIED BY 'bigdata_pass';
GRANT ALL PRIVILEGES ON *.* TO 'bigdata_user'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;

-- ==========================
-- BASE DE DATOS: bigdata_db
-- ==========================
CREATE DATABASE IF NOT EXISTS bigdata_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE bigdata_db;

CREATE TABLE IF NOT EXISTS sensores (
  id INT AUTO_INCREMENT PRIMARY KEY,
  dispositivo VARCHAR(50),
  temperatura DECIMAL(5,2),
  humedad DECIMAL(5,2),
  fecha DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO sensores (dispositivo, temperatura, humedad)
VALUES
  ('sensor_norte', 22.5, 60.1),
  ('sensor_sur',   25.3, 55.4),
  ('sensor_este',  21.8, 58.9),
  ('sensor_oeste', 24.1, 52.2);

-- ==========================
-- BASE DE DATOS: superset_db
-- ==========================
CREATE DATABASE IF NOT EXISTS superset_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

GRANT ALL PRIVILEGES ON superset_db.* TO 'bigdata_user'@'%';
FLUSH PRIVILEGES;

-- ==========================
-- BASE DE DATOS: airflow_db
-- ==========================
CREATE DATABASE IF NOT EXISTS airflow_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

GRANT ALL PRIVILEGES ON airflow_db.* TO 'bigdata_user'@'%';
FLUSH PRIVILEGES;

-- =====================================================
-- VERIFICACIÓN FINAL
-- =====================================================
SELECT '✅ Bases de datos creadas correctamente:' AS status;
SHOW DATABASES;
