-- ====================================================================
-- Script: ETL/03_etl_gold.sql
-- Description: Ingesta y transformación integral Silver -> Gold
--             con creación de dimensiones y fact tables
-- ====================================================================

USE CATALOG proyecto;

-- ETL_dim_caracteristicas

INSERT OVERWRITE proyecto.gold.dim_caracteristicas (estado, cochera)
SELECT DISTINCT
    COALESCE(estado, 'No Especificado') AS estado,
    COALESCE(cochera, FALSE) AS cochera
FROM proyecto.silver.propiedades
ORDER BY estado, cochera;


-- ETL_dim_tiempo

INSERT OVERWRITE proyecto.gold.dim_tiempo (
    fecha_id,
    fecha,
    anio,
    mes,
    nombre_mes,
    anio_mes,
    trimestre,
    dia_semana,
    es_fin_de_semana
)
SELECT DISTINCT
    CAST(DATE_FORMAT(fecha_publicacion, 'yyyyMMdd') AS BIGINT) AS fecha_id,
    fecha_publicacion AS fecha,
    YEAR(fecha_publicacion) AS anio,
    MONTH(fecha_publicacion) AS mes,
    DATE_FORMAT(fecha_publicacion, 'MMMM') AS nombre_mes,
    DATE_FORMAT(fecha_publicacion, 'yyyy-MM') AS anio_mes,
    QUARTER(fecha_publicacion) AS trimestre,
    DATE_FORMAT(fecha_publicacion, 'EEEE') AS dia_semana,
    DAYOFWEEK(fecha_publicacion) IN (1, 7) AS es_fin_de_semana
FROM proyecto.silver.propiedades
WHERE fecha_publicacion IS NOT NULL
ORDER BY fecha;


-- ETL_dim_tipo_operacion

INSERT OVERWRITE proyecto.gold.dim_tipo_operacion (tipo_operacion)
SELECT DISTINCT
    tipo_operacion
FROM proyecto.silver.propiedades
WHERE tipo_operacion IS NOT NULL
ORDER BY tipo_operacion;


-- ETL_dim_zona

INSERT OVERWRITE proyecto.gold.dim_zona 
    (partido, region, ciudad, provincia, pais)
SELECT DISTINCT
    sp.partido,
    sp.region,
    CASE 
        WHEN sp.region = 'capital federal' THEN 'CABA'
        ELSE 'GBA'
    END AS ciudad,
    'Buenos Aires' AS provincia,
    'Argentina' AS pais
FROM proyecto.silver.propiedades sp
WHERE sp.partido IS NOT NULL
ORDER BY sp.partido;


-- ETL_fact_propiedades

INSERT OVERWRITE proyecto.gold.fact_propiedades (
    row_hash, 
    zona_id, 
    tipo_operacion_id, 
    fecha_id, 
    caracteristicas_id, 
    precio_usd, 
    expensas_usd, 
    precio_por_m2,
    m2_totales, 
    m2_cubiertos, 
    ambientes, 
    url
)
SELECT 
    MD5(CONCAT_WS('|', sp.url, CAST(sp.precio_usd AS STRING))) AS row_hash,
    dz.zona_id,
    dt.tipo_operacion_id,
    dtf.fecha_id,
    dc.caracteristicas_id,
    sp.precio_usd, 
    sp.expensas_usd, 
    sp.precio_por_m2,
    sp.m2_totales, 
    sp.m2_cubiertos,
    sp.ambientes, 
    sp.url
FROM proyecto.silver.propiedades sp
LEFT JOIN proyecto.gold.dim_zona AS dz 
    ON sp.partido = dz.partido 
    AND sp.region = dz.region
LEFT JOIN proyecto.gold.dim_tipo_operacion AS dt 
    ON sp.tipo_operacion = dt.tipo_operacion
LEFT JOIN proyecto.gold.dim_tiempo AS dtf 
    ON sp.fecha_publicacion = dtf.fecha
LEFT JOIN proyecto.gold.dim_caracteristicas AS dc 
    ON COALESCE(sp.estado, 'No Especificado') = dc.estado 
    AND COALESCE(sp.cochera, FALSE) = dc.cochera;