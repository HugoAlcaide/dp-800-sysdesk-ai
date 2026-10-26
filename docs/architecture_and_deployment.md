# Guía Maestra de Ejecución Paso a Paso — Proyecto SysDesk AI (Microsoft DP-800)

Este documento describe el flujo de despliegue, verificación y auditoría de **SysDesk AI**, referenciando cada script `.sql` y documento técnico del repositorio en el orden exacto de ejecución sobre **SQL Server 2025 (Compatibilidad 170)**.

---

## Estructura General del Repositorio

```text
dp-800-sysdesk-ai/
├── database/
│   ├── 01_create_database.sql
│   ├── 02_create_tables.sql
│   ├── 03_insert_data.sql
│   ├── 04_views_and_functions.sql
│   ├── 05_procedures_and_tsql.sql
│   ├── 06_security.sql
│   └── 07_indexes_and_optimization.sql
├── ai/
│   ├── 08_vector_embeddings_and_diskann.sql
│   ├── 09_intelligent_hybrid_search.sql
│   └── 10_rag_copilot_solution.sql
├── tests/
│   └── test_bloque_c_y_d.sql
└── docs/
    ├── bloque_b_asistencia_ia.md
    └── guia_paso_a_paso_ejecucion.md
```

---

## Fase 1: Diseño y Desarrollo de la Base de Datos (Bloque A)

### Paso 1.1: Creación de la Base de Datos y Nivel de Compatibilidad 170
* **Archivo a ejecutar:** [`database/01_create_database.sql`](../database/01_create_database.sql)
* **Qué hace:** Crea la base de datos `[SysDeskAI]`, establece explícitamente `COMPATIBILITY_LEVEL = 170` (SQL Server 2025) y activa `PREVIEW_FEATURES = ON` para habilitar la indexación vectorial DiskANN.
* **Evidencia esperada:** Consulta que devuelve `DatabaseName = SysDeskAI` y `CompatibilityLevel = 170`.

### Paso 1.2: Despliegue del Modelo Relacional en 3FN y Tipos Nativos SQL 2025
* **Archivo a ejecutar:** [`database/02_create_tables.sql`](../database/02_create_tables.sql)
* **Qué hace:** Crea las 5 tablas normalizadas del sistema (`dbo.usuarios`, `dbo.sistemas`, `dbo.kb_articulos`, `dbo.tickets` y `dbo.auditoria_rag`) incorporando el tipo nativo `VECTOR(384)` para embeddings y el tipo nativo `JSON` para telemetría de diagnóstico, junto con restricciones `CHECK` de dominio e integridad temporal.

### Paso 1.3: Carga de Datos Operativos de Soporte TI
* **Archivo a ejecutar:** [`database/03_insert_data.sql`](../database/03_insert_data.sql)
* **Qué hace:** Inserta los perfiles de técnicos y usuarios corporativos, los 6 sistemas críticos de la organización, los artículos de la Base de Conocimiento (KB) y los tickets iniciales con telemetría JSON real.

### Paso 1.4: Creación de Funciones Escalares, Vistas Analíticas y Triggers
* **Archivo a ejecutar:** [`database/04_views_and_functions.sql`](../database/04_views_and_functions.sql)
* **Qué hace:**
  1. Crea `dbo.fn_CalcularHorasResolucion` para medir tiempos de atención.
  2. Crea la vista `dbo.vw_panel_operativo_sla` que cruza tickets, sistemas y técnicos evaluando si cada ticket está `DENTRO DE SLA` o `SLA INCUMPLIDO`.
  3. Crea el trigger `dbo.trg_tickets_SellarResolucion` (*set-based*) que asigna automáticamente `fecha_resolucion = SYSDATETIME()` al cerrar un ticket.

### Paso 1.5: Procedimientos Transaccionales y T-SQL Avanzado
* **Archivo a ejecutar:** [`database/05_procedures_and_tsql.sql`](../database/05_procedures_and_tsql.sql)
* **Qué hace:**
  1. Compila `dbo.usp_ResolverTicketConKB` con manejo de transacciones (`BEGIN TRAN / COMMIT / ROLLBACK`) y excepciones (`TRY / CATCH`).
  2. Ejecuta la consulta analítica avanzada combinando **CTE**, **Window Functions** (`AVG OVER`, `DENSE_RANK`), extracción sobre tipo **`JSON` nativo** (`JSON_VALUE`) y **Expresiones Regulares** (`REGEXP_LIKE`) de SQL Server 2025.

---

## Fase 2: Desarrollo SQL Asistido por IA (Bloque B)

* **Documento de referencia:** [`docs/bloque_b_asistencia_ia.md`](./bloque_b_asistencia_ia.md)
* **Qué documenta:** Registra el prompt enviado al asistente de IA, el código inicial defectuoso sugerido por el modelo (uso de `VARBINARY` en lugar de `VECTOR(384)`, `NVARCHAR` en vez de `JSON` nativo y un trigger escalar incapaz de procesar múltiples filas), las correcciones de ingeniería aplicadas y la prueba empírica de validación.

---

## Fase 3: Seguridad en SQL Server (Bloque C)

