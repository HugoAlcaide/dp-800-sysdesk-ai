USE [SysDeskAI];
GO

-- 1. STORED PROCEDURE: Registrar y resolver un ticket vinculando un artículo de la KB
CREATE OR ALTER PROCEDURE dbo.usp_ResolverTicketConKB
    @TicketID INT,
    @TecnicoID INT,
    @CodigoErrorKB VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @ArticuloID INT;
        SELECT @ArticuloID = articulo_id 
        FROM dbo.kb_articulos 
        WHERE codigo_error = @CodigoErrorKB;

        IF @ArticuloID IS NULL
            THROW 50001, 'El código de artículo KB indicado no existe en la base de conocimiento.', 1;

        UPDATE dbo.tickets
        SET tecnico_asignado_id = @TecnicoID,
            articulo_kb_aplicado_id = @ArticuloID,
            estado = 'Resuelto' -- El trigger trg_tickets_SellarResolucion asignará la fecha_resolucion
        WHERE ticket_id = @TicketID;

        IF @@ROWCOUNT = 0
            THROW 50002, 'No se encontró el ticket especificado.', 1;

        COMMIT TRANSACTION;
        
        SELECT * FROM dbo.vw_panel_operativo_sla WHERE ticket_id = @TicketID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 2. CONSULTA T-SQL AVANZADA (Cumplimiento estricto del Bloque A):
-- Combina: CTE + Window Functions (DENSE_RANK, AVG OVER) + JSON_VALUE sobre tipo JSON + REGEXP_LIKE (SQL Server 2025)
WITH MetricasTickets AS (
    SELECT 
        t.ticket_id,
        t.departamento_responsable,
        t.titulo,
        t.severidad,
        t.estado,
        dbo.fn_CalcularHorasResolucion(t.fecha_apertura, t.fecha_resolucion) AS horas_resolucion,
        -- Extracción desde columna nativa JSON de SQL Server 2025
        JSON_VALUE(t.metadatos_diagnostico, '$.host') AS equipo_afectado,
        JSON_VALUE(t.metadatos_diagnostico, '$.os') AS sistema_operativo,
        -- Window Function: Tiempo medio de resolución por departamento
        AVG(dbo.fn_CalcularHorasResolucion(t.fecha_apertura, t.fecha_resolucion)) 
            OVER (PARTITION BY t.departamento_responsable) AS media_horas_depto,
        -- Window Function: Ranking de tickets más críticos y lentos por departamento
        DENSE_RANK() OVER (
            PARTITION BY t.departamento_responsable 
            ORDER BY t.severidad ASC, dbo.fn_CalcularHorasResolucion(t.fecha_apertura, t.fecha_resolucion) DESC
        ) AS ranking_prioridad_depto
    FROM dbo.tickets t
    -- Uso de Expresiones Regulares nativas de SQL Server 2025 para validar que el host siga la nomenclatura corporativa
    WHERE REGEXP_LIKE(JSON_VALUE(t.metadatos_diagnostico, '$.host'), '^(PC|LAPTOP|SRV)-[A-Z0-9-]+$')
)
SELECT 
    ticket_id,
    departamento_responsable,
    titulo,
    equipo_afectado,
    sistema_operativo,
    horas_resolucion,
    CAST(media_horas_depto AS DECIMAL(10,2)) AS media_horas_depto,
    ranking_prioridad_depto
FROM MetricasTickets
ORDER BY departamento_responsable, ranking_prioridad_depto;
GO