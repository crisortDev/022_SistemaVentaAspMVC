-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 46 (v2): Normalizar tabla FORMA_COBRO
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-13
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- 1. Agregar columna Nombre si no existe (usa SQL dinámico para evitar error de parse)
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.FORMA_COBRO') AND name = 'Nombre'
)
BEGIN
    ALTER TABLE dbo.FORMA_COBRO ADD Nombre VARCHAR(100) NULL;
    -- Copiar desde Descripcion usando SQL dinámico (columna nueva, no reconocida en parse estático)
    EXEC sp_executesql N'UPDATE dbo.FORMA_COBRO SET Nombre = Descripcion';
    ALTER TABLE dbo.FORMA_COBRO ALTER COLUMN Nombre VARCHAR(100) NOT NULL;
    PRINT 'OK: Columna Nombre agregada y poblada desde Descripcion.';
END
ELSE
    PRINT 'INFO: Columna Nombre ya existe.';
GO

-- 2. Agregar columna Activo si no existe
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.FORMA_COBRO') AND name = 'Activo'
)
BEGIN
    ALTER TABLE dbo.FORMA_COBRO ADD Activo BIT NOT NULL DEFAULT 1;
    PRINT 'OK: Columna Activo agregada (todas activas por defecto).';
END
ELSE
    PRINT 'INFO: Columna Activo ya existe.';
GO

-- 3. Verificar
EXEC sp_executesql N'SELECT IdFormaCobro, Nombre, Activo FROM dbo.FORMA_COBRO ORDER BY Nombre';
GO
