/* =========================================================================
   DESCRIPCIÓN: Implementación del Bloque D — Optimización de Consultas:
                1. Generación de volumen de datos (2.000 tickets históricos)
                   para análisis realista de páginas de memoria y lecturas lógicas.
                2. Ejecución de consulta crítica de negocio ANTES (Clustered Index Scan).
                3. Creación de Índice No Agrupado Compuesto, Cubriente y Filtrado.
                4. Ejecución de consulta DESPUÉS (Index Seek con reducción drástica de I/O).
   ========================================================================= */
USE [SysDeskAI];
GO

SET NOCOUNT ON;

-- =========================================================================
-- 1. GENERACIÓN DE VOLUMEN PARA PRUEBAS DE RENDIMIENTO (2.000 REGISTROS)
-- =========================================================================
-- Nota: Desactivamos temporalmente la política RLS durante la carga masiva administrativa
ALTER SECURITY POLICY sec.Pol_Seguridad_Tickets_Depto WITH (STATE = OFF);
GO

IF (SELECT COUNT(*) FROM dbo.tickets) < 500
BEGIN
    PRINT 'Insertando 2.000 tickets históricos para simulación de carga e indexación...';

    ;WITH N1(n) AS (SELECT 1 FROM (VALUES (1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) v(n)), -- 10
         N2(n) AS (SELECT 1 FROM N1 a CROSS JOIN N1 b),                                   -- 100
         N3(n) AS (SELECT 1 FROM N2 a CROSS JOIN N1 b),                                   -- 1.000
         Nums(num) AS (SELECT TOP (2000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) FROM N3 a CROSS JOIN N1 b)
    INSERT INTO dbo.tickets (
        usuario_reporta_id, tecnico_asignado_id, sistema_id, departamento_responsable,
        titulo, descripcion_usuario, severidad, estado, fecha_apertura, fecha_resolucion,
        articulo_kb_aplicado_id, metadatos_diagnostico
    )
    SELECT 
        -- Usuarios reportadores (6, 7, 8)
        6 + (num % 3),
        -- Técnicos (1 al 5)
        1 + (num % 5),
        -- Sistemas (1 al 6)
        1 + (num % 6),
        -- Distribución por departamentos
        CASE (num % 6)
            WHEN 0 THEN 'BaseDeDatos'
            WHEN 1 THEN 'Redes'
            WHEN 2 THEN 'Seguridad'
            WHEN 3 THEN 'Finanzas'
            WHEN 4 THEN 'Infraestructura'
            ELSE 'RRHH'
        END,
        CONCAT(N'Incidencia operativa registrada en lote histórico #', num),
        CONCAT(N'Descripción técnica detallada del evento de soporte número ', num, 
               N'. El usuario reporta latencia elevada o interrupción parcial del servicio corporativo.'),
        -- Severidad de 1 a 4
        1 + (num % 4),
        -- El 85% de los tickets están Cerrados/Resueltos y solo el 15% siguen Abiertos/En Proceso
        CASE 
            WHEN (num % 20) = 0 THEN 'Abierto'
            WHEN (num % 20) IN (1, 2) THEN 'En Proceso'
            WHEN (num % 2) = 0 THEN 'Resuelto'
            ELSE 'Cerrado'
        END,
        DATEADD(HOUR, -(num * 2), SYSDATETIME()),
        CASE 
            WHEN (num % 20) IN (0, 1, 2) THEN NULL
            ELSE DATEADD(HOUR, -(num * 2) + 3, SYSDATETIME())
        END,
        CASE WHEN (num % 20) IN (0, 1, 2) THEN NULL ELSE 1 + (num % 6) END,
        CONCAT('{"host":"PC-CORP-', num, '","os":"Windows 11","batch_id":', num, '}')
    FROM Nums;

    PRINT 'Carga de volumen completada.';
END
GO

-- Reactivar la política RLS tras la carga
ALTER SECURITY POLICY sec.Pol_Seguridad_Tickets_Depto WITH (STATE = ON);
GO

-- =========================================================================
-- 2. ESCENARIO "ANTES": SIN ÍNDICE ESPECÍFICO (CLUSTERED INDEX SCAN)
-- =========================================================================
-- Limpiar el índice si existía de una prueba previa
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_tickets_Depto_Severidad_Activos' AND object_id = OBJECT_ID('dbo.tickets'))
    DROP INDEX IX_tickets_Depto_Severidad_Activos ON dbo.tickets;
GO

-- Actualizar estadísticas y limpiar caché para medición limpia
UPDATE STATISTICS dbo.tickets WITH FULLSCAN;
DBCC DROPCLEANBUFFERS;
GO

PRINT '=== EJECUCIÓN ANTES DE OPTIMIZAR (Activa "Incluir Plan de Ejecución Real" Ctrl+M en SSMS) ===';
SET STATISTICS IO, TIME ON;

-- Consulta crítica de negocio: Cola de guardia de tickets activos urgentes de BaseDeDatos
SELECT 
    t.ticket_id,
    t.departamento_responsable,
    t.severidad,
    t.estado,
    t.fecha_apertura,
    t.titulo,
    t.sistema_id,
    t.tecnico_asignado_id
FROM dbo.tickets t
WHERE t.departamento_responsable = 'BaseDeDatos'
  AND t.estado IN ('Abierto', 'En Proceso')
  AND t.severidad <= 2
ORDER BY t.severidad ASC, t.fecha_apertura DESC;

SET STATISTICS IO, TIME OFF;
GO

-- =========================================================================
-- 3. APLICACIÓN DE LA OPTIMIZACIÓN: ÍNDICE COMPUESTO, CUBRIENTE Y FILTRADO
-- =========================================================================
/*
   JUSTIFICACIÓN TÉCNICA DEL ÍNDICE (Para el informe DP-800):
   1. Clave compuesta (departamento_responsable, severidad ASC, fecha_apertura DESC):
      Permite resolver tanto el predicado WHERE como el ORDER BY sin operador de Sort.
   2. Cláusula INCLUDE (titulo, sistema_id, tecnico_asignado_id, estado):
      Convierte el índice en "Covering Index", eliminando el costoso operador Key Lookup.
   3. Cláusula WHERE estado IN ('Abierto', 'En Proceso'):
      Índice Filtrado (Filtered Index) que indexa únicamente el 15% de los tickets vivos,
      ahorrando un 85% de espacio en disco y mantenimiento en escrituras.
*/
CREATE NONCLUSTERED INDEX IX_tickets_Depto_Severidad_Activos
ON dbo.tickets (
    departamento_responsable ASC,
    severidad ASC,
    fecha_apertura DESC
)
INCLUDE (
    titulo,
    sistema_id,
    tecnico_asignado_id,
    estado
)
WHERE estado IN ('Abierto', 'En Proceso');
GO

-- =========================================================================
-- 4. ESCENARIO "DESPUÉS": CON ÍNDICE ESTRATÉGICO (INDEX SEEK PURO)
-- =========================================================================
DBCC DROPCLEANBUFFERS;
GO

PRINT '=== EJECUCIÓN DESPUÉS DE OPTIMIZAR (Index Seek sin Key Lookup ni Sort) ===';
SET STATISTICS IO, TIME ON;

SELECT 
    t.ticket_id,
    t.departamento_responsable,
    t.severidad,
    t.estado,
    t.fecha_apertura,
    t.titulo,
    t.sistema_id,
    t.tecnico_asignado_id
FROM dbo.tickets t
WHERE t.departamento_responsable = 'BaseDeDatos'
  AND t.estado IN ('Abierto', 'En Proceso')
  AND t.severidad <= 2
ORDER BY t.severidad ASC, t.fecha_apertura DESC;

SET STATISTICS IO, TIME OFF;
GO

-- Índice adicional de soporte para llaves foráneas frecuentes en vistas y RAG
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_kb_articulos_sistema_id' AND object_id = OBJECT_ID('dbo.kb_articulos'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_kb_articulos_sistema_id
    ON dbo.kb_articulos (sistema_id)
    INCLUDE (codigo_error, titulo);
END
GO