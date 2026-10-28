/* =========================================================================
   ARCHIVO: ai/10_rag_copilot_solution.sql
   DESCRIPCIÓN: Implementación del Bloque G (Modo Nativo Determinista en SSMS):
                1. Retrieval: Vectorización del ticket y extracción de contexto
                   de dbo.kb_articulos en formato JSON (FOR JSON PATH).
                2. Guardrail Semántico: Validación de umbral de distancia coseno
                   (@UmbralDistanciaMax) para bloquear alucinaciones en errores no
                   documentados y escalar automáticamente a Nivel 2.
                3. Augmentation: Construcción del prompt con instrucciones de
                   grounding estricto (JSON_OBJECT / JSON_ARRAY) + telemetría JSON.
                4. Generation & Audit: Síntesis determinista local inmediata (100%
                   reproducible en SSMS sin dependencias externas) y auditoría.
   ========================================================================= */

USE [SysDeskAI];
GO

SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_AsistenteRAG_SoporteTI
    @TicketID INT,
    @UsuarioConsultaID INT = 1,
    @UmbralDistanciaMax FLOAT = 0.25 -- Corte de seguridad anti-alucinaciones
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @InicioTiempo DATETIME2(3) = SYSDATETIME();
    DECLARE @TituloTicket NVARCHAR(200);
    DECLARE @DescripcionTicket NVARCHAR(2000);
    DECLARE @MetadatosJSON NVARCHAR(MAX);
    DECLARE @SistemaAfectado NVARCHAR(100);
    DECLARE @PreguntaCompleta NVARCHAR(3000);

    -- 1. Recuperar los datos del ticket y su telemetría JSON nativa
    SELECT 
        @TituloTicket = t.titulo,
        @DescripcionTicket = t.descripcion_usuario,
        @MetadatosJSON = CAST(t.metadatos_diagnostico AS NVARCHAR(MAX)),
        @SistemaAfectado = s.nombre_sistema
    FROM dbo.tickets t
    INNER JOIN dbo.sistemas s ON t.sistema_id = s.sistema_id
    WHERE t.ticket_id = @TicketID;

    IF @TituloTicket IS NULL
    BEGIN
        ;THROW 50010, 'El ticket especificado no existe o está filtrado por su política RLS.', 1;
    END

    SET @PreguntaCompleta = CONCAT(
        N'Ticket #', @TicketID, N' (', @SistemaAfectado, N'): ', 
        @TituloTicket, N'. Detalle: ', @DescripcionTicket,
        N'. Telemetría JSON: ', ISNULL(@MetadatosJSON, N'{}')
    );

    -- =====================================================================
    -- ETAPA 1: RETRIEVAL (Búsqueda Vectorial Semántica + Contexto FOR JSON PATH)
    -- =====================================================================
    DECLARE @VectorPregunta VECTOR(384) = dbo.fn_GenerarVectorSemantico384(@PreguntaCompleta);
    DECLARE @ArticuloMejorID INT;
    DECLARE @MejorDistancia FLOAT;
    DECLARE @CodigoErrorRecuperado VARCHAR(30);
    DECLARE @TituloKBRecuperado NVARCHAR(200);
    DECLARE @PasosResolucionKB NVARCHAR(MAX);
    DECLARE @ContextoJSON NVARCHAR(MAX);

    -- 1.1 Obtener el artículo más cercano (KNN / DiskANN)
    SELECT TOP (1)
        @ArticuloMejorID = kb.articulo_id,
        @MejorDistancia = CAST(VECTOR_DISTANCE('cosine', @VectorPregunta, kb.contenido_embedding) AS FLOAT),
        @CodigoErrorRecuperado = kb.codigo_error,
        @TituloKBRecuperado = kb.titulo,
        @PasosResolucionKB = kb.procedimiento_resolucion
    FROM dbo.kb_articulos kb
    ORDER BY VECTOR_DISTANCE('cosine', @VectorPregunta, kb.contenido_embedding) ASC;

    -- 1.2 Serializar los 3 artículos más relevantes en formato JSON estructurado
    SET @ContextoJSON = (
        SELECT TOP (3)
            kb.codigo_error AS CodigoArticuloKB,
            kb.titulo AS TituloKB,
            s.nombre_sistema AS SistemaRelacionado,
            kb.sintomas AS SintomasDocumentados,
            kb.procedimiento_resolucion AS PasosResolucionOficiales,
            CAST(VECTOR_DISTANCE('cosine', @VectorPregunta, kb.contenido_embedding) AS DECIMAL(8,5)) AS DistanciaSemanticaCoseno
        FROM dbo.kb_articulos kb
        INNER JOIN dbo.sistemas s ON kb.sistema_id = s.sistema_id
        ORDER BY VECTOR_DISTANCE('cosine', @VectorPregunta, kb.contenido_embedding) ASC
        FOR JSON PATH
    );

    -- =====================================================================
    -- ETAPA 2: AUGMENTATION (Construcción del Payload con JSON_OBJECT)
    -- =====================================================================
    DECLARE @PayloadLLM NVARCHAR(MAX);

    SET @PayloadLLM = JSON_OBJECT(
        'model': 'llama3.2',
        'messages': JSON_ARRAY(
            JSON_OBJECT(
                'role': 'system',
                'content': N'Eres SysDesk AI Copilot, un asistente experto de soporte técnico Nivel 3. ' +
                           N'REGLAS ESTRICTAS DE GROUNDING: ' +
                           N'1. Responde ÚNICAMENTE utilizando los artículos de la Base de Conocimiento (KB) proporcionados en el JSON. ' +
                           N'2. Cita explícitamente el código del artículo (ej. ERR-SEC-AD4740) y correlaciona la telemetría JSON del ticket. ' +
                           N'3. Enumera los pasos exactos de remediación. Si la información no está en el contexto, indícalo sin inventar datos.'
            ),
            JSON_OBJECT(
                'role': 'user',
                'content': N'Contexto KB (JSON): ' + ISNULL(@ContextoJSON, N'[]') + CHAR(10) + CHAR(10) +
                           N'Incidencia a resolver: ' + @PreguntaCompleta
            )
        ),
        'max_completion_tokens': CAST(800 AS INT)
    );

    -- =====================================================================
    -- ETAPA 3: GUARDRAIL SEMÁNTICO Y SÍNTESIS FUNDAMENTADA EN KB
    -- =====================================================================
    DECLARE @RespuestaFinalLLM NVARCHAR(MAX);
    DECLARE @EstadoGuardrail NVARCHAR(50);

    IF @MejorDistancia > @UmbralDistanciaMax
    BEGIN
        SET @EstadoGuardrail = N'BLOQUEADO_POR_UMBRAL (Escalado N2)';
        SET @CodigoErrorRecuperado = 'SIN-COINCIDENCIA-KB';
        SET @RespuestaFinalLLM = CONCAT(
            N'[GUARDRAIL ANTI-ALUCINACIÓN ACTIVADO — ESCALADO A NIVEL 2] ', CHAR(13), CHAR(10),
            N'• Motivo: La distancia semántica del artículo más cercano (', CAST(CAST(@MejorDistancia AS DECIMAL(6,4)) AS NVARCHAR(10)), 
            N') supera el umbral máximo de seguridad permitido (', CAST(CAST(@UmbralDistanciaMax AS DECIMAL(6,4)) AS NVARCHAR(10)), N').', CHAR(13), CHAR(10),
            N'• Acción: No existe un protocolo oficial validado en dbo.kb_articulos para esta incidencia. Se omite la respuesta automática para evitar alucinaciones y se escala el ticket #', @TicketID, N' a Ingeniería de Sistemas.'
        );
    END
    ELSE
    BEGIN
        SET @EstadoGuardrail = N'APROBADO (Grounding Verificado)';
        SET @RespuestaFinalLLM = CONCAT(
            N'[DIAGNÓSTICO FUNDAMENTADO EN KB: ', @CodigoErrorRecuperado, N' — ', @TituloKBRecuperado, N'] ', CHAR(13), CHAR(10),
            N'• Correlación de Telemetría: Se ha analizado el ticket #', @TicketID, 
            N' en el sistema "', @SistemaAfectado, N'" con telemetría ', ISNULL(@MetadatosJSON, N'N/A'), 
            N' (Distancia semántica coseno: ', CAST(CAST(@MejorDistancia AS DECIMAL(6,4)) AS NVARCHAR(10)), N').', CHAR(13), CHAR(10),
            N'• Procedimiento Oficial Recomendado: ', @PasosResolucionKB
        );
    END

    -- =====================================================================
    -- ETAPA 4: REGISTRO EN AUDITORÍA RAG Y DEVOLUCIÓN DE RESULTADOS
    -- =====================================================================
    DECLARE @TiempoMs INT = DATEDIFF(MILLISECOND, @InicioTiempo, SYSDATETIME());

    INSERT INTO dbo.auditoria_rag (
        usuario_consulta_id, pregunta_usuario, articulo_recuperado_id,
        distancia_coseno, contexto_enviado, respuesta_llm, tiempo_respuesta_ms
    )
    VALUES (
        @UsuarioConsultaID, @PreguntaCompleta, @ArticuloMejorID,
        @MejorDistancia, @PayloadLLM, @RespuestaFinalLLM, @TiempoMs
    );

    -- Salida estructurada del asistente
    SELECT 
        @TicketID AS TicketAnalizado,
        @EstadoGuardrail AS ControlCalidadRAG,
        @CodigoErrorRecuperado AS ArticuloKB_Aplicable,
        CAST(@MejorDistancia AS DECIMAL(8,5)) AS DistanciaCoseno,
        @TiempoMs AS LatenciaMs,
        @RespuestaFinalLLM AS RespuestaAsistenteRAG,
        @PayloadLLM AS PromptAumentadoJSON;
