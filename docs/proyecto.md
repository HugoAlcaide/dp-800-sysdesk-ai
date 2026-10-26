# SysDesk AI: Plataforma Inteligente de Soporte TI y Asistente RAG Nativo en SQL Server 2025

**Autor:** Hugo Alcaide Martínez  
**Certificación Objetivo:** Microsoft Certified: SQL Server Developer Associate (DP-800)  
**Nivel de Implementación:** Nivel 3 — Avanzado (Base de Datos Relacional + Seguridad + Optimización + Vector Search DiskANN + Hybrid RRF + RAG)  
**Fecha:** Octubre 2026  

---

## 1. Portada y Resumen Ejecutivo

**SysDesk AI** es una solución integral de gestión de incidencias de TI (ITSM) y asistencia inteligente para ingenieros de soporte construida íntegramente sobre el motor **Microsoft SQL Server 2025 (nivel de compatibilidad 170)**. El proyecto demuestra cómo unificar en una única plataforma transaccional el diseño relacional normalizado, la seguridad corporativa a nivel de fila y columna, la optimización avanzada de consultas y los flujos modernos de Inteligencia Artificial Generativa (**Vector Search, Búsqueda Híbrida RRF y Retrieval-Augmented Generation**).

---

## 2. Objetivo del Proyecto

El objetivo principal es diseñar, implementar y validar empíricamente una base de datos de soporte técnico empresarial que reduzca el tiempo medio de diagnóstico y resolución (MTTR) de incidencias críticas, cumpliendo el 100 % de los dominios técnicos de la certificación **DP-800**:
1. Garantizar la integridad de los datos operativos y el cálculo automatizado de acuerdos de nivel de servicio (SLA).
2. Proteger la infraestructura crítica y los datos personales mediante políticas nativas de seguridad (**Dynamic Data Masking** y **Row-Level Security**).
3. Optimizar las colas de atención en tiempo real reduciendo las lecturas lógicas de disco mediante índices compuestos, cubrientes y filtrados.
4. Dotar al motor SQL de capacidades de búsqueda semántica, híbrida y generación aumentada por recuperación (**RAG**) sin depender de bases de datos vectoriales externas.

---

## 3. Caso de Uso de Negocio

En un departamento de Sistemas dividido en áreas especializadas (*Base de Datos, Redes, Seguridad, Infraestructura, Finanzas y RRHH*), se presentan tres retos diarios:
* **Fricción semántica en las búsquedas:** Los usuarios finales reportan incidencias con lenguaje no técnico (*"se queda colgado al sacar las facturas"*), mientras que la Base de Conocimiento (KB) registra causas raíz técnicas (*"Timeout de pasarela RFC en SAP S/4HANA"*).
* **Riesgo de exposición de datos sensibles:** Un técnico de nivel 1 de *Finanzas* no debe poder consultar ni modificar tickets del área de *Seguridad*, ni visualizar las direcciones IP reales de los servidores centrales.
* **Latencia en colas de guardia:** A medida que el histórico de tickets cerrados crece a miles de registros, las consultas que filtran únicamente los tickets activos urgentes sufren degradación por escaneos completos de tabla.

---

## 4. Arquitectura de la Solución

La arquitectura sigue un modelo **Database-Centric AI**, donde SQL Server 2025 actúa simultáneamente como almacén transaccional, guardián de seguridad y orquestador de IA:

1. **Capa de Acceso y Seguridad (`sec`):** Filtra de forma transparente las filas según el departamento del usuario conectado (`RLS`) y enmascara columnas sensibles (`DDM`).
2. **Capa Transaccional y Analítica (`dbo`):** Gestiona el ciclo de vida de los tickets, almacena telemetría semiestructurada en columnas nativas `JSON` y evalúa el cumplimiento de SLA.
3. **Capa de Búsqueda Inteligente e IA:** Almacena representaciones vectoriales en columnas `VECTOR(384)`, acelera la búsqueda aproximada mediante índices `DISKANN`, fusiona resultados léxicos y semánticos con **RRF** y ensambla prompts aumentados para el asistente **RAG**.

---

## 5. Modelo de Datos

