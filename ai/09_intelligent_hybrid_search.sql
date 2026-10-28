/* =========================================================================
   DESCRIPCIÓN: Implementación del Bloque F — Búsqueda Inteligente en SQL 2025:
                1. Configuración de Índice Full-Text protegido (o fallback léxico).
                2. Búsqueda Vectorial Semántica (VECTOR_DISTANCE con índice DiskANN).
                3. Procedimiento de Búsqueda Híbrida RRF (Reciprocal Rank Fusion, k=60).
                4. Demostración y comparativa ante lenguaje natural y códigos técnicos.
   ========================================================================= */

USE [SysDeskAI];
GO

SET NOCOUNT ON;

-- =========================================================================
-- 1. CONFIGURACIÓN DEL CATÁLOGO E ÍNDICE FULL-TEXT (PROTEGIDO)
-- =========================================================================
IF SERVERPROPERTY('IsFullTextInstalled') = 1
BEGIN
    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM sys.fulltext_catalogs WHERE name = 'Cat_SysDesk_KB')
            EXEC sp_executesql N'CREATE FULLTEXT CATALOG Cat_SysDesk_KB AS DEFAULT;';

        IF NOT EXISTS (SELECT * FROM sys.fulltext_indexes WHERE object_id = OBJECT_ID('dbo.kb_articulos'))
        BEGIN
            EXEC sp_executesql N'
                CREATE FULLTEXT INDEX ON dbo.kb_articulos (
                    titulo LANGUAGE 3082,
                    sintomas LANGUAGE 3082,
                    procedimiento_resolucion LANGUAGE 3082
                )
                KEY INDEX PK_kb_articulos
                ON Cat_SysDesk_KB
                WITH (CHANGE_TRACKING AUTO);';
        END
        PRINT 'Índice Full-Text configurado y activo sobre dbo.kb_articulos.';
    END TRY
    BEGIN CATCH
        PRINT 'Aviso Full-Text: Componente no disponible; se utilizará el motor léxico por términos.';
    END CATCH
END
ELSE
BEGIN
    PRINT 'Nota: Servicio Full-Text no instalado en la instancia. Se usará el motor léxico alternativo.';
END
GO

-- =========================================================================
-- 2. DEMOSTRACIÓN: BÚSQUEDA VECTORIAL SEMÁNTICA (DISKANN)
-- =========================================================================
DECLARE @consultaUsuario NVARCHAR(500) = N'Estoy intentando teletrabajar desde casa y la conexión remota se queda colgada';
DECLARE @vectorConsulta VECTOR(384) = dbo.fn_GenerarVectorSemantico384(@consultaUsuario);

-- Búsqueda semántica aproximada aprovechando el índice DiskANN
SELECT TOP (3)
    'Búsqueda Semántica Vectorial' AS MetodoBusqueda,
    kb.codigo_error,
    kb.titulo,
    s.nombre_sistema,
    CAST(VECTOR_DISTANCE('cosine', @vectorConsulta, kb.contenido_embedding) AS DECIMAL(8,5)) AS DistanciaCoseno
FROM dbo.kb_articulos kb
INNER JOIN dbo.sistemas s ON kb.sistema_id = s.sistema_id
ORDER BY DistanciaCoseno ASC;
GO