END;
GO

-- =========================================================================
-- DEMOSTRACIÓN DE CASOS DE PRUEBA DEL PIPELINE RAG (BLOQUE G)
-- =========================================================================
DECLARE @TicketCaso1 INT = (SELECT TOP 1 ticket_id FROM dbo.tickets WHERE titulo LIKE '%18456%' OR ticket_id = 1002 ORDER BY ticket_id);
DECLARE @TicketCaso2 INT = (SELECT TOP 1 ticket_id FROM dbo.tickets WHERE titulo LIKE '%facturas%' OR ticket_id = 1003 ORDER BY ticket_id DESC);
DECLARE @TicketCaso3 INT = (SELECT TOP 1 ticket_id FROM dbo.tickets WHERE ticket_id NOT IN (@TicketCaso1, @TicketCaso2) ORDER BY ticket_id);

-- Casos 1, 2 y 3: Incidencias documentadas en la KB (Pasan el filtro de umbral)
EXEC dbo.usp_AsistenteRAG_SoporteTI @TicketID = @TicketCaso1, @UsuarioConsultaID = 1;
EXEC dbo.usp_AsistenteRAG_SoporteTI @TicketID = @TicketCaso2, @UsuarioConsultaID = 1;
EXEC dbo.usp_AsistenteRAG_SoporteTI @TicketID = @TicketCaso3, @UsuarioConsultaID = 1;

-- Caso 4: Demostración del Guardrail Anti-Alucinación (Umbral estricto 0.0001)
EXEC dbo.usp_AsistenteRAG_SoporteTI @TicketID = @TicketCaso1, @UsuarioConsultaID = 1, @UmbralDistanciaMax = 0.0001;

-- Verificación de la trazabilidad y auditoría RAG
SELECT TOP (10)
    a.auditoria_id,
    u.username AS tecnico_consulta,
    kb.codigo_error AS kb_mas_cercano,
    CAST(a.distancia_coseno AS DECIMAL(8,5)) AS distancia_coseno,
    a.tiempo_respuesta_ms,
    a.respuesta_llm
FROM dbo.auditoria_rag a
INNER JOIN dbo.usuarios u ON a.usuario_consulta_id = u.usuario_id
INNER JOIN dbo.kb_articulos kb ON a.articulo_recuperado_id = kb.articulo_id
ORDER BY a.auditoria_id DESC;
GO