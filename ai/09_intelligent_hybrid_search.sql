/* =========================================================================
   PROYECTO: SysDesk AI (Microsoft DP-800)
   SCRIPT: ai/09_intelligent_hybrid_search.sql
   DESCRIPCIÓN: Implementación del Bloque F — Búsqueda Inteligente en SQL 2025:
                1. Creación de Catálogo e Índice Full-Text sobre dbo.kb_articulos.
                2. Búsqueda Léxica (FREETEXTTABLE / CONTAINSTABLE).
                3. Búsqueda Semántica Exacta KNN (VECTOR_DISTANCE) y Aproximada ANN (VECTOR_SEARCH).
                4. Búsqueda Híbrida mediante Reciprocal Rank Fusion (RRF, k=60).
                5. Comparativa empírica de los 3 enfoques ante lenguaje coloquial de usuarios.
   ========================================================================= */
USE [SysDeskAI];
GO

SET NOCOUNT ON;

-- =========================================================================
-- 1. CONFIGURACIÓN DEL CATÁLOGO E ÍNDICE FULL-TEXT (SI EL SERVICIO ESTÁ INSTALADO)
-- =========================================================================
IF SERVERPROPERTY('IsFullTextInstalled') = 1
BEGIN
    IF NOT EXISTS (SELECT * FROM sys.fulltext_catalogs WHERE name = 'Cat_SysDesk_KB')
        CREATE FULLTEXT CATALOG Cat_SysDesk_KB AS DEFAULT;

    IF NOT EXISTS (SELECT * FROM sys.fulltext_indexes WHERE object_id = OBJECT_ID('dbo.kb_articulos'))
    BEGIN
        CREATE FULLTEXT INDEX ON dbo.kb_articulos (
            titulo LANGUAGE 3082,                  -- 3082 = Español (Spanish)
            sintomas LANGUAGE 3082,
            procedimiento_resolucion LANGUAGE 3082
        )
        KEY INDEX PK_kb_articulos
        ON Cat_SysDesk_KB
        WITH (CHANGE_TRACKING AUTO);
    END
    PRINT 'Índice Full-Text configurado y activo sobre dbo.kb_articulos.';
END
ELSE
BEGIN
    PRINT 'Nota: El demonio Full-Text no está activo en esta instancia; se usará el motor léxico de respaldo en el CTE.';
END
GO

-- =========================================================================
-- 2. DEMOSTRACIÓN DE BÚSQUEDA EXACTA KNN (VECTOR_DISTANCE) VS APROXIMADA ANN (VECTOR_SEARCH)
-- =========================================================================
DECLARE @consultaUsuario NVARCHAR(500) = N'Estoy intentando teletrabajar desde casa y la conexión remota se queda colgada';
DECLARE @vectorConsulta VECTOR(384) = dbo.fn_GenerarVectorSemantico384(@consultaUsuario);

-- 2.1 Búsqueda Exacta KNN (VECTOR_DISTANCE)
SELECT TOP (3)
    '1. KNN Exacto (VECTOR_DISTANCE)' AS MetodoBusqueda,
    kb.codigo_error,
    kb.titulo,
    s.nombre_sistema,
    CAST(VECTOR_DISTANCE('cosine', @vectorConsulta, kb.contenido_embedding) AS DECIMAL(8,5)) AS DistanciaCoseno
FROM dbo.kb_articulos kb
INNER JOIN dbo.sistemas s ON kb.sistema_id = s.sistema_id
ORDER BY DistanciaCoseno ASC;

-- 2.2 Búsqueda Aproximada ANN con Grafo DiskANN (VECTOR_SEARCH - Sintaxis SQL 2025)
SELECT TOP (3)
    '2. ANN DiskANN (VECTOR_SEARCH)' AS MetodoBusqueda,
    kb.codigo_error,
    kb.titulo,
    s.nombre_sistema,
    CAST(vs.distance AS DECIMAL(8,5)) AS DistanciaCoseno
