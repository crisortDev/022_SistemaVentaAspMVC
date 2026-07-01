-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 102: Unificar costo/precio de cada producto en TODAS las tiendas
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-31
--
-- OBJETIVO (presentación / defensa): que un mismo producto tenga el MISMO
--   CostoPromedio y PrecioUnidadCompra en todas las sucursales, para que no
--   aparezcan filas con costos distintos del mismo producto en el reporte.
--
-- CRITERIO de valor de referencia por producto:
--   Se toma el MÁXIMO CostoPromedio (>0) registrado entre las tiendas
--   (el más representativo / conservador). Si querés el último precio de compra,
--   ver la variante comentada al final.
--
-- ⚠️ BACKUP antes. PASO 1 = diagnóstico. PASO 2 = aplicar (descomentar).
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── PASO 1: DIAGNÓSTICO — productos con costo distinto entre tiendas ────────────
SELECT
    p.IdProducto, p.Codigo, p.Nombre,
    COUNT(*)                                   AS RegistrosTienda,
    MIN(pt.CostoPromedio)                       AS CostoMin,
    MAX(pt.CostoPromedio)                        AS CostoMax,
    MIN(pt.PrecioUnidadCompra)                  AS CompraMin,
    MAX(pt.PrecioUnidadCompra)                  AS CompraMax
FROM dbo.PRODUCTO_TIENDA pt
INNER JOIN dbo.PRODUCTO p ON p.IdProducto = pt.IdProducto
WHERE pt.Activo = 1
GROUP BY p.IdProducto, p.Codigo, p.Nombre
HAVING MIN(ISNULL(pt.CostoPromedio,0)) <> MAX(ISNULL(pt.CostoPromedio,0))
    OR MIN(ISNULL(pt.PrecioUnidadCompra,0)) <> MAX(ISNULL(pt.PrecioUnidadCompra,0))
ORDER BY p.Nombre;
GO

-- ── PASO 2: UNIFICAR (descomentar tras revisar el PASO 1) ──────────────────────
/*
BEGIN TRY
    BEGIN TRANSACTION;

    -- Valor de referencia por producto = MÁXIMO costo promedio (>0) entre tiendas
    ;WITH Ref AS (
        SELECT
            IdProducto,
            MAX(NULLIF(CostoPromedio,0))       AS CostoRef,
            MAX(NULLIF(PrecioUnidadCompra,0))  AS CompraRef
        FROM dbo.PRODUCTO_TIENDA
        WHERE Activo = 1
        GROUP BY IdProducto
    )
    UPDATE pt
        SET pt.CostoPromedio      = COALESCE(r.CostoRef, pt.CostoPromedio),
            pt.PrecioUnidadCompra = COALESCE(r.CompraRef, r.CostoRef, pt.PrecioUnidadCompra)
    FROM dbo.PRODUCTO_TIENDA pt
    INNER JOIN Ref r ON r.IdProducto = pt.IdProducto
    WHERE pt.Activo = 1;

    PRINT '>> Costos/precios unificados por producto. Filas: ' + CAST(@@ROWCOUNT AS VARCHAR);
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT '*** ERROR: ' + ERROR_MESSAGE();
    PRINT '*** ROLLBACK: sin cambios.';
END CATCH;
GO
*/

-- ── PASO 3: VERIFICACIÓN (tras el PASO 2) — debe dar 0 filas ───────────────────
-- SELECT p.Codigo, p.Nombre, MIN(pt.CostoPromedio) CostoMin, MAX(pt.CostoPromedio) CostoMax
-- FROM dbo.PRODUCTO_TIENDA pt INNER JOIN dbo.PRODUCTO p ON p.IdProducto=pt.IdProducto
-- WHERE pt.Activo=1
-- GROUP BY p.Codigo, p.Nombre
-- HAVING MIN(ISNULL(pt.CostoPromedio,0)) <> MAX(ISNULL(pt.CostoPromedio,0));
-- GO

-- ════════════════════════════════════════════════════════════════════════════════
-- VARIANTE (opcional): usar el ÚLTIMO precio de compra en vez del máximo.
-- Reemplazá el CTE Ref por:
--   ;WITH Ref AS (
--       SELECT pt.IdProducto,
--              (SELECT TOP 1 dc.PrecioUnitarioCompra
--               FROM dbo.DETALLE_COMPRA dc
--               INNER JOIN dbo.COMPRA c ON c.IdCompra = dc.IdCompra
--               WHERE dc.IdProducto = pt.IdProducto AND dc.Activo = 1
--               ORDER BY c.FechaRegistro DESC) AS CostoRef,
--              NULL AS CompraRef
--       FROM dbo.PRODUCTO_TIENDA pt GROUP BY pt.IdProducto )
-- ════════════════════════════════════════════════════════════════════════════════