### Paso 3.1: Configuración de Roles, Dynamic Data Masking (DDM) y Row-Level Security (RLS)
* **Archivo a ejecutar:** [`database/06_security.sql`](../database/06_security.sql)
* **Qué hace:**
  1. Crea los roles `rol_supervisor_ti`, `rol_tecnico_soporte` y `rol_auditor_externo` aplicando permisos de mínimo privilegio (`GRANT` / `DENY`).
  2. Crea usuarios contenidos sin contraseña (`WITHOUT LOGIN`) para garantizar reproducibilidad local: `halcaide` (Admin), `cmartinez` (BaseDeDatos), `lgomez` (Redes), `asanz` (Finanzas) y `mrodriguez` (Auditoría).
  3. Configura **Dynamic Data Masking** sobre `dbo.usuarios(email)` y `dbo.sistemas(ip_servidor)`.
  4. Despliega la función `sec.fn_rls_predicado_departamento` y la política **Row-Level Security** `sec.Pol_Seguridad_Tickets_Depto` con predicados `FILTER` y `BLOCK`.

### Paso 3.2: Validación Empírica de Seguridad
* **Archivo a ejecutar:** [`tests/test_bloque_c_y_d.sql`](../tests/test_bloque_c_y_d.sql)
* **Evidencia esperada:**
  * Conectado como `halcaide` (`EXECUTE AS USER = 'halcaide'`): ve las IPs en claro (`10.20.10.15`), los emails completos y los tickets de todos los departamentos.
  * Conectado como `lgomez` (`EXECUTE AS USER = 'lgomez'`): ve las IPs enmascaradas (`10..xxx.xxx.15`), los emails ocultos (`hXXX@XXXX.com`), **únicamente los tickets del departamento `Redes`**, y recibe un bloqueo de seguridad si intenta insertar un ticket en el departamento `Finanzas`.

---

## Fase 4: Optimización de Consultas e Indexación (Bloque D)

* **Archivo a ejecutar:** [`database/07_indexes_and_optimization.sql`](../database/07_indexes_and_optimization.sql) (Activar *Incluir Plan de Ejecución Real* con `Ctrl + M` en SSMS antes de ejecutar).
* **Qué hace:**
  1. Inserta un lote histórico de **2.000 tickets** para disponer de un volumen realista de páginas de datos.
  2. Ejecuta la consulta crítica de cola de guardia **ANTES** de optimizar (`SET STATISTICS IO, TIME ON`), evidenciando un `Clustered Index Scan` de alto coste.
  3. Crea el índice no agrupado compuesto, cubriente (`INCLUDE`) y filtrado (`WHERE estado IN ('Abierto', 'En Proceso')`) llamado `IX_tickets_Depto_Severidad_Activos`.
  4. Ejecuta la misma consulta **DESPUÉS** de optimizar, pasando a un `Index Seek` puro sin operadores *Key Lookup* ni *Sort*, reduciendo drásticamente las lecturas lógicas (`logical reads`).

---

## Fase 5: Vectores, Búsqueda Híbrida RRF y Solución RAG (Bloques E, F y G)

### Paso 5.1: Modelos Externos, Embeddings `VECTOR(384)` e Índice DiskANN (Bloque E)
* **Archivo a ejecutar:** [`ai/08_vector_embeddings_and_diskann.sql`](../ai/08_vector_embeddings_and_diskann.sql)
* **Qué hace:**
  1. Registra la credencial y el `EXTERNAL MODEL` (`modelo_embeddings_local_384`) apuntando al modelo de 384 dimensiones.
  2. Crea la función vectorizadora determinista `dbo.fn_GenerarVectorSemantico384` y puebla la columna `contenido_embedding VECTOR(384)` de `dbo.kb_articulos`.
  3. Construye el índice vectorial **`IX_kb_articulos_VectorDiskANN`** (`TYPE = 'DISKANN'`, `METRIC = 'cosine'`) y verifica sus propiedades con `VECTORPROPERTY`.

### Paso 5.2: Búsqueda Léxica, Vectorial y Fusión Híbrida RRF (Bloque F)
* **Archivo a ejecutar:** [`ai/09_intelligent_hybrid_search.sql`](../ai/09_intelligent_hybrid_search.sql)
* **Qué hace:**
  1. Configura el catálogo e índice Full-Text sobre `dbo.kb_articulos`.
  2. Compara la búsqueda exacta KNN (`VECTOR_DISTANCE`) frente a la búsqueda aproximada ANN (`VECTOR_SEARCH`).
  3. Crea y ejecuta el procedimiento `dbo.usp_BusquedaHibridaKB_RRF`, que combina el ranking léxico y el ranking vectorial mediante **Reciprocal Rank Fusion ($k=60$)** para resolver consultas ambiguas de usuarios.

### Paso 5.3: Pipeline RAG Completo y Auditoría de IA (Bloque G)
* **Archivo a ejecutar:** [`ai/10_rag_copilot_solution.sql`](../ai/10_rag_copilot_solution.sql)
* **Qué hace:**
  1. Crea el procedimiento almacenado `dbo.usp_AsistenteRAG_SoporteTI`.
  2. **Retrieval:** Vectoriza el problema del ticket junto con su telemetría JSON y extrae los 3 artículos más relevantes de la KB formateados con `FOR JSON PATH`.
  3. **Augmentation:** Construye el payload estructurado con `JSON_OBJECT` y `JSON_ARRAY` inyectando reglas estrictas de *grounding* para evitar alucinaciones.
  4. **Generation y Trazabilidad:** Invoca el modelo o sintetiza la respuesta fundamentada y registra automáticamente la consulta, el artículo recuperado, la distancia coseno y la latencia en milisegundos dentro de `dbo.auditoria_rag`.