USE CATALOG proyecto;

-- ====================================================================
-- Script: VIEWS/01_vw_propiedades_analytics.sql
-- Description: Vista semántica unificada para consumo analítico / BI
-- ====================================================================

CREATE OR REPLACE VIEW proyecto.semantic.v_propiedades_analytics
COMMENT 'Capa Semántica: Vista desnormalizada lista para Dashboards'
AS
SELECT 
    f.row_hash,
    -- Dimensión Tiempo
    dt.fecha,
    dt.anio,
    dt.mes,
    dt.nombre_mes,
    dt.anio_mes,
    dt.trimestre,
    
    -- Dimensión Zona
    dz.partido,
    dz.region,
    dz.ciudad,
    dz.provincia,
    
    -- Dimensión Operación
    dto.tipo_operacion,
    
    -- Dimensión Características
    dc.estado,
    dc.cochera,
    
    -- Métricas
    f.precio_usd,
    f.expensas_usd,
    f.precio_por_m2,
    f.m2_totales,
    f.m2_cubiertos,
    f.ambientes,
    f.url
FROM proyecto.gold.fact_propiedades f
INNER JOIN proyecto.gold.dim_zona dz 
    ON f.zona_id = dz.zona_id
INNER JOIN proyecto.gold.dim_tipo_operacion dto 
    ON f.tipo_operacion_id = dto.tipo_operacion_id
INNER JOIN proyecto.gold.dim_tiempo dt 
    ON f.fecha_id = dt.fecha_id
INNER JOIN proyecto.gold.dim_caracteristicas dc 
    ON f.caracteristicas_id = dc.caracteristicas_id;



-- ====================================================================
-- Script: VIEWS/02_vw_mercado_por_zona.sql
-- Description: Métricas agregadas de oferta y valor promedio por zona
-- ====================================================================

CREATE OR REPLACE VIEW proyecto.semantic.v_mercado_por_zona
COMMENT 'Capa Semántica: KPIs consolidados por Partido y Región'
AS
SELECT 
    region,
    partido,
    tipo_operacion,
    COUNT(*) AS total_publicaciones,
    ROUND(AVG(precio_usd), 2) AS precio_promedio_usd,
    ROUND(MEDIAN(precio_usd), 2) AS precio_mediana_usd,
    ROUND(AVG(precio_por_m2), 2) AS precio_m2_promedio_usd,
    ROUND(AVG(m2_totales), 2) AS m2_promedio
FROM proyecto.semantic.vw_propiedades_analytics
GROUP BY region, partido, tipo_operacion;


-- ====================================================================
-- Script: VIEWS/03_vw_ratio_rentabilidad_zona.sql
-- Description: Análisis de rentabilidad estimada por zona (Gross Yield)
-- ====================================================================

CREATE OR REPLACE VIEW proyecto.semantic.v_ratio_rentabilidad_zona
COMMENT 'Capa Semántica: Comparativa Alquiler vs Venta y Yield por Zona'
AS
WITH metricas_operacion AS (
    SELECT 
        region,
        partido,
        tipo_operacion,
        ROUND(MEDIAN(precio_usd), 2) AS precio_mediana
    FROM proyecto.semantic.vw_propiedades_analytics
    GROUP BY region, partido, tipo_operacion
)
SELECT 
    v.region,
    v.partido,
    v.precio_mediana AS precio_venta_mediana,
    a.precio_mediana AS alquiler_mensual_mediana,
    -- Gross Yield anualizado aproximado
    ROUND(((a.precio_mediana * 12) / NULLIF(v.precio_mediana, 0)) * 100, 2) AS yield_bruto_anual_pct
FROM metricas_operacion v
INNER JOIN metricas_operacion a 
    ON v.partido = a.partido 
    AND v.region = a.region
WHERE v.tipo_operacion = 'venta' 
  AND a.tipo_operacion = 'alquiler';