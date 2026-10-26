/* =========================================================================
   PROYECTO: SysDesk AI (Microsoft DP-800)
   SCRIPT: tests/test_bloque_c_y_d.sql
   DESCRIPCIÓN: Batería de pruebas de validación empírica para capturas de 
                pantalla del Bloque C (Seguridad) y Bloque D (Optimización).
   ========================================================================= */
USE [SysDeskAI];
GO

-- =========================================================================
-- PRUEBA 1: DEMOSTRACIÓN DE DYNAMIC DATA MASKING (DDM) Y ROW-LEVEL SECURITY (RLS)
-- =========================================================================

-- A) PERSPECTIVA DEL SUPERVISOR / ADMINISTRADOR ('halcaide')
-- Resultado esperado:
--   1. Ve TODOS los departamentos en dbo.tickets.
--   2. Ve los emails completos y las IPs reales sin máscara (tiene permiso UNMASK).
EXECUTE AS USER = 'halcaide';
    SELECT 
        USER_NAME() AS UsuarioConectado,
        'Supervisor TI (Admin)' AS RolActivo;

    SELECT TOP 5 usuario_id, username, email, rol, departamento 
    FROM dbo.usuarios;

    SELECT sistema_id, codigo_sistema, nombre_sistema, ip_servidor 
    FROM dbo.sistemas;

    SELECT departamento_responsable, COUNT(*) AS TotalTicketsVisibles
    FROM dbo.tickets
    GROUP BY departamento_responsable;
REVERT;
GO

-- B) PERSPECTIVA DEL TÉCNICO DE REDES ('lgomez')
-- Resultado esperado:
--   1. DDM activo: ve correos como 'hXXX@XXXX.com' e IPs como '10..xxx.xxx.15'.
--   2. RLS activo: al consultar dbo.tickets sin filtro WHERE, el motor SOLO le devuelve 'Redes'.
EXECUTE AS USER = 'lgomez';
    SELECT 
        USER_NAME() AS UsuarioConectado,
        'Técnico Soporte Tier 1 (Redes)' AS RolActivo;

    SELECT TOP 5 usuario_id, username, email, rol, departamento 
    FROM dbo.usuarios;

    SELECT sistema_id, codigo_sistema, nombre_sistema, ip_servidor 
    FROM dbo.sistemas;

    SELECT departamento_responsable, COUNT(*) AS TotalTicketsVisibles
    FROM dbo.tickets
    GROUP BY departamento_responsable;
REVERT;
GO

-- C) PRUEBA DE BLOQUEO DE ESCRITURA RLS (BLOCK PREDICATE) Y DENY DELETE
-- Resultado esperado: Si 'lgomez' (Redes) intenta insertar un ticket para 'Finanzas', RLS lo bloquea.
EXECUTE AS USER = 'lgomez';
    BEGIN TRY
        INSERT INTO dbo.tickets (
            usuario_reporta_id, sistema_id, departamento_responsable, 
            titulo, descripcion_usuario, severidad
        )
        VALUES (6, 4, 'Finanzas', N'Intento de inserción cruzada', N'Prueba de bloqueo RLS', 3);
    END TRY
    BEGIN CATCH
        SELECT 
            ERROR_NUMBER() AS CodigoError,
            ERROR_MESSAGE() AS MensajeSeguridadRLS;
    END CATCH;
REVERT;
GO