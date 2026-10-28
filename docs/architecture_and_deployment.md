# Guía Maestra de Ejecución Paso a Paso — Proyecto SysDesk AI (Microsoft DP-800)

Este documento describe el flujo de despliegue, verificación y auditoría de **SysDesk AI**, referenciando cada script `.sql` y documento técnico del repositorio en el orden exacto de ejecución sobre **SQL Server 2025 (Compatibilidad 170)**.

---

## Estructura General del Repositorio

```text
dp-800-sysdesk-ai/
├── ai/
│   ├── 08_vector_embeddings_and_diskann.sql
│   ├── 09_intelligent_hybrid_search.sql
│   ├── 10_rag_copilot_solution.sql
│   └── 11_rag_ollama_live_endpoint.sql
├── database/
│   ├── 01_create_database.sql
│   ├── 02_create_tables.sql
│   ├── 03_insert_data.sql
│   ├── 04_views_and_functions.sql
│   ├── 05_procedures_and_tsql.sql
│   ├── 06_security.sql
│   └── 07_indexes_and_optimization.sql
├── docs/
│   ├── img/
│   │   ├── 01_tsql_json_regex_window.png
│   │   ├── 02_security_rls_ddm.png
│   │   ├── 03_query_optimization_plan.png
│   │   ├── 04_hybrid_search_rrf.png
│   │   └── 05_rag_copilot_execution.png
│   ├── ai_assisted_sql_audit.md
│   ├── architecture_and_deployment.md
│   ├── proyecto.md
│   └── SysDesk_AI_Propuesta_Tecnica_DP800.pdf
├── presentation/
├── tests/
│   └── security_and_performance_validation.sql
└── README.md
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
* **Captura asociada:** `docs/img/01_tsql_json_regex_window.png`

---

## Fase 2: Desarrollo SQL Asistido por IA (Bloque B)

* **Documento de referencia:** [`docs/ai_assisted_sql_audit.md`](./ai_assisted_sql_audit.md)
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

### Paso 3.2: Validación Empírica de Seguridad y Rendimiento
* **Archivo a ejecutar:** [`tests/security_and_performance_validation.sql`](../tests/security_and_performance_validation.sql)
* **Evidencia esperada:**
  * Conectado como `halcaide` (`EXECUTE AS USER = 'halcaide'`): ve las IPs en claro (`10.20.10.15`), los emails completos y los tickets de todos los departamentos.
  * Conectado como `lgomez` (`EXECUTE AS USER = 'lgomez'`): ve las IPs enmascaradas (`10..xxx.xxx.15`), los emails ocultos (`hXXX@XXXX.com`), **únicamente los tickets del departamento `Redes`**, y recibe un bloqueo de seguridad si intenta insertar un ticket en el departamento `Finanzas`.
* **Captura asociada:** `docs/img/02_security_rls_ddm.png`

---

## Fase 4: Optimización de Consultas e Indexación (Bloque D)

* **Archivo a ejecutar:** [`database/07_indexes_and_optimization.sql`](../database/07_indexes_and_optimization.sql) (Activar *Incluir Plan de Ejecución Real* con `Ctrl + M` en SSMS antes de ejecutar).
* **Qué hace:**
  1. Inserta un lote histórico de **2.000 tickets** para disponer de un volumen realista de páginas de datos.
  2. Ejecuta la consulta crítica de cola de guardia **ANTES** de optimizar (`SET STATISTICS IO, TIME ON`), evidenciando un `Clustered Index Scan` de alto coste (157 lecturas lógicas).
  3. Crea el índice no agrupado compuesto, cubriente (`INCLUDE`) y filtrado (`WHERE estado IN ('Abierto', 'En Proceso')`) llamado `IX_tickets_Depto_Severidad_Activos`.
  4. Ejecuta la misma consulta **DESPUÉS** de optimizar, pasando a un `Index Seek` puro sin operadores *Key Lookup* ni *Sort*, reduciendo las lecturas lógicas a solo 3 páginas (reducción del 98 % de I/O).
* **Captura asociada:** `docs/img/03_query_optimization_plan.png`

---

## Fase 5: Vectores, Búsqueda Híbrida RRF y Solución RAG (Bloques E, F y G)

### Paso 5.1: Modelos Externos, Embeddings `VECTOR(384)` e Índice DiskANN (Bloque E)
* **Archivo a ejecutar:** [`ai/08_vector_embeddings_and_diskann.sql`](../ai/08_vector_embeddings_and_diskann.sql)
* **Qué hace:**
  1. Registra la credencial y el `EXTERNAL MODEL` (`modelo_embeddings_local_384`) apuntando al modelo de 384 dimensiones.
  2. Crea la función vectorizadora determinista `dbo.fn_GenerarVectorSemantico384` y puebla la columna `contenido_embedding VECTOR(384)` de `dbo.kb_articulos`.
  3. Construye el índice vectorial **`IX_kb_articulos_VectorDiskANN`** (`TYPE = 'DISKANN'`, `METRIC = 'cosine'`) y verifica sus propiedades mediante las vistas de catálogo `sys.columns` y `sys.indexes`.

### Paso 5.2: Búsqueda Léxica, Vectorial y Fusión Híbrida RRF (Bloque F)
* **Archivo a ejecutar:** [`ai/09_intelligent_hybrid_search.sql`](../ai/09_intelligent_hybrid_search.sql)
* **Qué hace:**
  1. Configura el catálogo e índice Full-Text sobre `dbo.kb_articulos`.
  2. Ejecuta la búsqueda vectorial semántica calculando la distancia coseno con `VECTOR_DISTANCE`.
  3. Crea y ejecuta el procedimiento `dbo.usp_BusquedaHibridaKB_RRF`, que combina el ranking léxico y el ranking vectorial mediante **Reciprocal Rank Fusion ($k=60$)** para resolver consultas ambiguas de usuarios.
* **Captura asociada:** `docs/img/04_hybrid_search_rrf.png`

### Paso 5.3: Pipeline RAG Determinista con Guardrail Anti-Alucinaciones (Modo SSMS Autónomo)
* **Archivo a ejecutar:** [`ai/10_rag_copilot_solution.sql`](../ai/10_rag_copilot_solution.sql)
* **Qué hace:**
  1. Crea el procedimiento almacenado `dbo.usp_AsistenteRAG_SoporteTI` diseñado para ejecutarse de forma 100 % autónoma en cualquier instancia de SQL Server 2025 sin requerir servicios externos.
  2. **Retrieval:** Vectoriza el problema del ticket junto con su telemetría JSON y extrae los 3 artículos más relevantes de la KB formateados con `FOR JSON PATH`.
  3. **Guardrail Semántico (`@UmbralDistanciaMax = 0.25`):** Evalúa si la distancia coseno del artículo más cercano supera el umbral de seguridad permitido. Si un código de error o síntoma no está documentado en la Base de Conocimiento, bloquea la respuesta automática y escala el ticket a Nivel 2 para evitar alucinaciones.
  4. **Augmentation, Generation y Trazabilidad:** Construye el payload estructurado con `JSON_OBJECT` y `JSON_ARRAY`, sintetiza la respuesta fundamentada en la KB y registra la auditoría completa en `dbo.auditoria_rag`.
* **Captura asociada:** `docs/img/05_rag_copilot_execution.png`

### Paso 5.4 (Opcional): Despliegue e Inferencia RAG en Vivo con Ollama (`llama3.2`)
* **Archivo a ejecutar:** [`ai/11_rag_ollama_live_endpoint.sql`](../ai/11_rag_ollama_live_endpoint.sql)
* **Qué hace:** Habilita `external rest endpoint enabled` a nivel de servidor y crea el procedimiento `dbo.usp_AsistenteRAG_SoporteTI_Live`, conectando SQL Server 2025 mediante `sp_invoke_external_rest_endpoint` con el modelo local **Llama 3.2 (3B)** ejecutándose en Ollama e incorporando el corte de seguridad `@UmbralDistanciaMax` antes de realizar la llamada HTTP.
* **Guía paso a paso para levantar el entorno local en Windows 11 (16 GB RAM):**
  1. **Instalar Ollama y descargar el modelo `llama3.2` (3B parámetros, ~2.0 GB):**
     Abrir PowerShell y ejecutar:
     ```powershell
     irm https://ollama.com/install.ps1 | iex
     ollama run llama3.2
     ```
     *(Una vez descargado el modelo y verificado el prompt `>>>`, escribir `/bye` para salir del chat interactivo).*
  2. **Iniciar el servidor de Ollama permitiendo orígenes externos (Terminal PowerShell 1):**
     Cerrar la aplicación de escritorio de Ollama en la bandeja del sistema (clic derecho $\rightarrow$ *Quit Ollama*) y ejecutar:
     ```powershell
     $env:OLLAMA_ORIGINS="*"
     ollama serve
     ```
  3. **Levantar el túnel HTTPS con reescritura de cabecera Host (Terminal PowerShell 2):**
     Dado que `sp_invoke_external_rest_endpoint` exige endpoints HTTPS con certificados TLS válidos y Ollama bloquea por protección contra *DNS Rebinding* cualquier cabecera `Host` distinta de `localhost` (devolviendo `HTTP 403 Forbidden`), se expone el puerto local `11434` con Cloudflare Quick Tunnels reescribiendo la cabecera:
     ```powershell
     winget install Cloudflare.cloudflared
     cloudflared tunnel --url http://localhost:11434 --http-host-header localhost
     ```
  4. **Ejecución en vivo desde SSMS:**
     Copiar la dirección `https://xxxx.trycloudflare.com` generada por `cloudflared`, asignarla a la variable `@MiTunelActivo` en el script [`ai/11_rag_ollama_live_endpoint.sql`](../ai/11_rag_ollama_live_endpoint.sql) y ejecutar `EXEC dbo.usp_AsistenteRAG_SoporteTI_Live @TicketID = 1002;`.
      #### Validación de Casos en Vivo
      * **Caso de Éxito (Ticket #1002):** Incidencia catalogada (`ERR-SEC-AD4740`). Distancia semántica de `0.00010 <= 0.25`. Ollama sintetiza la resolución oficial en ~34 segundos.
      * **Caso de Bloqueo por Guardrail (Ticket #3009):** Incidencia no documentada de hardware. Distancia semántica de `0.36962 > 0.25`. SQL Server aborta la llamada REST en 11 ms, protegiendo al sistema de alucinaciones y escalando automáticamente a Nivel 2.