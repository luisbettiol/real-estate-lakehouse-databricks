-- ====================================================================
-- Script: ETL/02_etl_silver.sql
-- Description: Ingesta y transformación integral Bronze -> Silver
--              con cálculo dinámico de percentiles (outliers)
-- ====================================================================

USE CATALOG proyecto;

INSERT OVERWRITE proyecto.silver.propiedades (
    partido,
    region,
    tipo_operacion,
    precio_usd,
    expensas_usd,
    ambientes,
    m2_totales,
    m2_cubiertos,
    antiguedad,
    cochera,
    estado,
    url,
    fecha_publicacion,
    precio_por_m2
)
WITH 
-- 1. Limpieza base, casteo seguro y normalización a USD
bronze_preparada AS (
    SELECT
        id,
        url,
        LOWER(TRIM(tipo_de_operacion)) AS tipo_operacion,
        LOWER(TRIM(zona)) AS zona,
        
        -- Normalización de Precios a USD
        CASE 
            WHEN (LOWER(moneda) LIKE '%pesos%' OR LOWER(moneda) LIKE '%ars%') AND TRY_CAST(precio AS DOUBLE) > 0 
                THEN ROUND(TRY_CAST(precio AS DOUBLE) / 1520.0, 2)
            WHEN TRY_CAST(precio AS DOUBLE) > 0 
                THEN ROUND(TRY_CAST(precio AS DOUBLE), 2)
            ELSE NULL 
        END AS precio_usd,

        -- Normalización de Expensas a USD
        CASE 
            WHEN (LOWER(moneda) LIKE '%pesos%' OR LOWER(moneda) LIKE '%ars%') AND TRY_CAST(expensas AS DOUBLE) > 0 
                THEN ROUND(TRY_CAST(expensas AS DOUBLE) / 1520.0, 2)
            WHEN TRY_CAST(expensas AS DOUBLE) > 0 
                THEN ROUND(TRY_CAST(expensas AS DOUBLE), 2)
            ELSE 0.00 
        END AS expensas_usd,

        -- Normalización y categorización de Ambientes
        CASE
            -- Valores numéricos del 1 al 9: se mantienen como texto individual ('1', '2', ..., '9')
            WHEN TRY_CAST(TRIM(ambientes) AS DOUBLE) >= 1 
            AND TRY_CAST(TRIM(ambientes) AS DOUBLE) < 10 
                THEN CAST(CAST(ROUND(TRY_CAST(TRIM(ambientes) AS DOUBLE)) AS INT) AS STRING)

            -- Rango de 10 a 20: agrupados en '10+'
            WHEN TRY_CAST(TRIM(ambientes) AS DOUBLE) >= 10 
            AND TRY_CAST(TRIM(ambientes) AS DOUBLE) <= 20 
                THEN '10+'

            -- Mayores a 20, negativos, cero o nulos/corruptos
            ELSE 'No Especificado'
        END AS ambientes,

        -- Metros cuadrados
        TRY_CAST(metros_cuadrados_totales AS DECIMAL(15,2)) AS m2_totales,
        TRY_CAST(metros_cuadrados_cubiertos AS DECIMAL(15,2)) AS m2_cubiertos,

        -- Antigüedad
        CASE 
            WHEN TRY_CAST(antiguedad AS INT) BETWEEN 0 AND 150 THEN TRY_CAST(antiguedad AS INT)
            ELSE 999 
        END AS antiguedad,

        -- Cochera booleana
        CASE 
            WHEN cochera = 'tiene' OR cochera = '1' OR LOWER(cochera) = 'true' THEN TRUE 
            ELSE FALSE 
        END AS cochera,

        -- Homologación de Estado
        CASE 
            WHEN LOWER(estado) IN ('excelente', 'impecable', 'premium', 'perfecto') THEN 'Excelente'
            WHEN LOWER(estado) IN ('muy bueno', 'muy_bueno', 'muy buen estado') THEN 'Muy Bueno'
            WHEN LOWER(estado) IN ('bueno', 'estandar', 'habitable') THEN 'Bueno'
            WHEN LOWER(estado) IN ('a_refaccionar', 'a refaccionar', 'a_reciclar', 'reciclado') THEN 'A Refaccionar'
            WHEN LOWER(estado) IN ('a_estrenar', 'a estrenar', 'nuevo') THEN 'A Estrenar'
            ELSE 'No Especificado'
        END AS estado,

        COALESCE(TRY_CAST(fecha AS DATE), CURRENT_DATE()) AS fecha_publicacion

    FROM proyecto.bronze.properties_bronze
    WHERE url RLIKE '^https'
      AND tipo_de_operacion IN ('alquiler', 'venta')
      AND (
          LOWER(moneda) LIKE '%dolares%' OR LOWER(moneda) LIKE '%us%' OR 
          LOWER(moneda) LIKE '%pesos%' OR LOWER(moneda) LIKE '%ars%'
      )
),

-- 2. Cálculo DINÁMICO de percentiles de precio por tipo de operación
limites_precio AS (
    SELECT 
        tipo_operacion,
        PERCENTILE(precio_usd, 0.05) AS p05_precio,
        PERCENTILE(precio_usd, 0.95) AS p95_precio
    FROM bronze_preparada
    WHERE precio_usd IS NOT NULL
    GROUP BY tipo_operacion
),

