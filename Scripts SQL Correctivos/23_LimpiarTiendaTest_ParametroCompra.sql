-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 23: Limpiar Tienda de Test y ajustar PARAMETRO_COMPRA
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-07
--
-- Pasos:
--   1. Muestra estructura de PARAMETRO_COMPRA
--   2. Muestra datos actuales de las 3 tiendas
--   3. Elimina PARAMETRO_COMPRA de la tienda test (IdTienda de TEST-OC-RUC-001)
--   4. Elimina la tienda test
--   5. Verifica / inserta PARAMETRO_COMPRA para las 2 tiendas reales
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── PASO 1: Ver columnas de PARAMETRO_COMPRA ──────────────────────────────────
PRINT '══ ESTRUCTURA de PARAMETRO_COMPRA ══';
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'PARAMETRO_COMPRA'
ORDER BY ORDINAL_POSITION;
GO

-- ── PASO 2: Ver situación actual ──────────────────────────────────────────────
PRINT '══ TIENDAS activas ══';
SELECT IdTienda, RUC, Nombre, Activo FROM dbo.TIENDA ORDER BY IdTienda;

PRINT '══ PARAMETRO_COMPRA actual ══';
SELECT * FROM dbo.PARAMETRO_COMPRA ORDER BY IdTienda;
GO

-- ── PASO 3 y 4: Borrar tienda test ───────────────────────────────────────────
DECLARE @IdTiendaTest INT;
SELECT @IdTiendaTest = IdTienda FROM dbo.TIENDA WHERE RUC = 'TEST-OC-RUC-001';

IF @IdTiendaTest IS NOT NULL
BEGIN
    -- Primero eliminar su PARAMETRO_COMPRA (quita la FK que bloqueaba el DELETE)
    DELETE FROM dbo.PARAMETRO_COMPRA WHERE IdTienda = @IdTiendaTest;
    PRINT 'OK: PARAMETRO_COMPRA de tienda test eliminado.';

    -- Luego eliminar la tienda
    DELETE FROM dbo.TIENDA WHERE IdTienda = @IdTiendaTest;
    PRINT 'OK: Tienda TEST-OC-RUC-001 eliminada. IdTienda = ' + CAST(@IdTiendaTest AS VARCHAR);
END
ELSE
    PRINT 'INFO: La tienda test no fue encontrada (ya fue eliminada).';
GO

-- ── PASO 5: Asegurar PARAMETRO_COMPRA para las 2 tiendas reales ───────────────
-- Primero revisá los resultados del PASO 1 para ver las columnas.
-- Este bloque inserta filas faltantes usando los valores de la tienda que ya tenga
-- su PARAMETRO_COMPRA como referencia (copia los mismos parámetros).

DECLARE @IdCentral    INT;
DECLARE @IdSucursal   INT;

SELECT @IdCentral  = IdTienda FROM dbo.TIENDA WHERE RUC = '80012345-6'; -- Compu Space Central
SELECT @IdSucursal = IdTienda FROM dbo.TIENDA WHERE RUC = '80012345-7'; -- Compu Space Sucursal

PRINT 'IdTienda Central  = ' + ISNULL(CAST(@IdCentral  AS VARCHAR), 'NULL');
PRINT 'IdTienda Sucursal = ' + ISNULL(CAST(@IdSucursal AS VARCHAR), 'NULL');

-- Verificar cuáles ya tienen parámetros
IF NOT EXISTS (SELECT 1 FROM dbo.PARAMETRO_COMPRA WHERE IdTienda = @IdCentral)
    PRINT 'WARN: Falta PARAMETRO_COMPRA para Compu Space Central.';
ELSE
    PRINT 'OK: Compu Space Central ya tiene PARAMETRO_COMPRA.';

IF NOT EXISTS (SELECT 1 FROM dbo.PARAMETRO_COMPRA WHERE IdTienda = @IdSucursal)
    PRINT 'WARN: Falta PARAMETRO_COMPRA para Compu Space Sucursal.';
ELSE
    PRINT 'OK: Compu Space Sucursal ya tiene PARAMETRO_COMPRA.';
GO

-- ── PASO 5b: Ver resultado final ──────────────────────────────────────────────
PRINT '══ TIENDAS después de limpieza ══';
SELECT IdTienda, RUC, Nombre, Activo FROM dbo.TIENDA ORDER BY IdTienda;

PRINT '══ PARAMETRO_COMPRA después de limpieza ══';
SELECT * FROM dbo.PARAMETRO_COMPRA ORDER BY IdTienda;
GO
