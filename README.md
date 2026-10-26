# SysDesk AI — Intelligent IT Service Management & Native RAG Engine on SQL Server 2025

![SQL Server 2025](https://img.shields.io/badge/Motor-SQL%20Server%202025%20(170)-CC2927?style=for-the-badge&logo=microsoftsqlserver)
![DP-800](https://img.shields.io/badge/Certificación-Microsoft%20DP--800-0078D4?style=for-the-badge&logo=microsoft)
![Nivel Proyecto](https://img.shields.io/badge/Nivel%20de%20Complejidad-Nivel%203%20(Avanzado)-2EA44F?style=for-the-badge)
![AI Ready](https://img.shields.io/badge/AI-Vector%20384d%20%7C%20DiskANN%20%7C%20RAG-8A2BE2?style=for-the-badge)

> **Nivel seleccionado del proyecto:** **Nivel 3 — Avanzado** (Diseño Relacional 3FN + T-SQL Avanzado + Seguridad DDM/RLS + Optimización de Índices + Vector Search `DiskANN` + Búsqueda Híbrida `RRF` + Solución `RAG` Autocontenida).

---

## 1. Descripción y Problema que Resuelve

En los centros de soporte técnico empresarial (IT HelpDesk / ITSM), los ingenieros de guardia pierden hasta un **40 % del tiempo de resolución (MTTR)** buscando procedimientos en bases de conocimiento fragmentadas. Las búsquedas tradicionales basadas en palabras exactas (`LIKE`) fracasan porque el usuario final describe síntomas coloquiales (*"la pantalla se congela al entrar desde casa"*), mientras que la documentación oficial está redactada en lenguaje técnico (*"Fallo de túnel IPSec por bloqueo UDP 500/4500"*).

**SysDesk AI** resuelve este problema integrando la inteligencia artificial **dentro del propio motor de SQL Server 2025 (nivel de compatibilidad 170)**, sin depender de infraestructuras externas complejas:
1. **Gestión Operativa y Telemetría JSON:** Control transaccional de tickets, cálculo automático de acuerdos de nivel de servicio (SLA) y almacenamiento de telemetría de diagnóstico mediante el nuevo tipo de datos nativo **`JSON`**.
2. **Gobierno del Dato y Seguridad Zero-Trust:** Enmascaramiento dinámico (**DDM**) de direcciones IP de servidores y correos corporativos, junto con aislamiento multidepartamental estricto fila a fila mediante **Row-Level Security (RLS)**.
3. **Búsqueda Híbrida Inteligente (RRF):** Fusión de búsqueda léxica (**Full-Text BM25**) y búsqueda semántica aproximada sobre grafos **DiskANN** (**`VECTOR(384)`**) mediante el algoritmo **Reciprocal Rank Fusion**.
4. **Asistente Copilot RAG en T-SQL:** Procedimiento almacenado que recupera los artículos de conocimiento más relevantes, construye un prompt aumentado con reglas de *grounding* (`JSON_OBJECT` / `JSON_ARRAY`), sintetiza la solución técnica y audita cada inferencia en milisegundos.

---

## 2. Arquitectura de la Solución

```text
                       +-----------------------------------+
                       |     Ingeniero / Usuario TI        |
                       +-----------------+-----------------+
                                         |
                                         v
                       +-----------------------------------+
                       |    Aplicación ITSM / SSMS 22      |
                       +-----------------+-----------------+
                                         |
                                         v
+---------------------------------------------------------------------------------+
|                     SQL SERVER 2025 (COMPATIBILITY LEVEL 170)                   |
|                                                                                 |
|  +---------------------------+               +-------------------------------+  |
|  |   Seguridad y Gobierno    |               |   Motor Relacional y T-SQL    |  |
|  | - Row-Level Security (RLS)|               | - 5 Tablas en 3FN + Checks    |  |
|  | - Dynamic Data Masking    |               | - Tipo nativo JSON + Regex    |  |
|  | - Roles Mínimo Privilegio |               | - Vistas SLA, Triggers y CTEs |  |
|  +---------------------------+               +-------------------------------+  |
|                                                                                 |
|  +---------------------------+               +-------------------------------+  |
|  |     Optimización I/O      |               |     Motor Nativo de IA        |  |
|  | - Covering Filtered Index |               | - Tipo nativo VECTOR(384)     |  |
|  | - Eliminación Key Lookups |               | - Índice Vectorial DiskANN    |  |
|  | - Reducción 95% Lecturas  |               | - Hybrid Search (BM25 + RRF)  |  |
|  +---------------------------+               | - Pipeline RAG + Auditoría    |  |
|                                              +---------------+---------------+  |
+--------------------------------------------------------------|------------------+
                                                               |
                                                               v
                                       +---------------------------------------+
                                       |  Modelo Local Embeddings / Inferencia |
                                       |   (Ollama / ONNX / Motor Semántico)   |
                                       +---------------------------------------+
```

---

## 3. Tecnologías Utilizadas

* **Motor de Base de Datos:** Microsoft SQL Server 2025 Developer Edition (`COMPATIBILITY_LEVEL = 170`).
* **Lenguaje:** Transact-SQL (T-SQL) avanzado.
* **Capacidades Nativas SQL 2025:** Tipos de datos `VECTOR(384)` y `JSON`, índice vectorial `DISKANN`, funciones `VECTOR_DISTANCE`, `VECTOR_SEARCH`, `VECTORPROPERTY`, `REGEXP_LIKE`, `JSON_OBJECT`, `JSON_ARRAY` y `sp_invoke_external_rest_endpoint`.
* **Entorno y Control de Versiones:** SQL Server Management Studio (SSMS 22), Git y GitHub.
* **Modelos e Integración IA:** Soporte para `EXTERNAL MODEL` con `Ollama` (`all-minilm` 384d / `llama3.2`) y motor semántico determinista local para ejecución 100 % reproducible sin dependencias externas.

---

## 4. Estructura del Repositorio

```text
dp-800-sysdesk-ai/
│
├── README.md                                          # Documentación principal del proyecto
│
├── database/                                          # Bloques A, C y D (Core, Seguridad y Rendimiento)
│   ├── 01_create_database.sql                         # Creación de BD y nivel de compatibilidad 170
│   ├── 02_create_tables.sql                           # Modelo 3FN, restricciones, JSON y VECTOR(384)
│   ├── 03_insert_data.sql                             # Semilla de datos corporativos de soporte TI
│   ├── 04_views_and_functions.sql                     # Función escalar SLA, Vista analítica y Trigger
│   ├── 05_procedures_and_tsql.sql                     # SP transaccional, CTE, Window Functions y Regex
│   ├── 06_security.sql                                # Roles, Dynamic Data Masking (DDM) y RLS
│   └── 07_indexes_and_optimization.sql                # Simulación de 2.000 tickets e Índice Filtrado
│
├── ai/                                                # Bloques E, F y G (Inteligencia Artificial Nativa)
│   ├── 08_vector_embeddings_and_diskann.sql           # EXTERNAL MODEL, Embeddings 384d e Índice DiskANN
│   ├── 09_intelligent_hybrid_search.sql               # Full-Text, KNN, ANN y Fusión Híbrida RRF
│   └── 10_rag_copilot_solution.sql                    # Procedimiento RAG completo y auditoría de IA
│
├── tests/                                             # Batería de validación empírica
│   └── security_and_performance_validation.sql        # Pruebas multiusuario de RLS, DDM y bloqueos
│
├── docs/                                              # Documentación técnica y evidencias
│   ├── proyecto.md                                    # Memoria técnica completa (Fuente del PDF)
│   ├── SysDesk_AI_Propuesta_Tecnica_DP800.pdf         # Entregable oficial en formato PDF
│   ├── ai_assisted_sql_audit.md                       # Auditoría del Bloque B (Desarrollo SQL con IA)
│   ├── architecture_and_deployment.md                 # Guía técnica detallada de despliegue
│   └── img/                                           # Capturas de ejecución y planes de consulta
│
└── presentation/                                      # Material de defensa del proyecto
    └── dp800-project.pptx                             # Presentación ejecutiva (8 diapositivas)
```

---

## 5. Modelo de Base de Datos

El esquema está normalizado en **Tercera Forma Normal (3FN)** y consta de 5 tablas principales en el esquema `dbo`:

| Tabla | Rol en la Arquitectura | Características Clave e Integridad |
| :--- | :--- | :--- |
| **`dbo.usuarios`** | Catálogo de clientes internos, técnicos (`Tier1`, `Tier2`) y administradores. | `UNIQUE` en `username` y `email`, `CHECK` de formato de correo, enmascaramiento **DDM** en `email` y pivote departamental para **RLS**. |
| **`dbo.sistemas`** | Inventario de infraestructura crítica (Clúster SQL, VPN, AD, SAP, K8s). | Define `criticidad` y `sla_horas_objetivo`. Protege la columna `ip_servidor` mediante **DDM parcial**. |
| **`dbo.kb_articulos`** | Base de conocimiento de errores conocidos y guías de remediación. | Incorpora la columna **`contenido_embedding VECTOR(384)`**, indexada con un grafo **`DISKANN`** e índice **Full-Text**. |
| **`dbo.tickets`** | Entidad transaccional central de incidencias operativas. | Incluye validación temporal (`fecha_resolucion >= fecha_apertura`), columna nativa **`metadatos_diagnostico JSON`**, política **RLS** e índice cubriente filtrado. |
| **`dbo.auditoria_rag`** | Registro inmutable de observabilidad de IA generativa. | Almacena la pregunta, el artículo KB utilizado, la `distancia_coseno`, el prompt JSON enviado y el `tiempo_respuesta_ms`. |

---

## 6. Funcionalidades DP-800 Implementadas

```text
✔ Diseño relacional en 3FN con integridad referencial y restricciones de dominio (Bloque A)
✔ Tipos de datos de última generación en SQL Server 2025: JSON nativo y VECTOR(384) (Bloque A/E)
✔ Objetos programables: Vistas de SLA, Funciones escalares, Triggers set-based y SPs con TRY/CATCH (Bloque A)
✔ Consultas T-SQL avanzadas: CTEs, Window Functions (DENSE_RANK, AVG OVER) y REGEXP_LIKE (Bloque A)
✔ Auditoría crítica de código SQL generado por IA frente a estándares de producción (Bloque B)
✔ Seguridad multicapa: Roles, GRANT/DENY, Dynamic Data Masking (DDM) y Row-Level Security (RLS) (Bloque C)
✔ Optimización empírica: Paso de Clustered Index Scan a Index Seek mediante Índice Cubriente Filtrado (Bloque D)
✔ Creación de EXTERNAL MODEL, generación de embeddings de 384 dimensiones e índice DiskANN (Bloque E)
✔ Búsqueda inteligente: Comparativa Full-Text (BM25) vs Vectorial (KNN/ANN) vs Híbrida con RRF (Bloque F)
✔ Arquitectura RAG end-to-end en T-SQL con grounding estricto y trazabilidad en tabla de auditoría (Bloque G)
```

---

## 7. Guía Rápida de Instalación y Reproducción

El proyecto es **100 % autocontenido y reproducible en local**. No requiere claves privadas de API ni configuraciones externas para ejecutar todas las pruebas:

1. Abrir **SQL Server Management Studio (SSMS 22)** conectado a una instancia de **SQL Server 2025**.
2. Ejecutar en orden los scripts de la carpeta `database/` (`01` al `07`).
3. Ejecutar en orden los scripts de la carpeta `ai/` (`08` al `10`).
4. Ejecutar `tests/security_and_performance_validation.sql` para verificar el comportamiento de RLS y DDM bajo distintos usuarios (`halcaide` vs `lgomez`).

*(Para más detalles sobre cada script, consultar [`docs/architecture_and_deployment.md`](docs/architecture_and_deployment.md)).*

---

## 8. Ejemplos de Ejecución y Resultados Demostrados

### 8.1. T-SQL Avanzado: Extracción `JSON` Nativa, `REGEXP_LIKE` y Window Functions
Ejecución de `database/05_procedures_and_tsql.sql` validando nomenclatura de servidores por expresión regular y calculando rankings de severidad y tiempos medios por departamento:

![T-SQL Avanzado](docs/img/01_tsql_json_regex_window.png)

### 8.2. Seguridad en Acción: Row-Level Security (RLS) y Dynamic Data Masking (DDM)
Ejecución de `tests/security_and_performance_validation.sql`. Mientras el supervisor (`halcaide`) visualiza las IPs reales (`10.20.10.15`) y los 6 departamentos, la técnica de redes (`lgomez`) recibe IPs enmascaradas (`10..xxx.xxx.15`), correos ocultos y **solo visualiza las filas de `Redes`**:

![Seguridad RLS y DDM](docs/img/02_security_rls_ddm.png)

### 8.3. Optimización de Consultas: `Clustered Index Scan` vs `Index Seek` Filtrado
En `database/07_indexes_and_optimization.sql`, sobre un volumen de 2.006 tickets, la creación del índice `IX_tickets_Depto_Severidad_Activos` elimina la lectura completa de la tabla y ordena los resultados directamente desde el árbol B+ sin operador *Sort* ni *Key Lookup*:

![Optimización de Consultas](docs/img/03_query_optimization_plan.png)

### 8.4. Búsqueda Híbrida con Reciprocal Rank Fusion (RRF)
En `ai/09_intelligent_hybrid_search.sql`, `dbo.usp_BusquedaHibridaKB_RRF` combina el ranking léxico y la distancia coseno vectorial ($k=60$) para encontrar el artículo exacto ante descripciones ambiguas del usuario:

![Búsqueda Híbrida RRF](docs/img/04_hybrid_search_rrf.png)

### 8.5. Asistente Copilot RAG y Trazabilidad
En `ai/10_rag_copilot_solution.sql`, `dbo.usp_AsistenteRAG_SoporteTI` cruza la telemetría JSON del ticket con los 3 artículos más cercanos de la KB, construye el payload JSON y registra la inferencia en `dbo.auditoria_rag`:

![Ejecución RAG Copilot](docs/img/05_rag_copilot_execution.png)

---

## 9. Conclusiones

* **Qué se ha aprendido:** SQL Server 2025 consolida en un único motor transaccional capacidades que antes exigían bases de datos vectoriales dedicadas, motores de búsqueda externos y capas de middleware para RAG, manteniendo el gobierno del dato bajo políticas RLS y DDM.
* **Qué problemas surgieron y cómo se resolvieron:**
  1. *Sintaxis actualizada de `VECTOR_SEARCH`:* Las versiones recientes del índice DiskANN no admiten el parámetro explícito `TOP_N` dentro de la función; se resolvió aplicando `SELECT TOP (k)` en la proyección exterior ordenada por `vs.distance ASC`.
  2. *Reproducibilidad offline de embeddings:* Dado que `AI_GENERATE_EMBEDDINGS` exige endpoints HTTPS con certificados TLS válidos, se diseñó en paralelo una función vectorizadora determinista de 384 dimensiones en T-SQL que garantiza que el índice DiskANN, las distancias coseno y el flujo RAG funcionen de inmediato en cualquier máquina local.
  3. *Rendimiento en tablas pequeñas:* Con pocos registros el optimizador prefiere escaneos completos; se inyectó un lote histórico de 2.000 tickets para demostrar empíricamente el impacto real del índice cubriente filtrado en `STATISTICS IO`.
* **Mejoras futuras:** Automatización del refresco de embeddings mediante un trigger asíncrono o cola de Service Broker cuando se publiquen nuevos artículos en `dbo.kb_articulos`, e integración de un frontal interactivo conectado directamente a `dbo.usp_AsistenteRAG_SoporteTI`.