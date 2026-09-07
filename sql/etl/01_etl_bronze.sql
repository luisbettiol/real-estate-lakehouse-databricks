-- ====================================================================
-- Script: ETL/01_etl_bronze.sql
-- Description: Ingesta por lotes (Batch) idempotente desde Landing a Bronze
-- ====================================================================

USE CATALOG proyecto;

-- Carga idempotente: reemplaza el contenido con el último snapshot crudo
INSERT OVERWRITE proyecto.bronze.properties_bronze
SELECT 
    *,
    current_timestamp() AS ingestion_timestamp,
    _metadata.file_name AS source_file
FROM read_files(
    '/Volumes/proyecto/landing/files/properties_raw.csv',
    format => 'csv',
    header => true
);