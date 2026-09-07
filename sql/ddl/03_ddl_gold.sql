-- ====================================================================
-- Script: DDL/03_ddl_gold.sql
-- Description: Estructura de la tabla Gold en Delta Lake
-- ====================================================================

USE CATALOG proyecto;


-- DDL_dim_caracteristicas

DROP TABLE IF EXISTS proyecto.gold.dim_caracteristicas;

CREATE TABLE IF NOT EXISTS proyecto.gold.dim_caracteristicas (
    caracteristicas_id BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1)
        COMMENT 'Surrogate Key de la junk dimension',
    estado STRING NOT NULL
        COMMENT 'Estado homologado: Excelente, Muy Bueno, Bueno, A Refaccionar, A Estrenar, No Especificado',
    cochera BOOLEAN NOT NULL
        COMMENT 'Flag booleano de posesión de cochera',
    _created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
USING DELTA
TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported'
)
COMMENT 'Junk Dimension de características (estado + cochera) - Star Schema';


-- DDL_dim_tiempo

DROP TABLE IF EXISTS proyecto.gold.dim_tiempo;

CREATE TABLE IF NOT EXISTS proyecto.gold.dim_tiempo (
    fecha_id BIGINT COMMENT 'Surrogate Key en formato YYYYMMDD',
    fecha DATE NOT NULL COMMENT 'Fecha calendario',
    anio INT COMMENT 'Año',
    mes INT COMMENT 'Número de mes (1 a 12)',
    nombre_mes STRING COMMENT 'Nombre del mes',
    anio_mes STRING COMMENT 'Año y mes en formato YYYY-MM para agrupaciones de dashboards',
    trimestre INT COMMENT 'Trimestre (1 a 4)',
    dia_semana STRING COMMENT 'Nombre del día',
    es_fin_de_semana BOOLEAN COMMENT 'TRUE si es sábado o domingo',
    _created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
USING DELTA
TBLPROPERTIES ('delta.feature.allowColumnDefaults' = 'supported')
COMMENT 'Dimensión de Tiempo - Star Schema';


-- DDL_dim_tipo_operacion

DROP TABLE IF EXISTS proyecto.gold.dim_tipo_operacion;

CREATE TABLE IF NOT EXISTS proyecto.gold.dim_tipo_operacion (
    tipo_operacion_id BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1)
        COMMENT 'Surrogate key del tipo de operación',
    tipo_operacion STRING NOT NULL
        COMMENT 'Tipo de transacción: alquiler o venta',
    _created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
USING DELTA
TBLPROPERTIES ('delta.feature.allowColumnDefaults' = 'supported')
COMMENT 'Dimensión de Tipo de Operación - Star Schema';


--- DDL_dim_zona

DROP TABLE IF EXISTS proyecto.gold.dim_zona;

CREATE TABLE IF NOT EXISTS proyecto.gold.dim_zona (
    zona_id BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) 
        COMMENT 'Surrogate Key de la zona geográfica',
    partido STRING NOT NULL 
        COMMENT 'Partido o municipio normalizado',
    region STRING NOT NULL 
        COMMENT 'Región: capital federal, gba zona norte/oeste/sur',
    ciudad STRING 
        COMMENT 'Agrupación macro: CABA o GBA',
    provincia STRING DEFAULT 'Buenos Aires' 
        COMMENT 'Provincia correspondiente',
    pais STRING DEFAULT 'Argentina' 
        COMMENT 'País',
    _created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP() 
        COMMENT 'Timestamp de creación del registro'
)
USING DELTA
TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported'
)
COMMENT 'Dimensión de Zonas Geográficas - Modelo Estrella Gold';


-- DDL_fact_propiedades

DROP TABLE IF EXISTS proyecto.gold.fact_propiedades;

CREATE TABLE IF NOT EXISTS proyecto.gold.fact_propiedades (
    row_hash STRING NOT NULL 
        COMMENT 'Hash MD5 único por publicación (url + precio_usd)',
    
    -- Claves Foráneas (FKs) hacia las dimensiones
    zona_id BIGINT 
        COMMENT 'FK hacia dim_zona',
    tipo_operacion_id BIGINT 
        COMMENT 'FK hacia dim_tipo_operacion',
    fecha_id BIGINT 
        COMMENT 'FK hacia dim_tiempo',
    caracteristicas_id BIGINT 
        COMMENT 'FK hacia dim_caracteristicas (junk dimension)',
    
    -- Métricas Numéricas / Hechos
    precio_usd DECIMAL(15,2) 
        COMMENT 'Precio estandarizado en USD',
    expensas_usd DECIMAL(15,2) 
        COMMENT 'Expensas mensuales estandarizadas en USD',
    precio_por_m2 DECIMAL(15,2) 
        COMMENT 'Precio por metro cuadrado en USD',
    m2_totales DECIMAL(15,2) 
        COMMENT 'Superficie total en metros cuadrados',
    m2_cubiertos DECIMAL(15,2) 
        COMMENT 'Superficie cubierta en metros cuadrados',
    ambientes STRING 
        COMMENT 'Cantidad de ambientes',
    
    -- Trazabilidad
    url STRING 
        COMMENT 'URL origen de la propiedad',
    _refresh_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP() 
        COMMENT 'Timestamp de carga en capa Gold'
)
USING DELTA
CLUSTER BY (fecha_id, zona_id)
TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported'
)
COMMENT 'Tabla de Hechos de Propiedades - Star Schema Gold';