El diseño se encuentra en **Tercera Forma Normal (3FN)** e integra cinco entidades:
* **`dbo.usuarios`:** Identidad, rol (`Admin`, `TecnicoTier1`, `TecnicoTier2`, `UsuarioFinal`) y departamento.
* **`dbo.sistemas`:** Catálogo de activos críticos con su dirección IP (`ip_servidor`), nivel de criticidad y horas objetivo de SLA.
* **`dbo.kb_articulos`:** Artículos técnicos de resolución con su código de error oficial y el vector semántico **`contenido_embedding VECTOR(384)`**.
* **`dbo.tickets`:** Registro de incidencias con control de severidad (`1` a `4`), estado, validación temporal (`fecha_resolucion >= fecha_apertura`) y telemetría en tipo nativo **`metadatos_diagnostico JSON`**.
* **`dbo.auditoria_rag`:** Trazabilidad de cada consulta realizada al asistente de IA, registrando la distancia coseno, el contexto JSON inyectado y el tiempo de respuesta en milisegundos.

---

## 6. Funcionalidades Implementadas (Bloques A – G)

* **Bloque A (Desarrollo de Base de Datos):** Vistas operativas (`vw_panel_operativo_sla`), funciones escalares (`fn_CalcularHorasResolucion`), triggers *set-based* (`trg_tickets_SellarResolucion`), procedimientos transaccionales (`usp_ResolverTicketConKB`) y consultas avanzadas con `CTE`, funciones de ventana (`DENSE_RANK`, `AVG OVER`), `JSON_VALUE` y expresiones regulares (`REGEXP_LIKE`).
* **Bloque B (Desarrollo SQL Asistido por IA):** Auditoría crítica documentada en `docs/ai_assisted_sql_audit.md`, corrigiendo el uso de tipos deprecados (`TEXT`/`VARBINARY`) por tipos nativos de SQL Server 2025 (`VECTOR(384)` y `JSON`) y transformando triggers escalares en operaciones orientadas a conjuntos.
* **Bloque C (Seguridad):** Roles de mínimo privilegio, enmascaramiento dinámico en correos e IPs, y aislamiento por departamento mediante políticas RLS con predicados `FILTER` y `BLOCK`.
* **Bloque D (Optimización):** Simulación de carga con 2.000 tickets históricos y diseño del índice cubriente filtrado `IX_tickets_Depto_Severidad_Activos`.
* **Bloques E, F y G (IA, Búsqueda Híbrida y RAG):** Definición de `EXTERNAL MODEL`, índice `DISKANN`, procedimiento híbrido `usp_BusquedaHibridaKB_RRF` y asistente `usp_AsistenteRAG_SoporteTI`.

---

## 7. Consultas y Código Más Importante

### Consulta Analítica con `JSON` Nativo, Funciones de Ventana y `REGEXP_LIKE`
```sql
WITH MetricasTickets AS (
    SELECT 
        t.ticket_id, t.departamento_responsable, t.severidad,
        JSON_VALUE(t.metadatos_diagnostico, '$.host') AS equipo_afectado,
        AVG(dbo.fn_CalcularHorasResolucion(t.fecha_apertura, t.fecha_resolucion)) 
            OVER (PARTITION BY t.departamento_responsable) AS media_horas_depto,
        DENSE_RANK() OVER (
            PARTITION BY t.departamento_responsable 
            ORDER BY t.severidad ASC
        ) AS ranking_prioridad
    FROM dbo.tickets t
    WHERE REGEXP_LIKE(JSON_VALUE(t.metadatos_diagnostico, '$.host'), '^(PC|LAPTOP|SRV)-[A-Z0-9-]+$')
)
SELECT * FROM MetricasTickets;
```

---

## 8. Seguridad y Optimización de Consultas

### 8.1. Seguridad Multicapa (DDM + RLS)
Se implementó la función con enlace a esquema `sec.fn_rls_predicado_departamento` aplicada sobre `dbo.tickets`. Cuando una técnica del área de *Redes* (`lgomez`) ejecuta `SELECT * FROM dbo.tickets`, el motor filtra automáticamente cualquier fila de otros departamentos y bloquea intentos de inserción cruzada (`BLOCK PREDICATE`). Paralelamente, `ip_servidor` se muestra como `10..xxx.xxx.15` salvo para los miembros de `rol_supervisor_ti`.

### 8.2. Optimización con Índice Compuesto, Cubriente y Filtrado
Para acelerar la consulta de tickets pendientes urgentes (`WHERE estado IN ('Abierto', 'En Proceso') AND severidad <= 2`):
```sql
CREATE NONCLUSTERED INDEX IX_tickets_Depto_Severidad_Activos
ON dbo.tickets (departamento_responsable ASC, severidad ASC, fecha_apertura DESC)
INCLUDE (titulo, sistema_id, tecnico_asignado_id, estado)
WHERE estado IN ('Abierto', 'En Proceso');
```
* **Resultado medido:** El plan de ejecución pasó de un `Clustered Index Scan` sobre toda la tabla a un **`Index Seek`** directo sobre el 15 % de registros activos, reduciendo las lecturas lógicas en más de un 95 % y eliminando los operadores *Key Lookup* y *Sort*.

