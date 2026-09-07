-- ====================================================================
-- Script: DDL/01_ddl_bronze.sql
-- Description: Creación de la estructura de la tabla Bronze (vacía)
-- ====================================================================

USE CATALOG proyecto;

CREATE TABLE IF NOT EXISTS proyecto.bronze.properties_bronze
USING DELTA
COMMENT 'Tabla Bronze: Ingesta cruda de propiedades'
AS 
SELECT 
    *,
    current_timestamp() AS ingestion_timestamp,
    _metadata.file_name AS source_file
FROM read_files(
    '/Volumes/proyecto/landing/files/properties_raw.csv',
    format => 'csv',
    header => true
)
WHERE 1 = 0;