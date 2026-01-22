-- Crear base (si no existe)
CREATE DATABASE IF NOT EXISTS bigdata_db;

USE bigdata_db;

-- Crear tabla de ejemplo
CREATE TABLE IF NOT EXISTS sensores (
  id INT AUTO_INCREMENT PRIMARY KEY,
  dispositivo VARCHAR(50),
  temperatura DECIMAL(5,2),
  humedad DECIMAL(5,2),
  fecha DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Insertar datos de ejemplo
INSERT INTO sensores (dispositivo, temperatura, humedad)
VALUES
  ('sensor_norte', 22.5, 60.1),
  ('sensor_sur',   25.3, 55.4),
  ('sensor_este',  21.8, 58.9),
  ('sensor_oeste', 24.1, 52.2);
