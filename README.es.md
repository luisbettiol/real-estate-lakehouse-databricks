<p align="right">
  <a href="README.md">English Version</a>
</p>

# Plataforma Lakehouse Inmobiliaria (Mercado Argentina)

Implementación completa de un Lakehouse para Ingeniería de Datos construido sobre **Databricks**, **Delta Lake** y **Apache Spark**. El pipeline ingesta, limpia, modela y orquesta más de 440.000 propiedades listadas en el Área Metropolitana de Buenos Aires (CABA y GBA), entregando un modelo dimensional analítico (Star Schema / Modelo en Estrella) y un dashboard ejecutivo.

---

## Arquitectura General

La plataforma implementa una **Arquitectura Medallion (Bronze $\rightarrow$ Silver $\rightarrow$ Gold)** con gobernanza de datos a través de Unity Catalog y una capa semántica para analítica:

    [ Zona de Aterrizaje / Volumes ]
      │
      ▼
    [ BRONZE ] Tabla Delta Raw (ingesta batch, schema enforcement, append/overwrite)
        │
        ▼
    [ SILVER ] Limpieza y Enriquecimiento (unificación a USD, filtros P05/P95, parsing con regex)
        │
        ▼
    [ GOLD ] Modelo Dimensional / Star Schema (Kimball: Fact + 4 Dimensiones con Surrogate Keys)
        │
        ▼
    [ SEMÁNTICA ]  Vistas Analíticas (Data Marts desnormalizados para BI)
        │
        ▼
    [ PRESENTACIÓN ] Databricks Lakehouse Dashboards y Reportes de Negocio

---

## Fases del Pipeline y Aspectos Técnicos Destacados

### 1. Ingesta (Capa Bronze)
* Ingesta de archivos CSV en lotes hacia una tabla Delta Lake administrada mediante Unity Catalog.
* Aplicación estricta de esquemas (*schema enforcement*) para prevenir desajustes de tipos y preservar el linaje del dato crudo.
* Idempotencia total mediante patrones `INSERT OVERWRITE`.

### 2. Limpieza de Datos, EDA e Ingeniería de Atributos (Capa Silver)
* **Tratamiento Estadístico de Outliers:** Evaluación de la distribución de precios y recorte de colas anómalas usando los percentiles 5 y 95 ($P_{05} / P_{95}$) por zona y tipología.
* **Normalización de Moneda:** Estandarización de precios heterogéneos (ARS y USD) a dólares estadounidenses aplicando la tasa representativa del mercado (FX: 1520 ARS/USD).
* **Mapeo Territorial Robusto:** Simplificación de reglas complejas por un parsing tokenizado con `LIKE` y expresiones regulares en más de 30 partidos y municipios de CABA y GBA (Norte, Oeste, Sur).
* **Tipado Seguro y Deduplicación:** Homogeneización de campos categóricos, tipado seguro mediante `TRY_CAST` y eliminación de duplicados cruzados usando hashes compuestos.

### 3. Modelado Dimensional (Capa Gold - Esquema en Estrella de Kimball)
Diseño de un Star Schema analítico optimizado para agregaciones rápidas y filtros dinámicos:

* **`fact_propiedades`:** Tabla de hechos granular que almacena métricas clave aditivas (`precio_usd`, `expensas_usd`, `precio_por_m2`, `m2_totales`, `ambientes`), indexada con una clave subrogada hash MD5 (`row_hash`). Optimizada mediante agrupamiento físico (`CLUSTER BY (fecha_id, zona_id)`).
* **`dim_zona`:** Jerarquía geográfica (`partido`, `region`, `ciudad`, `provincia`, `pais`).
* **`dim_tiempo`:** Dimensión calendario (`fecha_id` en formato `YYYYMMDD`, `anio`, `mes`, `anio_mes`, `trimestre`, marcas de fin de semana).
* **`dim_tipo_operacion`:** Contexto de la transacción (`alquiler`, `venta`).
* **`dim_caracteristicas`:** Junk dimension (*dimensión basurero* de Kimball) que agrupa atributos de baja cardinalidad (`estado`, `cochera`) para no sobrecargar la tabla de hechos con claves foráneas extras.

### 4. Capa Semántica
* Creación de vistas analíticas (`vw_propiedades_analytics`, `vw_mercado_por_zona`) para abstraer los `JOINs` complejos de la capa de visualización y facilitar el autoservicio de datos.

---

## Dashboard Ejecutivo en el Lakehouse

Construido de manera nativa en Databricks Lakehouse Dashboards, permitiendo filtrado dinámico por región, tipo de transacción y características del inmueble.

![Dashboard Lakehouse Inmobiliario](docs/img/dashboard.png)
![Dashboard Lakehouse Inmobiliario](docs/img/filters.png)

### Métricas Clave del Mercado:
* **Total de Propiedades Analizadas:** 449.060 publicaciones calificadas.
* **Precio Promedio:** $135.269 USD.
* **Precio Promedio por Metro Cuadrado:** $1.509 USD/m².
* **Superficie Promedio:** 88 m².

---

## Orquestación y Automatización

El flujo completo se orquesta a través de **Databricks Workflows** como un grafo dirigido acíclico (DAG):

            [ Tarea: etl_bronze ]
                        │
                        ▼
            [ Tarea: etl_silver ]
                        │
          ┌─────────────┼─────────────┬─────────────┐
          ▼             ▼             ▼             ▼
        [dim_zona]  [dim_tiempo]  [dim_tipo]  [dim_caract]
          └─────────────┬─────────────┴─────────────┘
                        │ (Ejecución en Paralelo)
                        ▼       
            [ Tarea: etl_gold_fact ]

* **Arquitectura Desacoplada:** Los esquemas (DDLs) están separados de las cargas programadas (ETLs), evitando bloqueos y errores de metastore en producción.
* **Ejecución Paralela:** Las 4 dimensiones de Gold se procesan de forma concurrente tras finalizar Silver, minimizando los tiempos de clúster.
* **Diseño Orientado a Eventos:** Configurado para utilizar **File Arrival Triggers** en Volúmenes de Unity Catalog, reaccionando automáticamente ante la llegada de nuevos archivos.

---

## Stack Tecnológico

* **Almacenamiento y Cómputo:** Databricks, Apache Spark, Delta Lake.
* **Gobernanza de Datos:** Unity Catalog (Catalogs, Schemas, Volumes).
* **Modelado de Datos:** Kimball Dimensional Modeling (Star Schema).
* **Lenguajes:** SQL, PySpark.
* **Orquestación:** Databricks Workflows (DAGs, dependencias, triggers).
* **Visualización:** Databricks Lakehouse Dashboards.
* **Control de Versiones:** Git, GitHub.

---

## Estructura del Proyecto

```text
├── docs/
│   └── img/
│       └── dashboard.png               # Captura del dashboard ejecutivo
├── sql/
│   ├── ddl/
│   │   ├── 01_bronze.sql               # Definición de tabla Bronze
│   │   ├── 02_silver.sql               # Definición de tabla Silver
│   │   └── 03_gold.sql                 # DDL de Star Schema (Dimensiones + Fact)
│   ├── etl/
│   │   ├── 01_bronze.sql               # Lógica de ingesta Bronze
│   │   ├── 02_silver.sql               # Transformaciones y filtros Silver
│   │   └── 03_gold.sql                 # Cargas Gold y resolución de FKs
│   └── views/
│       └── 01_semantic_views.sql       # Capa de consumo semántico
├── .gitignore                          # Exclusiones de Git
├── README.es.md                        # Documentación técnica en español
└── README.md                           # Documentación técnica en inglés