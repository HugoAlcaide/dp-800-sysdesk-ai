/* =========================================================================
   DESCRIPCIÓN: Implementación del Bloque C — Seguridad en SQL Server 2025:
                1. Roles personalizados y Principio de Mínimo Privilegio (GRANT/DENY).
                2. Usuarios contenidos de prueba (WITHOUT LOGIN) mapeados a dbo.usuarios.
                3. Dynamic Data Masking (DDM) sobre correos e IPs críticas.
                4. Row-Level Security (RLS) por departamento con Filter y Block Predicates.
   ========================================================================= */
USE [SysDeskAI];
GO

-- =========================================================================
-- 0. LIMPIEZA IDEMPOTENTE (Permite reejecutar el script sin errores)
-- =========================================================================
IF EXISTS (SELECT * FROM sys.security_policies WHERE name = 'Pol_Seguridad_Tickets_Depto')
    DROP SECURITY POLICY sec.Pol_Seguridad_Tickets_Depto;
GO
IF OBJECT_ID('sec.fn_rls_predicado_departamento', 'IF') IS NOT NULL
    DROP FUNCTION sec.fn_rls_predicado_departamento;
GO
IF EXISTS (SELECT * FROM sys.schemas WHERE name = 'sec')
    DROP SCHEMA sec;
GO

-- =========================================================================
-- 1. ROLES DE BASE DE DATOS Y USUARIOS DE PRUEBA (MÍNIMO PRIVILEGIO)
-- =========================================================================
IF DATABASE_PRINCIPAL_ID('rol_supervisor_ti') IS NULL
    CREATE ROLE rol_supervisor_ti;
IF DATABASE_PRINCIPAL_ID('rol_tecnico_soporte') IS NULL
    CREATE ROLE rol_tecnico_soporte;
IF DATABASE_PRINCIPAL_ID('rol_auditor_externo') IS NULL
    CREATE ROLE rol_auditor_externo;
GO

-- Creación de usuarios de BD sin login externo (100% reproducible en local)
-- Los nombres coinciden exactamente con la columna [username] de dbo.usuarios
IF DATABASE_PRINCIPAL_ID('halcaide') IS NULL
    CREATE USER halcaide WITHOUT LOGIN;    -- Admin (Infraestructura)
IF DATABASE_PRINCIPAL_ID('cmartinez') IS NULL
    CREATE USER cmartinez WITHOUT LOGIN;   -- TecnicoTier2 (BaseDeDatos)
IF DATABASE_PRINCIPAL_ID('lgomez') IS NULL
    CREATE USER lgomez WITHOUT LOGIN;      -- TecnicoTier1 (Redes)
IF DATABASE_PRINCIPAL_ID('asanz') IS NULL
    CREATE USER asanz WITHOUT LOGIN;       -- TecnicoTier1 (Finanzas)
IF DATABASE_PRINCIPAL_ID('mrodriguez') IS NULL
    CREATE USER mrodriguez WITHOUT LOGIN;  -- UsuarioFinal (General / Auditoría)
GO

-- Asignación de miembros a roles
ALTER ROLE rol_supervisor_ti ADD MEMBER halcaide;
ALTER ROLE rol_tecnico_soporte ADD MEMBER cmartinez;
ALTER ROLE rol_tecnico_soporte ADD MEMBER lgomez;
ALTER ROLE rol_tecnico_soporte ADD MEMBER asanz;
ALTER ROLE rol_auditor_externo ADD MEMBER mrodriguez;
GO

-- Concesión y denegación de permisos (GRANT / DENY)
-- A) Supervisor TI: Control operativo completo y lectura de todas las tablas
GRANT SELECT, INSERT, UPDATE ON SCHEMA::dbo TO rol_supervisor_ti;
GRANT EXECUTE ON SCHEMA::dbo TO rol_supervisor_ti;

