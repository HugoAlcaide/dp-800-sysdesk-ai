/* =========================================================================
   ARCHIVO: ai/11_rag_ollama_live_endpoint.sql
   DESCRIPCIÓN: Integración RAG en Vivo con Ollama (Llama 3.2 Local) en SQL 2025:
                1. Habilitación de 'external rest endpoint enabled' en el motor.
                2. Procedimiento dbo.usp_AsistenteRAG_SoporteTI_Live que conecta
                   SQL Server 2025 con el servidor local de Ollama a través de
                   Cloudflare Tunnel (HTTPS con rewrite de cabecera Host).
                3. Guardrail Semántico Anti-Alucinaciones: Si la distancia coseno
                   supera @UmbralDistanciaMax (ej. error no documentado),
                   SQL Server aborta la llamada HTTP a Ollama y escala el ticket.
                4. Casos de prueba: Inferencia real en CPU vs. Corte inmediato.
   ========================================================================= */

USE [master];
GO

-- =========================================================================
-- 1. HABILITAR ENDPOINTS REST EXTERNOS A NIVEL DE INSTANCIA SQL SERVER 2025
-- =========================================================================
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO

EXEC sp_configure 'external rest endpoint enabled', 1;
RECONFIGURE;
GO

USE [SysDeskAI];
GO

SET NOCOUNT ON;
GO

-- =========================================================================
-- 2. PROCEDIMIENTO RAG CON CONEXIÓN EN VIVO A OLLAMA (LLAMA 3.2) Y GUARDRAIL
-- =========================================================================
CREATE OR ALTER PROCEDURE dbo.usp_AsistenteRAG_SoporteTI_Live
    @TicketID INT,
    @UsuarioConsultaID INT = 1,
    @UrlTunelCloudflare NVARCHAR(500) = N'https://teaching-contemporary-labeled-surf.trycloudflare.com',
    @UmbralDistanciaMax FLOAT = 0.25 -- Si la distancia es mayor, no invoca a Ollama
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @InicioTiempo DATETIME2(3) = SYSDATETIME();
    DECLARE @TituloTicket NVARCHAR(200);
    DECLARE @DescripcionTicket NVARCHAR(2000);
    DECLARE @MetadatosJSON NVARCHAR(MAX);
    DECLARE @SistemaAfectado NVARCHAR(100);

    -- Recuperar ticket y telemetría JSON
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

    DECLARE @PreguntaCompleta NVARCHAR(3000) = CONCAT(
        N'Ticket #', @TicketID, N' (', @SistemaAfectado, N'): ', 
        @TituloTicket, N'. Detalle: ', @DescripcionTicket,
        N'. Telemetría JSON: ', ISNULL(@MetadatosJSON, N'{}')
    );

    -- 1. Retrieval vectorial semántico
    DECLARE @VectorPregunta VECTOR(384) = dbo.fn_GenerarVectorSemantico384(@PreguntaCompleta);
    DECLARE @ArticuloMejorID INT;
    DECLARE @MejorDistancia FLOAT;
    DECLARE @CodigoErrorRecuperado VARCHAR(30);

    SELECT TOP (1)
        @ArticuloMejorID = kb.articulo_id,
        @MejorDistancia = CAST(VECTOR_DISTANCE('cosine', @VectorPregunta, kb.contenido_embedding) AS FLOAT),
        @CodigoErrorRecuperado = kb.codigo_error
    FROM dbo.kb_articulos kb
    ORDER BY VECTOR_DISTANCE('cosine', @VectorPregunta, kb.contenido_embedding) ASC;

    -- Contexto aumentado formateado como JSON para el LLM
    DECLARE @ContextoJSON NVARCHAR(MAX) = (
        SELECT TOP (3)
            kb.codigo_error AS CodigoArticuloKB,
            kb.titulo AS TituloKB,
            s.nombre_sistema AS SistemaRelacionado,
            kb.procedimiento_resolucion AS PasosResolucionOficiales
        FROM dbo.kb_articulos kb
        INNER JOIN dbo.sistemas s ON kb.sistema_id = s.sistema_id
        ORDER BY VECTOR_DISTANCE('cosine', @VectorPregunta, kb.contenido_embedding) ASC
        FOR JSON PATH
    );

    -- 2. Augmentation: Ensamblar payload JSON para Ollama API (Llama 3.2)
    DECLARE @PayloadLLM NVARCHAR(MAX) = JSON_OBJECT(
        'model': 'llama3.2',
        'stream': CAST(0 AS BIT),
        'messages': JSON_ARRAY(
            JSON_OBJECT(
                'role': 'system', 
                'content': N'Eres SysDesk AI Copilot, asistente de soporte técnico Nivel 3. Responde en español brevemente indicando el código KB oficial aplicable y los pasos numerados de solución según este contexto: ' + @ContextoJSON
            ),
            JSON_OBJECT(
                'role': 'user', 
                'content': @PreguntaCompleta
            )
        )
    );

    -- 3. Guardrail Semántico + Generation (Invocación REST a Ollama)
    DECLARE @RespuestaRaw NVARCHAR(MAX);
    DECLARE @RespuestaFinalLLM NVARCHAR(MAX);
    DECLARE @EstadoGuardrail NVARCHAR(50);
    DECLARE @HttpStatus INT = -1;
    DECLARE @EndpointCompleto NVARCHAR(600) = CONCAT(@UrlTunelCloudflare, N'/v1/chat/completions');

    -- Si la distancia supera el umbral, bloqueamos la llamada al LLM para evitar alucinaciones
    IF @MejorDistancia > @UmbralDistanciaMax
    BEGIN
        SET @EstadoGuardrail = N'BLOQUEADO_SIN_KB (Ollama No Invocado)';
        SET @CodigoErrorRecuperado = 'NO-DOCUMENTADO';
        SET @RespuestaFinalLLM = CONCAT(
            N'AVISO DE SEGURIDAD RAG: La incidencia presenta una distancia semántica de ', 
            CAST(CAST(@MejorDistancia AS DECIMAL(6,4)) AS NVARCHAR(10)), 
            N' (superior al límite de ', CAST(CAST(@UmbralDistanciaMax AS DECIMAL(6,4)) AS NVARCHAR(10)), 
            N'). Al no existir procedimiento oficial en la Base de Conocimiento, se ha cancelado la consulta a Llama 3.2 para evitar alucinaciones. Escale el ticket #', 
            @TicketID, N' al equipo de Nivel 2.'
        );
    END
    ELSE
    BEGIN
        SET @EstadoGuardrail = N'APROBADO (Generado por Llama 3.2)';
        
        EXECUTE @HttpStatus = sp_invoke_external_rest_endpoint
            @url = @EndpointCompleto,
            @method = 'POST',
            @payload = @PayloadLLM,
            @timeout = 120, -- Permite hasta 2 minutos para inferencia local en CPU
            @response = @RespuestaRaw OUTPUT;

        -- Extraer respuesta del JSON devuelto por Ollama
        SET @RespuestaFinalLLM = JSON_VALUE(@RespuestaRaw, '$.result.choices[0].message.content');
        
        IF @RespuestaFinalLLM IS NULL
            SET @RespuestaFinalLLM = JSON_VALUE(@RespuestaRaw, '$.choices[0].message.content');

        IF @RespuestaFinalLLM IS NULL
            SET @RespuestaFinalLLM = CONCAT(N'[HTTP Status: ', @HttpStatus, N'] Respuesta cruda: ', @RespuestaRaw);
    END

    DECLARE @TiempoMs INT = DATEDIFF(MILLISECOND, @InicioTiempo, SYSDATETIME());

    -- 4. Registro en auditoría
    INSERT INTO dbo.auditoria_rag (
        usuario_consulta_id, pregunta_usuario, articulo_recuperado_id, 
        distancia_coseno, contexto_enviado, respuesta_llm, tiempo_respuesta_ms
    )
    VALUES (
        @UsuarioConsultaID, @PreguntaCompleta, @ArticuloMejorID, 
        @MejorDistancia, @PayloadLLM, @RespuestaFinalLLM, @TiempoMs
    );

    -- Devolución del resultado en cuadrícula
    SELECT 
        @TicketID AS TicketAnalizado,
        @EstadoGuardrail AS ControlGuardrail,
        @CodigoErrorRecuperado AS ArticuloRecuperadoKB,
        CAST(@MejorDistancia AS DECIMAL(8,5)) AS DistanciaCoseno,
        @TiempoMs AS LatenciaMilisegundos,
        @RespuestaFinalLLM AS RespuestaGeneradaPorOllama;