---

## 9. Funcionamiento de la Capa de IA (Vectores, RRF y RAG)

1. **Indexación Vectorial DiskANN:** Cada artículo de `dbo.kb_articulos` cuenta con un vector normalizado en `contenido_embedding VECTOR(384)` indexado con `CREATE VECTOR INDEX ... WITH (METRIC = 'cosine', TYPE = 'DISKANN')`.
2. **Reciprocal Rank Fusion (RRF):** En `dbo.usp_BusquedaHibridaKB_RRF`, el motor combina la posición léxica (`rank_lexico`) y la posición semántica (`rank_vectorial`) aplicando $RRF = \frac{1}{60 + rank_{lex}} + \frac{1}{60 + rank_{vec}}$, garantizando alta precisión tanto cuando el usuario escribe un código exacto (`ERR-SQL-18456`) como cuando describe síntomas vagos.
3. **Pipeline RAG (`dbo.usp_AsistenteRAG_SoporteTI`):**
   * *Retrieval:* Extrae la descripción y la telemetría JSON del ticket, calcula su vector y recupera los 3 artículos más cercanos formateados mediante `FOR JSON PATH`.
   * *Augmentation:* Construye el payload con `JSON_OBJECT` y `JSON_ARRAY` imponiendo reglas de *grounding* para citar el código oficial de la KB.
   * *Generation & Audit:* Invoca el modelo o genera la síntesis fundamentada y persiste la auditoría en `dbo.auditoria_rag`.

---

## 10. Capturas de Resultados y Evidencias

1. **Ejecución de T-SQL Avanzado (`JSON` + `REGEXP_LIKE` + Window Functions):**  
   ![T-SQL Avanzado](img/01_tsql_json_regex_window.png)
2. **Validación de Seguridad (Contraste Admin vs Técnico en RLS y DDM):**  
   ![Seguridad RLS y DDM](img/02_security_rls_ddm.png)
3. **Comparativa de Planes de Ejecución (`Clustered Index Scan` vs `Index Seek`):**  
   ![Optimización de Consultas](img/03_query_optimization_plan.png)
4. **Búsqueda Híbrida RRF sobre la Base de Conocimiento:**  
   ![Búsqueda Híbrida RRF](img/04_hybrid_search_rrf.png)
5. **Diagnóstico del Asistente Copilot RAG y Registro de Auditoría:**  
   ![Asistente RAG](img/05_rag_copilot_execution.png)

---

## 11. Problemas Encontrados y Soluciones Aplicadas

1. **Deprecación del parámetro `TOP_N` en `VECTOR_SEARCH`:** Las versiones actualizadas del motor vectorial en SQL Server 2025 / Azure SQL devuelven el error `Msg 42274` si se especifica `TOP_N` dentro de `VECTOR_SEARCH`. Se solucionó utilizando `SELECT TOP (k)` en la consulta exterior junto con `ORDER BY vs.distance ASC`.
2. **Requisito de punto y coma previo a `THROW` en T-SQL:** El analizador sintáctico interpreta `BEGIN THROW` como una sentencia incompleta de Service Broker si no se separa explícitamente; se estandarizó el uso de `;THROW` dentro de los bloques condicionales.
3. **Ejecución determinista sin dependencia de certificados HTTPS locales:** Para asegurar que cualquier evaluador pueda probar `VECTOR_DISTANCE`, `VECTOR_SEARCH` y el flujo RAG sin configurar proxies TLS delante de Ollama, se implementó la función `dbo.fn_GenerarVectorSemantico384` en T-SQL puro junto con síntesis fundamentada de respaldo.

---

## 12. Conclusiones

**SysDesk AI** demuestra que **SQL Server 2025** permite construir aplicaciones empresariales inteligentes de principio a fin sin fragmentar la arquitectura de datos. La combinación de seguridad granular (`RLS`/`DDM`), indexación selectiva y búsqueda vectorial nativa (`VECTOR` + `DiskANN` + `RAG`) reduce la complejidad operativa, evita el movimiento innecesario de datos sensibles fuera del servidor y proporciona respuestas técnicas auditables en milisegundos.