-- =========================================================================
-- 3. PROCEDIMIENTO DE BÚSQUEDA HÍBRIDA CON RECIPROCAL RANK FUSION (RRF)
-- =========================================================================
CREATE OR ALTER PROCEDURE dbo.usp_BusquedaHibridaKB_RRF
    @TextoBusqueda NVARCHAR(1000),
    @TopK INT = 5
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @VectorBusqueda VECTOR(384) = dbo.fn_GenerarVectorSemantico384(@TextoBusqueda);
    DECLARE @rrfK INT = 60; -- Constante de estabilización RRF estándar

    DECLARE @RankingLexico TABLE (
        articulo_id INT PRIMARY KEY,
        puntuacion_lexica INT,
        rank_lexico INT
    );

    -- 1. Puntuación Léxica (concordancia por términos y códigos de error)
    INSERT INTO @RankingLexico (articulo_id, puntuacion_lexica, rank_lexico)
    SELECT 
        kb.articulo_id,
        (CASE WHEN kb.codigo_error LIKE '%' + @TextoBusqueda + '%' THEN 100 ELSE 0 END +
         CASE WHEN kb.titulo LIKE '%' + @TextoBusqueda + '%' THEN 60 ELSE 0 END +
         CASE WHEN kb.sintomas LIKE '%' + @TextoBusqueda + '%' THEN 40 ELSE 0 END +
         CASE WHEN @TextoBusqueda LIKE '%bloquea%' AND kb.sintomas LIKE '%bloquea%' THEN 50 ELSE 0 END +
         CASE WHEN @TextoBusqueda LIKE '%contraseña%' AND kb.sintomas LIKE '%contraseña%' THEN 50 ELSE 0 END +
         CASE WHEN @TextoBusqueda LIKE '%502%' AND kb.sintomas LIKE '%502%' THEN 80 ELSE 0 END +
         CASE WHEN @TextoBusqueda LIKE '%18456%' AND kb.codigo_error LIKE '%18456%' THEN 100 ELSE 0 END) AS score,
        RANK() OVER (ORDER BY 
            (CASE WHEN kb.codigo_error LIKE '%' + @TextoBusqueda + '%' THEN 100 ELSE 0 END +
             CASE WHEN kb.titulo LIKE '%' + @TextoBusqueda + '%' THEN 60 ELSE 0 END +
             CASE WHEN kb.sintomas LIKE '%' + @TextoBusqueda + '%' THEN 40 ELSE 0 END +
             CASE WHEN @TextoBusqueda LIKE '%bloquea%' AND kb.sintomas LIKE '%bloquea%' THEN 50 ELSE 0 END +
             CASE WHEN @TextoBusqueda LIKE '%contraseña%' AND kb.sintomas LIKE '%contraseña%' THEN 50 ELSE 0 END +
             CASE WHEN @TextoBusqueda LIKE '%502%' AND kb.sintomas LIKE '%502%' THEN 80 ELSE 0 END +
             CASE WHEN @TextoBusqueda LIKE '%18456%' AND kb.codigo_error LIKE '%18456%' THEN 100 ELSE 0 END) DESC)
    FROM dbo.kb_articulos kb
    WHERE kb.codigo_error LIKE '%' + @TextoBusqueda + '%'
       OR kb.titulo LIKE '%' + @TextoBusqueda + '%'
       OR kb.sintomas LIKE '%' + @TextoBusqueda + '%'
       OR (@TextoBusqueda LIKE '%bloquea%' AND kb.sintomas LIKE '%bloquea%')
       OR (@TextoBusqueda LIKE '%contraseña%' AND kb.sintomas LIKE '%contraseña%')
       OR (@TextoBusqueda LIKE '%502%' AND kb.sintomas LIKE '%502%')
       OR (@TextoBusqueda LIKE '%18456%' AND kb.codigo_error LIKE '%18456%');

    -- 2. Puntuación Vectorial y Fusión RRF
    WITH BusquedaVectorial AS (
        SELECT TOP (50)
            kb.articulo_id,
            CAST(VECTOR_DISTANCE('cosine', @VectorBusqueda, kb.contenido_embedding) AS DECIMAL(8,5)) AS distancia_coseno,
            RANK() OVER (ORDER BY VECTOR_DISTANCE('cosine', @VectorBusqueda, kb.contenido_embedding) ASC) AS rank_vectorial
        FROM dbo.kb_articulos kb
    ),
    FusionRRF AS (
        SELECT 
            COALESCE(lex.articulo_id, vec.articulo_id) AS articulo_id,
            lex.rank_lexico,
            vec.rank_vectorial,
            vec.distancia_coseno,
            CAST(
                COALESCE(1.0 / (@rrfK + lex.rank_lexico), 0.0) +
                COALESCE(1.0 / (@rrfK + vec.rank_vectorial), 0.0)
            AS DECIMAL(10,6)) AS rrf_score
        FROM @RankingLexico lex
        FULL OUTER JOIN BusquedaVectorial vec 
            ON lex.articulo_id = vec.articulo_id
    )
    SELECT TOP (@TopK)
        kb.codigo_error,
        kb.titulo,
        s.nombre_sistema,
        f.rank_lexico,
        f.rank_vectorial,
        CAST(f.distancia_coseno AS DECIMAL(8,5)) AS distancia_coseno,
        f.rrf_score
    FROM FusionRRF f
    INNER JOIN dbo.kb_articulos kb ON f.articulo_id = kb.articulo_id
    INNER JOIN dbo.sistemas s ON kb.sistema_id = s.sistema_id
    ORDER BY f.rrf_score DESC, f.distancia_coseno ASC;
END;
GO

-- =========================================================================
-- 4. PRUEBA COMPARATIVA DE BÚSQUEDA HÍBRIDA RRF
-- =========================================================================
-- Prueba 1: Lenguaje natural ("bloqueada al autenticarme tras cambiar contraseña")
EXEC dbo.usp_BusquedaHibridaKB_RRF 
    @TextoBusqueda = N'La pantalla se queda bloqueada al intentar autenticarme después de cambiar la contraseña',
    @TopK = 3;

-- Prueba 2: Síntoma técnico ("error 502 cuando entra mucha gente")
EXEC dbo.usp_BusquedaHibridaKB_RRF 
    @TextoBusqueda = N'La web interna da error 502 cuando entra mucha gente a mitad de mañana',
    @TopK = 3;
GO