-- B) Técnico de Soporte: Puede leer catálogos, gestionar tickets de su área y usar el SP de resolución
GRANT SELECT ON dbo.usuarios TO rol_tecnico_soporte;
GRANT SELECT ON dbo.sistemas TO rol_tecnico_soporte;
GRANT SELECT ON dbo.kb_articulos TO rol_tecnico_soporte;
GRANT SELECT, INSERT, UPDATE ON dbo.tickets TO rol_tecnico_soporte;
GRANT SELECT ON dbo.vw_panel_operativo_sla TO rol_tecnico_soporte;
GRANT EXECUTE ON dbo.usp_ResolverTicketConKB TO rol_tecnico_soporte;
-- DENY explícito: Un técnico nunca puede borrar tickets ni manipular la auditoría de IA
DENY DELETE ON dbo.tickets TO rol_tecnico_soporte;
DENY INSERT, UPDATE, DELETE ON dbo.auditoria_rag TO rol_tecnico_soporte;

-- C) Usuario Final / Auditor Externo: Solo lectura sobre vistas y tablas generales, sin acceso a KB interna
GRANT SELECT ON dbo.usuarios TO rol_auditor_externo;
GRANT SELECT ON dbo.sistemas TO rol_auditor_externo;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.kb_articulos TO rol_auditor_externo;
GO

-- =========================================================================
-- 2. DYNAMIC DATA MASKING (DDM) — PROTECCIÓN DE DATOS SENSIBLES
-- =========================================================================
-- Enmascarar correo electrónico de usuarios: muestra 'hXXX@XXXX.com'
ALTER TABLE dbo.usuarios
ALTER COLUMN email ADD MASKED WITH (FUNCTION = 'email()');
GO

-- Enmascarar dirección IP de servidores críticos: muestra los 3 primeros caracteres y los 2 últimos
-- Ejemplo: '10.20.10.15' -> '10..xxx.xxx.15'
ALTER TABLE dbo.sistemas
ALTER COLUMN ip_servidor ADD MASKED WITH (FUNCTION = 'partial(3, ".xxx.xxx.", 2)');
GO

-- Conceder permiso UNMASK exclusivamente al rol de supervisores/administradores
GRANT UNMASK TO rol_supervisor_ti;
REVOKE UNMASK FROM rol_tecnico_soporte;
REVOKE UNMASK FROM rol_auditor_externo;
GO

-- =========================================================================
-- 3. ROW-LEVEL SECURITY (RLS) — AISLAMIENTO MULTIDEPARTAMENTAL
-- =========================================================================
CREATE SCHEMA sec AUTHORIZATION dbo;
GO

-- Función de predicado con SCHEMABINDING:
-- Regla: Un usuario ve el ticket si:
--   1. Su username tiene rol 'Admin' en dbo.usuarios (o es 'dbo' en SSMS), O BIEN
--   2. Su departamento en dbo.usuarios coincide con el @departamento_responsable del ticket.
CREATE OR ALTER FUNCTION sec.fn_rls_predicado_departamento (
    @departamento_responsable VARCHAR(40)
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS acceso_permitido
    FROM dbo.usuarios u
    WHERE 
        (
            u.username = USER_NAME() 
            AND (u.rol = 'Admin' OR u.departamento = @departamento_responsable)
            AND u.activo = 1
        )
        OR USER_NAME() = 'dbo';
GO

-- Crear la política de seguridad activando FILTER PREDICATE (lectura) y BLOCK PREDICATE (escritura)
CREATE SECURITY POLICY sec.Pol_Seguridad_Tickets_Depto
    ADD FILTER PREDICATE sec.fn_rls_predicado_departamento(departamento_responsable)
        ON dbo.tickets,
    ADD BLOCK PREDICATE sec.fn_rls_predicado_departamento(departamento_responsable)
        ON dbo.tickets AFTER INSERT,
    ADD BLOCK PREDICATE sec.fn_rls_predicado_departamento(departamento_responsable)
        ON dbo.tickets AFTER UPDATE
WITH (STATE = ON);
GO

PRINT 'Bloque C (Seguridad: Roles, DDM y RLS) configurado correctamente.';
GO