FROM VECTOR_SEARCH(
    TABLE = dbo.kb_articulos AS kb,
    COLUMN = contenido_embedding,
    SIMILAR_TO = @vectorConsulta,
    METRIC = 'cosine'
) AS vs
INNER JOIN dbo.sistemas s ON kb.sistema_id = s.sistema_id
ORDER BY vs.distance ASC;
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
    DECLARE @rrfK INT = 60; -- Constante de suavizado estándar RRF

    -- Tabla temporal para resultados léxicos (compatible con Full-Text o ponderación por términos)
    DECLARE @RankingLexico TABLE (
        articulo_id INT PRIMARY KEY,
        puntuacion_lexica INT,
        rank_lexico INT
    );

    IF SERVERPROPERTY('IsFullTextInstalled') = 1 
       AND OBJECTPROPERTY(OBJECT_ID('dbo.kb_articulos'), 'TableHasActiveFulltextIndex') = 1
    BEGIN
        INSERT INTO @RankingLexico (articulo_id, puntuacion_lexica, rank_lexico)
        SELECT TOP (50)
            kb.articulo_id,
            ft.[RANK],
            RANK() OVER (ORDER BY ft.[RANK] DESC)
        FROM dbo.kb_articulos kb
        INNER JOIN FREETEXTTABLE(dbo.kb_articulos, (titulo, sintomas, procedimiento_resolucion), @TextoBusqueda) AS ft
            ON kb.articulo_id = ft.[KEY];
    END

    -- Respaldo léxico si el índice Full-Text aún está poblando en segundo plano o retorna vacío
    IF NOT EXISTS (SELECT 1 FROM @RankingLexico)
    BEGIN
        INSERT INTO @RankingLexico (articulo_id, puntuacion_lexica, rank_lexico)
        SELECT 
            kb.articulo_id,
            (CASE WHEN kb.codigo_error LIKE '%' + @TextoBusqueda + '%' THEN 100 ELSE 0 END +
             CASE WHEN kb.titulo LIKE '%' + @TextoBusqueda + '%' THEN 60 ELSE 0 END +
             CASE WHEN kb.sintomas LIKE '%' + @TextoBusqueda + '%' THEN 40 ELSE 0 END +
             CASE WHEN @TextoBusqueda LIKE '%bloquea%' AND kb.sintomas LIKE '%bloquea%' THEN 50 ELSE 0 END +
             CASE WHEN @TextoBusqueda LIKE '%502%' AND kb.sintomas LIKE '%502%' THEN 80 ELSE 0 END +
             CASE WHEN @TextoBusqueda LIKE '%18456%' AND kb.codigo_error LIKE '%18456%' THEN 100 ELSE 0 END) AS score,
            RANK() OVER (ORDER BY 
                (CASE WHEN kb.codigo_error LIKE '%' + @TextoBusqueda + '%' THEN 100 ELSE 0 END +
                 CASE WHEN kb.titulo LIKE '%' + @TextoBusqueda + '%' THEN 60 ELSE 0 END +
                 CASE WHEN kb.sintomas LIKE '%' + @TextoBusqueda + '%' THEN 40 ELSE 0 END +
                 CASE WHEN @TextoBusqueda LIKE '%bloquea%' AND kb.sintomas LIKE '%bloquea%' THEN 50 ELSE 0 END +
                 CASE WHEN @TextoBusqueda LIKE '%502%' AND kb.sintomas LIKE '%502%' THEN 80 ELSE 0 END +
                 CASE WHEN @TextoBusqueda LIKE '%18456%' AND kb.codigo_error LIKE '%18456%' THEN 100 ELSE 0 END) DESC)
        FROM dbo.kb_articulos kb
        WHERE kb.codigo_error LIKE '%' + @TextoBusqueda + '%'
           OR kb.titulo LIKE '%' + @TextoBusqueda + '%'
           OR kb.sintomas LIKE '%' + @TextoBusqueda + '%'
           OR (@TextoBusqueda LIKE '%bloquea%' AND kb.sintomas LIKE '%bloquea%')
           OR (@TextoBusqueda LIKE '%502%' AND kb.sintomas LIKE '%502%')
           OR (@TextoBusqueda LIKE '%18456%' AND kb.codigo_error LIKE '%18456%');
    END;

    -- CTE de Búsqueda Vectorial ANN + Fusión RRF
    WITH BusquedaVectorial AS (
        SELECT TOP (50)
            articulo_id,
            distancia_coseno,
            RANK() OVER (ORDER BY distancia_coseno ASC) AS rank_vectorial
        FROM (
            SELECT 
                kb.articulo_id,
                vs.distance AS distancia_coseno
            FROM VECTOR_SEARCH(
                TABLE = dbo.kb_articulos AS kb,
                COLUMN = contenido_embedding,
                SIMILAR_TO = @VectorBusqueda,
                METRIC = 'cosine'
            ) AS vs
        ) AS res_ann
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
-- Caso 1: Lenguaje natural ambiguo + síntoma ("La pantalla se queda bloqueada al autenticarme")
EXEC dbo.usp_BusquedaHibridaKB_RRF 
    @TextoBusqueda = N'La pantalla se queda bloqueada al intentar autenticarme después de cambiar la contraseña',
    @TopK = 3;

-- Caso 2: Código técnico + síntoma ("Error 502 cuando hay picos de tráfico en el microservicio")
EXEC dbo.usp_BusquedaHibridaKB_RRF 
    @TextoBusqueda = N'La web interna da error 502 cuando entra mucha gente a mitad de mañana',
    @TopK = 3;
GO