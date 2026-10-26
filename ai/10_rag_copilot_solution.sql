/* =========================================================================
   DESCRIPCIÓN: Implementación del Bloque G — Solución RAG en SQL Server 2025:
                1. Retrieval: Vectorización del ticket y extracción de contexto
                   de dbo.kb_articulos en formato JSON (FOR JSON PATH).
                2. Augmentation: Construcción del prompt con instrucciones de
                   grounding estricto (JSON_OBJECT / JSON_ARRAY) + telemetría JSON.
                3. Generation: Invocación a endpoint LLM mediante sp_invoke_external_rest_endpoint
                   con síntesis determinista de respaldo y registro en dbo.auditoria_rag.
   ========================================================================= */
USE [SysDeskAI];
GO

SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_AsistenteRAG_SoporteTI
    @TicketID INT,
    @UsuarioConsultaID INT = 1,
    @UsarEndpointExterno BIT = 0 -- 1: Invoca sp_invoke_external_rest_endpoint | 0: Síntesis local inmediata
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @InicioTiempo DATETIME2(3) = SYSDATETIME();
    DECLARE @TituloTicket NVARCHAR(200);
    DECLARE @DescripcionTicket NVARCHAR(2000);
    DECLARE @MetadatosJSON NVARCHAR(MAX);
    DECLARE @SistemaAfectado NVARCHAR(100);
    DECLARE @PreguntaCompleta NVARCHAR(3000);

    -- 1. Recuperar los datos del ticket abierto y su telemetría JSON nativa
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
    -- ETAPA 1: RETRIEVAL (Búsqueda Vectorial ANN + Contexto FOR JSON PATH)
    -- =====================================================================
    DECLARE @VectorPregunta VECTOR(384) = dbo.fn_GenerarVectorSemantico384(@PreguntaCompleta);
    DECLARE @ArticuloMejorID INT;
    DECLARE @MejorDistancia FLOAT;
    DECLARE @CodigoErrorRecuperado VARCHAR(30);
    DECLARE @TituloKBRecuperado NVARCHAR(200);
    DECLARE @PasosResolucionKB NVARCHAR(MAX);
    DECLARE @ContextoJSON NVARCHAR(MAX);

    -- Obtener el artículo principal más cercano para trazabilidad en auditoría
    SELECT TOP (1)
        @ArticuloMejorID = kb.articulo_id,
        @MejorDistancia = vs.distance,
        @CodigoErrorRecuperado = kb.codigo_error,
        @TituloKBRecuperado = kb.titulo,
        @PasosResolucionKB = kb.procedimiento_resolucion
    FROM VECTOR_SEARCH(
        TABLE = dbo.kb_articulos AS kb,
        COLUMN = contenido_embedding,
        SIMILAR_TO = @VectorPregunta,
        METRIC = 'cosine'
    ) AS vs
    ORDER BY vs.distance ASC;

    -- Serializar los 3 artículos más relevantes como documento JSON para el LLM
    SET @ContextoJSON = (
        SELECT TOP (3)
            kb.codigo_error AS CodigoArticuloKB,
            kb.titulo AS TituloKB,
            s.nombre_sistema AS SistemaRelacionado,
            kb.sintomas AS SintomasDocumentados,
            kb.procedimiento_resolucion AS PasosResolucionOficiales,
            CAST(vs.distance AS DECIMAL(8,5)) AS DistanciaSemanticaCoseno
        FROM VECTOR_SEARCH(
            TABLE = dbo.kb_articulos AS kb,
            COLUMN = contenido_embedding,
            SIMILAR_TO = @VectorPregunta,
            METRIC = 'cosine'
        ) AS vs
        INNER JOIN dbo.sistemas s ON kb.sistema_id = s.sistema_id
        ORDER BY vs.distance ASC
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
    -- ETAPA 3: GENERATION (Invocación REST o Síntesis Fundamentada Local)
    -- =====================================================================
    DECLARE @RespuestaRaw NVARCHAR(MAX);
    DECLARE @RespuestaFinalLLM NVARCHAR(MAX);
    DECLARE @HttpStatus INT = -1;

    IF @UsarEndpointExterno = 1
    BEGIN
        BEGIN TRY
            EXECUTE @HttpStatus = sp_invoke_external_rest_endpoint
                @url = N'https://localhost:11434/v1/chat/completions',
                @method = 'POST',
                @payload = @PayloadLLM,
                @credential = [https://localhost:11434],
                @response = @RespuestaRaw OUTPUT;

            IF @HttpStatus = 0
                SET @RespuestaFinalLLM = JSON_VALUE(@RespuestaRaw, '$.result.choices[0].message.content');
        END TRY
        BEGIN CATCH
            SET @HttpStatus = ERROR_NUMBER();
        END CATCH
    END

    -- Síntesis fundamentada en los artículos recuperados si no hay endpoint externo activo
    IF @RespuestaFinalLLM IS NULL
    BEGIN
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
        @CodigoErrorRecuperado AS ArticuloKB_Aplicable,
        CAST(@MejorDistancia AS DECIMAL(8,5)) AS DistanciaCoseno,
        @TiempoMs AS LatenciaMs,
        @RespuestaFinalLLM AS RespuestaAsistenteRAG,
        @PayloadLLM AS PromptAumentadoJSON;
END
GO

-- =========================================================================
-- DEMOSTRACIÓN DE CASOS DE PRUEBA DEL PIPELINE RAG (BLOQUE G)
-- =========================================================================
-- Caso 1: Ticket #1002 (Bloqueo recurrente de cuenta de dominio tras cambio de clave - AD Event 4740)
EXEC dbo.usp_AsistenteRAG_SoporteTI @TicketID = 1002, @UsuarioConsultaID = 1;

-- Caso 2: Ticket #1003 (Se cuelga el programa al sacar las facturas del trimestre en SAP)
EXEC dbo.usp_AsistenteRAG_SoporteTI @TicketID = 1003, @UsuarioConsultaID = 1;

-- Caso 3: Ticket #1005 (La web interna da error 502 cuando hay picos de tráfico - Exit Code 137)
EXEC dbo.usp_AsistenteRAG_SoporteTI @TicketID = 1005, @UsuarioConsultaID = 1;

-- Verificar la trazabilidad registrada en la tabla de auditoría RAG
SELECT 
    a.auditoria_id,
    u.username AS tecnico_consulta,
    kb.codigo_error AS kb_utilizado,
    CAST(a.distancia_coseno AS DECIMAL(8,5)) AS distancia_coseno,
    a.tiempo_respuesta_ms,
    a.respuesta_llm
FROM dbo.auditoria_rag a
INNER JOIN dbo.usuarios u ON a.usuario_consulta_id = u.usuario_id
INNER JOIN dbo.kb_articulos kb ON a.articulo_recuperado_id = kb.articulo_id
ORDER BY a.auditoria_id DESC;
GO