END;
GO

-- =========================================================================
-- 3. CASOS DE PRUEBA: INFERENCIA REAL VS. GUARDRAIL SEMÁNTICO
-- =========================================================================
-- Reemplazar por la URL activa generada por: cloudflared tunnel --url http://localhost:11434 --http-host-header localhost
DECLARE @MiTunelActivo NVARCHAR(500) = N'https://teaching-contemporary-labeled-surf.trycloudflare.com';

-- Caso A: Incidencia documentada en KB (Pasa el filtro -> Llama a Ollama ~35s)
EXEC dbo.usp_AsistenteRAG_SoporteTI_Live 
    @TicketID = 1002, 
    @UrlTunelCloudflare = @MiTunelActivo,
    @UmbralDistanciaMax = 0.25;

-- Caso B: Incidencia de hardware no documentada (Activa Guardrail -> 11 ms, Ollama no invocado)
INSERT INTO dbo.tickets (
    usuario_reporta_id, tecnico_asignado_id, sistema_id, departamento_responsable,
    titulo, descripcion_usuario, severidad, estado, metadatos_diagnostico
)
VALUES (
    6, 4, 1, 'Infraestructura',
    N'Fallo de hardware e impresion en planta 2',
    N'La impresora láser hace un ruido extraño en los rodillos y no recoge el papel de la bandeja inferior.',
    3, 'Abierto',
    '{"dispositivo":"HP-LaserJet-P3015","ubicacion":"Planta 2"}'
);

DECLARE @TicketPruebaGuardrail INT = SCOPE_IDENTITY();

EXEC dbo.usp_AsistenteRAG_SoporteTI_Live 
    @TicketID = @TicketPruebaGuardrail, 
    @UrlTunelCloudflare = @MiTunelActivo,
    @UmbralDistanciaMax = 0.25;

-- Verificación en la tabla de auditoría corporativa
SELECT TOP (2)
    auditoria_id,
    fecha_consulta,
    articulo_recuperado_id,
    CAST(distancia_coseno AS DECIMAL(6,4)) AS distancia_coseno,
    tiempo_respuesta_ms,
    LEFT(respuesta_llm, 120) AS resumen_respuesta
FROM dbo.auditoria_rag
ORDER BY auditoria_id DESC;
GO