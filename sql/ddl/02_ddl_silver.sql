-- ====================================================================
-- Script: DDL/02_ddl_silver.sql
-- Description: Estructura de la tabla Silver en Delta Lake
-- ====================================================================

USE CATALOG proyecto;

DROP TABLE IF EXISTS proyecto.silver.propiedades;

CREATE TABLE IF NOT EXISTS proyecto.silver.propiedades (
    propiedad_id BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) 
        COMMENT 'Surrogate Key auto-generada para la propiedad',

    partido STRING 
        COMMENT 'Partido o municipio estandarizado',

    region STRING 
        COMMENT 'Región geográfica: capital_federal, gba_norte, gba_oeste, gba_sur, etc.',

    tipo_operacion STRING 
        COMMENT 'Tipo de transacción estandarizada: alquiler o venta',

    precio_usd DECIMAL(15,2) 
        COMMENT 'Precio estandarizado en USD (ARS convertidos a tasa 1520)',
    
    expensas_usd DECIMAL(15,2) 
        COMMENT 'Expensas mensuales normalizadas a USD',

    ambientes STRING COMMENT 'Cantidad o categoría de ambientes: 1 a 9, 10-20, No Especificado',
    
    m2_totales DECIMAL(15,2) 
        COMMENT 'Superficie total en metros cuadrados',
    
    m2_cubiertos DECIMAL(15,2) 
        COMMENT 'Superficie cubierta en metros cuadrados',

    antiguedad INT 
        COMMENT 'Años de antigüedad (imputado con 999 cuando no está especificado)',
    
    cochera BOOLEAN 
        COMMENT 'Flag booleano: TRUE si posee cochera, FALSE en caso contrario',
    
    estado STRING 
        COMMENT 'Estado homologado: Excelente, Muy Bueno, Bueno, A Refaccionar, A Estrenar, No Especificado',
    
    url STRING 
        COMMENT 'URL origen de la publicación (usada junto a precio para deduplicación)',

    fecha_publicacion DATE 
        COMMENT 'Fecha de publicación parseada a DATE',

    precio_por_m2 DECIMAL(15,2) 
        COMMENT 'Métrica calculada: precio_usd / m2_totales',

    -- Columnas de Auditoría / Metadata
    _source_table STRING DEFAULT 'proyecto.bronze.properties_bronze' 
        COMMENT 'Tabla origen de los datos',
    
    _processing_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP() 
        COMMENT 'Timestamp de carga en capa Silver'
)
USING DELTA
CLUSTER BY (tipo_operacion, region, partido)
TBLPROPERTIES ('delta.feature.allowColumnDefaults' = 'supported')
COMMENT 'Propiedades inmobiliarias - Capa Silver (datos limpios, deduplicados y validados)';