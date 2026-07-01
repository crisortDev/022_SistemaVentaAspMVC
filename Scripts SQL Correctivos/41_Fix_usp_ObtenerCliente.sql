-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 41: Corregir usp_ObtenerCliente
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-12
--
-- Problema: usp_ObtenerCliente no devuelve columnas que CD_Cliente.cs espera:
--   Ciudad, Barrio, Calle, NumeroCasa, Referencia, Geolocalizacion
--   Si alguna no existe en el SP, la capa de datos falla silenciosamente (null).
--
-- Solución:
--   1. Agregar columnas faltantes a la tabla CLIENTE (si no existen)
--   2. CREATE OR ALTER usp_ObtenerCliente con todas las columnas requeridas
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── 1. Agregar columnas faltantes a CLIENTE ───────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.CLIENTE') AND name = 'Ciudad')
    ALTER TABLE dbo.CLIENTE ADD Ciudad NVARCHAR(100) NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.CLIENTE') AND name = 'Barrio')
    ALTER TABLE dbo.CLIENTE ADD Barrio NVARCHAR(100) NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.CLIENTE') AND name = 'Calle')
    ALTER TABLE dbo.CLIENTE ADD Calle NVARCHAR(200) NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.CLIENTE') AND name = 'NumeroCasa')
    ALTER TABLE dbo.CLIENTE ADD NumeroCasa NVARCHAR(20) NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.CLIENTE') AND name = 'Referencia')
    ALTER TABLE dbo.CLIENTE ADD Referencia NVARCHAR(300) NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.CLIENTE') AND name = 'Geolocalizacion')
    ALTER TABLE dbo.CLIENTE ADD Geolocalizacion NVARCHAR(100) NULL;

PRINT 'OK: Columnas de CLIENTE verificadas/agregadas.';
GO

-- ── 2. Actualizar usp_ObtenerCliente con todas las columnas ──────────────────
CREATE OR ALTER PROCEDURE [dbo].[usp_ObtenerCliente]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.IdCliente,
        c.TipoDocumento,
        c.NumeroDocumento,
        c.Nombre,
        ISNULL(c.Direccion, '')      AS Direccion,
        ISNULL(c.Telefono, '')       AS Telefono,
        c.Activo,
        ISNULL(c.Ciudad, '')         AS Ciudad,
        ISNULL(c.Barrio, '')         AS Barrio,
        ISNULL(c.Calle, '')          AS Calle,
        ISNULL(c.NumeroCasa, '')     AS NumeroCasa,
        ISNULL(c.Referencia, '')     AS Referencia,
        c.Geolocalizacion
    FROM dbo.CLIENTE c
    WHERE c.Activo = 1
    ORDER BY c.Nombre;
END
GO

PRINT 'OK: usp_ObtenerCliente actualizado con todas las columnas requeridas.';
GO

-- ── 3. Verificar ─────────────────────────────────────────────────────────────
EXEC dbo.usp_ObtenerCliente;
GO
