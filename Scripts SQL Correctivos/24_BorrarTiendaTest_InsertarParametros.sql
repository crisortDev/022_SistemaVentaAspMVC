-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 24: Eliminar tienda test y configurar PARAMETRO_COMPRA
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-07
--
-- Pasos:
--   1. Elimina PRODUCTO_TIENDA de la tienda test (IdTienda = 5)
--   2. Elimina la tienda test (IdTienda = 5)
--   3. Inserta PARAMETRO_COMPRA para Compu Space Central   (IdTienda = 1)
--   4. Inserta PARAMETRO_COMPRA para Compu Space Sucursal  (IdTienda = 2)
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── PASO 1: Borrar productos de prueba de la tienda test ──────────────────────
DELETE FROM dbo.PRODUCTO_TIENDA WHERE IdTienda = 5;
PRINT 'OK: PRODUCTO_TIENDA de tienda test eliminados (' + CAST(@@ROWCOUNT AS VARCHAR) + ' filas).';

-- ── PASO 2: Borrar la tienda test ─────────────────────────────────────────────
DELETE FROM dbo.TIENDA WHERE IdTienda = 5;
PRINT 'OK: Tienda TEST_OC_TIENDA (IdTienda = 5) eliminada.';
GO

-- ── PASO 3 y 4: Insertar PARAMETRO_COMPRA para las 2 tiendas reales ───────────
--
-- TopeCompraDiario: límite máximo de compras por día por tienda.
-- Ajustá el valor según lo que definas para tu tesis.
--   Central  → Gs. 10.000.000  (tienda principal, mayor volumen)
--   Sucursal → Gs.  5.000.000  (tienda secundaria, menor volumen)
--
-- Si la tienda ya tuviera PARAMETRO_COMPRA no se inserta de nuevo.

IF NOT EXISTS (SELECT 1 FROM dbo.PARAMETRO_COMPRA WHERE IdTienda = 1)
BEGIN
    INSERT INTO dbo.PARAMETRO_COMPRA
        (IdTienda, TopeCompraDiario, Vigente, FechaInicio, FechaFin, FechaRegistro)
    VALUES
        (1, 10000000.00, 1, CAST(GETDATE() AS DATE), NULL, GETDATE());
    PRINT 'OK: PARAMETRO_COMPRA insertado para Compu Space Central (IdTienda = 1). Tope: Gs. 10.000.000';
END
ELSE
    PRINT 'INFO: Compu Space Central ya tenía PARAMETRO_COMPRA.';

IF NOT EXISTS (SELECT 1 FROM dbo.PARAMETRO_COMPRA WHERE IdTienda = 2)
BEGIN
    INSERT INTO dbo.PARAMETRO_COMPRA
        (IdTienda, TopeCompraDiario, Vigente, FechaInicio, FechaFin, FechaRegistro)
    VALUES
        (2, 5000000.00, 1, CAST(GETDATE() AS DATE), NULL, GETDATE());
    PRINT 'OK: PARAMETRO_COMPRA insertado para Compu Space Sucursal (IdTienda = 2). Tope: Gs. 5.000.000';
END
ELSE
    PRINT 'INFO: Compu Space Sucursal ya tenía PARAMETRO_COMPRA.';
GO

-- ── Verificación final ────────────────────────────────────────────────────────
PRINT '══ TIENDAS finales ══';
SELECT IdTienda, RUC, Nombre, Activo FROM dbo.TIENDA ORDER BY IdTienda;

PRINT '══ PARAMETRO_COMPRA final ══';
SELECT
    pc.IdParametro,
    t.Nombre                                        AS Tienda,
    pc.TopeCompraDiario,
    pc.Vigente,
    CONVERT(VARCHAR, pc.FechaInicio, 103)           AS FechaInicio,
    ISNULL(CONVERT(VARCHAR, pc.FechaFin, 103), '—') AS FechaFin
FROM dbo.PARAMETRO_COMPRA pc
INNER JOIN dbo.TIENDA t ON t.IdTienda = pc.IdTienda
ORDER BY pc.IdTienda;
GO

PRINT 'Script 24 completado.'