-- 3. Cálculo DINÁMICO de percentiles de superficie (m2)
limites_m2 AS (
    SELECT 
        PERCENTILE(m2_totales, 0.001) AS p001_totales,
        PERCENTILE(m2_totales, 0.999) AS p999_totales,
        PERCENTILE(m2_cubiertos, 0.001) AS p001_cubiertos,
        PERCENTILE(m2_cubiertos, 0.999) AS p999_cubiertos
    FROM bronze_preparada
    WHERE m2_totales > 0
),

-- 4. Filtro de outliers usando los percentiles calculados arriba
outliers_filtrados AS (
    SELECT b.*
    FROM bronze_preparada b
    INNER JOIN limites_precio lp 
        ON b.tipo_operacion = lp.tipo_operacion
    CROSS JOIN limites_m2 lm
    WHERE b.precio_usd BETWEEN lp.p05_precio AND lp.p95_precio
      AND (b.m2_totales BETWEEN lm.p001_totales AND lm.p999_totales)
      AND (b.m2_cubiertos IS NULL OR b.m2_cubiertos BETWEEN lm.p001_cubiertos AND lm.p999_cubiertos)
),

-- 5. Mapeo geográfico de Partidos y Regiones
geo_mapeada AS (
    SELECT 
        *,
        -- Mapeo de Partido simplificado y robusto
        CASE
            -- CABA
            WHEN zona LIKE '%capital%' OR zona LIKE '%caba%' THEN 'capital federal'
            
            -- GBA Norte
            WHEN zona LIKE '%vicente%lopez%' THEN 'vicente lopez'
            WHEN zona LIKE '%san%isidro%' THEN 'san isidro'
            WHEN zona LIKE '%san%fernando%' THEN 'san fernando'
            WHEN zona LIKE '%tigre%' THEN 'tigre'
            WHEN zona LIKE '%san%martin%' THEN 'general san martin'
            WHEN zona LIKE '%san%miguel%' THEN 'san miguel'
            WHEN zona LIKE '%malvinas%' THEN 'malvinas argentinas'
            WHEN zona LIKE '%escobar%' THEN 'escobar'
            WHEN zona LIKE '%pilar%' THEN 'pilar'
            WHEN zona LIKE '%jose%c%paz%' THEN 'jose c paz'

            -- GBA Oeste
            WHEN zona LIKE '%moron%' OR zona LIKE '%castelar%' THEN 'moron'
            WHEN zona LIKE '%tres%febrero%' OR zona LIKE '%caseros%' THEN 'tres de febrero'
            WHEN zona LIKE '%hurlingham%' THEN 'hurlingham'
            WHEN zona LIKE '%ituzaingo%' THEN 'ituzaingo'
            WHEN zona LIKE '%matanza%' THEN 'la matanza'
            WHEN zona LIKE '%merlo%' THEN 'merlo'
            WHEN zona LIKE '%moreno%' THEN 'moreno'
            WHEN zona LIKE '%general%rodriguez%' THEN 'general rodriguez'
            WHEN zona LIKE '%marcos%paz%' THEN 'marcos paz'
            WHEN zona LIKE '%lujan%' THEN 'lujan'

            -- GBA Sur
            WHEN zona LIKE '%avellaneda%' THEN 'avellaneda'
            WHEN zona LIKE '%lanus%' THEN 'lanus'
            WHEN zona LIKE '%lomas%zamora%' THEN 'lomas de zamora'
            WHEN zona LIKE '%quilmes%' THEN 'quilmes'
            WHEN zona LIKE '%almirante%brown%' THEN 'almirante brown'
            WHEN zona LIKE '%esteban%echeverria%' THEN 'esteban echeverria'
            WHEN zona LIKE '%ezeiza%' THEN 'ezeiza'
            WHEN zona LIKE '%berazategui%' THEN 'berazategui'
            WHEN zona LIKE '%florencio%varela%' THEN 'florencio varela'
            WHEN zona LIKE '%la%plata%' THEN 'la plata'
            WHEN zona LIKE '%berisso%' THEN 'berisso'
            WHEN zona LIKE '%ensenada%' THEN 'ensenada'
            WHEN zona LIKE '%san%vicente%' THEN 'san vicente'
            WHEN zona LIKE '%presidente%peron%' THEN 'presidente peron'
            WHEN zona LIKE '%canuelas%' THEN 'canuelas'

            ELSE 'no especifica'
        END AS partido,

        -- Mapeo de Región simplificado
        CASE
            WHEN zona LIKE '%capital%' OR zona LIKE '%caba%' THEN 'capital federal'
            WHEN zona LIKE '%norte%' THEN 'gba zona norte'
            WHEN zona LIKE '%oeste%' THEN 'gba zona oeste'
            WHEN zona LIKE '%sur%' THEN 'gba zona sur'
            ELSE 'no especifica'
        END AS region
    FROM outliers_filtrados
),

-- 6. Deduplicación por (precio_usd, url) quedándonos con la más reciente
deduplicadas AS (
    SELECT 
        *,
        ROUND(precio_usd / NULLIF(m2_totales, 0), 2) AS precio_por_m2,
        ROW_NUMBER() OVER (
            PARTITION BY precio_usd, url 
            ORDER BY fecha_publicacion DESC
        ) AS rn
    FROM geo_mapeada
)

-- 7. Inserción en la tabla Silver
SELECT
    partido,
    region,
    tipo_operacion,
    precio_usd,
    expensas_usd,
    ambientes,
    m2_totales,
    m2_cubiertos,
    antiguedad,
    cochera,
    estado,
    url,
    fecha_publicacion,
    precio_por_m2
FROM deduplicadas
WHERE rn = 1;