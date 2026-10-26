# Auditoría de Desarrollo SQL Asistido por IA (Bloque B — Microsoft DP-800)

En el desarrollo de **SysDesk AI** se emplearon asistentes de IA generativa (GitHub Copilot / LLMs) para acelerar la escritura del esquema inicial y la lógica procedimental. Siguiendo las buenas prácticas de ingeniería de datos de la certificación **DP-800**, todo el código sugerido fue sometido a una auditoría técnica antes de su incorporación a [`database/02_create_tables.sql`](../database/02_create_tables.sql) y [`database/04_views_and_functions.sql`](../database/04_views_and_functions.sql).

---

## 1. Prompt Utilizado

> *"Genera en T-SQL para SQL Server 2025 la tabla `kb_articulos` para almacenar artículos de soporte técnico con un vector de embeddings de 384 dimensiones, la tabla `tickets` con una columna para guardar telemetría de diagnóstico en formato JSON, y un trigger que selle automáticamente la fecha de resolución cuando el ticket pase a estado Resuelto."*

---

## 2. Respuesta Original Generada por la IA (Código con Deficiencias)

```sql
CREATE TABLE dbo.kb_articulos (
    articulo_id INT IDENTITY(1,1) PRIMARY KEY,
    codigo_error VARCHAR(30),
    titulo TEXT,
    procedimiento_resolucion TEXT,
    contenido_embedding VARBINARY(MAX) -- Deficiencia 1: No emplea el tipo nativo VECTOR(384)
);

CREATE TABLE dbo.tickets (
    ticket_id INT IDENTITY(1,1) PRIMARY KEY,
    estado VARCHAR(20),
    fecha_apertura DATETIME,
    fecha_resolucion DATETIME,
    metadatos_diagnostico NVARCHAR(MAX) -- Deficiencia 2: Usa texto plano en lugar del tipo JSON nativo
);
GO

CREATE TRIGGER trg_tickets_SellarResolucion
ON dbo.tickets
AFTER UPDATE
AS
BEGIN
    -- Deficiencia 3: Lógica escalar que falla en actualizaciones de múltiples filas (multi-row UPDATE)
    DECLARE @id INT, @estado VARCHAR(20);
    SELECT @id = ticket_id, @estado = estado FROM inserted;
    IF @estado = 'Resuelto'
        UPDATE dbo.tickets SET fecha_resolucion = GETDATE() WHERE ticket_id = @id;
END;
```

---

## 3. Evaluación Crítica: Qué se Aceptó y Qué se Corrigió

| Componente | Sugerencia de la IA | Corrección Aplicada en Producción | Justificación Técnica (SQL Server 2025) |
| :--- | :--- | :--- | :--- |
| **Almacenamiento de Embeddings** | `VARBINARY(MAX)` | `VECTOR(384) NULL` | El tipo nativo `VECTOR(384)` valida la dimensionalidad e habilita el uso de `VECTOR_DISTANCE`, `VECTOR_SEARCH` e índices `DISKANN`. |
| **Telemetría de Diagnóstico** | `NVARCHAR(MAX)` | `JSON NULL` | El nuevo tipo nativo `JSON` de SQL Server 2025 almacena el documento en formato binario optimizado y valida la sintaxis de forma automática. |
| **Columnas de Texto y Tiempo** | `TEXT` y `DATETIME` | `NVARCHAR(MAX)` y `DATETIME2(0)` | `TEXT` está deprecado; `DATETIME2(0)` ofrece mayor precisión con menor consumo de bytes en almacenamiento. |
| **Lógica del Trigger** | Asignación a variables `@id`, `@estado` | `UPDATE ... FROM dbo.tickets INNER JOIN inserted INNER JOIN deleted` | Si una sentencia `UPDATE` modifica varios tickets a la vez, la versión escalar de la IA ignora todas las filas salvo una. La versión *set-based* procesa lotes completos. |

---

## 4. Verificación Empírica del Código Corregido

El código corregido e implementado en [`database/04_views_and_functions.sql`](../database/04_views_and_functions.sql) se validó mediante una actualización simultánea sobre múltiples registros:

```sql
UPDATE dbo.tickets
SET estado = 'Resuelto'
WHERE ticket_id IN (1002, 1003);

SELECT ticket_id, estado, fecha_apertura, fecha_resolucion
FROM dbo.tickets
WHERE ticket_id IN (1002, 1003);
```

Ambos registros recibieron su marca de tiempo `fecha_resolucion` de forma atómica sin pérdida de datos.