USE [SysDeskAI];
GO

-- 1. FUNCIÓN ESCALAR: Calcula las horas transcurridas de un ticket (resuelto o aún abierto)
CREATE OR ALTER FUNCTION dbo.fn_CalcularHorasResolucion (
    @FechaApertura DATETIME2(0),
    @FechaResolucion DATETIME2(0)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @FechaFin DATETIME2(0) = ISNULL(@FechaResolucion, SYSDATETIME());
    RETURN CAST(DATEDIFF(MINUTE, @FechaApertura, @FechaFin) / 60.0 AS DECIMAL(10,2));
END;
GO

-- 2. VISTA ANALÍTICA: Panel de control de tickets y estado de cumplimiento SLA
CREATE OR ALTER VIEW dbo.vw_panel_operativo_sla
AS
SELECT 
    t.ticket_id,
    t.titulo AS titulo_incidencia,
    t.departamento_responsable,
    s.codigo_sistema,
    s.nombre_sistema,
    s.criticidad AS criticidad_sistema,
    u_rep.nombre_completo AS reportado_por,
    ISNULL(u_tec.nombre_completo, N'Sin Asignar') AS tecnico_asignado,
    t.severidad,
    t.estado,
    t.fecha_apertura,
    t.fecha_resolucion,
    dbo.fn_CalcularHorasResolucion(t.fecha_apertura, t.fecha_resolucion) AS horas_transcurridas,
    s.sla_horas_objetivo,
    CASE 
        WHEN dbo.fn_CalcularHorasResolucion(t.fecha_apertura, t.fecha_resolucion) <= s.sla_horas_objetivo 
            THEN 'DENTRO DE SLA'
        ELSE 'SLA INCUMPLIDO'
    END AS estado_sla,
    kb.codigo_error AS kb_asociado
FROM dbo.tickets t
INNER JOIN dbo.sistemas s ON t.sistema_id = s.sistema_id
INNER JOIN dbo.usuarios u_rep ON t.usuario_reporta_id = u_rep.usuario_id
LEFT JOIN dbo.usuarios u_tec ON t.tecnico_asignado_id = u_tec.usuario_id
LEFT JOIN dbo.kb_articulos kb ON t.articulo_kb_aplicado_id = kb.articulo_id;
GO

-- 3. TRIGGER: Sella automáticamente la fecha_resolucion cuando el ticket pasa a 'Resuelto' o 'Cerrado'
CREATE OR ALTER TRIGGER dbo.trg_tickets_SellarResolucion
ON dbo.tickets
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Si el estado cambia a Resuelto/Cerrado y no se indicó fecha_resolucion, asignarla automáticamente
    IF UPDATE(estado)
    BEGIN
        UPDATE t
        SET t.fecha_resolucion = SYSDATETIME()
        FROM dbo.tickets t
        INNER JOIN inserted i ON t.ticket_id = i.ticket_id
        INNER JOIN deleted d ON i.ticket_id = d.ticket_id
        WHERE i.estado IN ('Resuelto', 'Cerrado')
          AND d.estado NOT IN ('Resuelto', 'Cerrado')
          AND i.fecha_resolucion IS NULL;
    END
END;
GO