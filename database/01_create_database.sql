/* =========================================================================
   DESCRIPCIÓN: Inicialización y configuración del entorno SQL Server 2025:
                1. Recreación limpia de la base de datos [SysDeskAI].
                2. Configuración del nivel de compatibilidad 170 (SQL Server 2025).
                3. Habilitación de PREVIEW_FEATURES para soporte de índices DiskANN.
                4. Verificación de metadatos de estado y compatibilidad en sys.databases.
   ========================================================================= */
USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = N'SysDeskAI')
BEGIN
    ALTER DATABASE [SysDeskAI] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [SysDeskAI];
END
GO

CREATE DATABASE [SysDeskAI];
GO

-- Establecer explícitamente el nivel de compatibilidad 170 (SQL Server 2025)
ALTER DATABASE [SysDeskAI] SET COMPATIBILITY_LEVEL = 170;
GO

USE [SysDeskAI];
GO

-- Habilitar características preliminares para soporte completo de índices vectoriales DiskANN
ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
GO

-- Verificar configuración
SELECT 
    name AS DatabaseName, 
    compatibility_level AS CompatibilityLevel,
    state_desc AS Status
FROM sys.databases 
WHERE name = N'SysDeskAI';
GO