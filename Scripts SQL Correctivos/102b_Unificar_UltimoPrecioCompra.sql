-- ════════════════════════════════════════════════════════════════════════════════
-- SCRIPT 102b: Unificar costo de cada producto usando el ÚLTIMO precio de compra
-- Base de datos: [DBVENTAS_WEB]
-- Fecha: 2026-05-31
--
-- Variante del script 102. Pone en TODAS las tiendas, para cada producto:
--   CostoPromedio = PrecioUnidadCompra = último precio de compra real registrado.
-- Si el producto no tiene compras, conserva el mayor costo actual (fallback).
--
-- ⚠️ BACKUP antes. PASO 1 diagnóstico, PASO 2 aplicar.
-- ════════════════════════════════════════════════════════════════════════════════

USE [DBVENTAS_WEB]
GO

-- ── PASO 1: ver el último precio de compra que se aplicará a cada producto ──────
SELECT
    p.IdProducto, p.Codigo, p.Nombre,
    (SELECT TOP 1 dc.PrecioUnitarioCompra
       FROM dbo.DETALLE_COMPRA dc
       INNER JOIN dbo.COMPRA c ON c.IdCompra = dc.IdCompra
       WHERE dc.IdProducto = p.IdProducto AND dc.Activo = 1
       ORDER BY c.FechaRegistro DESC)                       AS UltimoPrecioCompra,
    MAX(pt.CostoPromedio)                                    AS CostoActualMax
FROM dbo.PRODUCTO p
INNER JOIN dbo.PRODUCTO_TIENDA pt ON pt.IdProducto = p.IdProducto AND pt.Activo = 1
GROUP BY p.IdProducto, p.Codigo, p.Nombre
ORDER BY p.Nombre;
GO

-- ── PASO 2: APLICAR (descomentar tras revisar el PASO 1) ───────────────────────
/*
BEGIN TRY
    BEGIN TRANSACTION;

    ;WITH Ref AS (
        SELECT
            pt.IdProducto,
            COALESCE(
                (SELECT TOP 1 dc.PrecioUnitarioCompra
                   FROM dbo.DETALLE_COMPRA dc
                   INNER JOIN dbo.COMPRA c ON c.IdCompra = dc.IdCompra
                   WHERE dc.IdProducto = pt.IdProducto AND dc.Activo = 1
                   ORDER BY c.FechaRegistro DESC),
                MAX(NULLIF(pt.CostoPromedio,0)),
                MAX(NULLIF(pt.PrecioUnidadCompra,0))
            ) AS CostoRef
        FROM dbo.PRODUCTO_TIENDA pt
        WHERE pt.Activo = 1
        GROUP BY pt.IdProducto
    )
    UPDATE pt
        SET pt.CostoPromedio      = r.CostoRef,
            pt.PrecioUnidadCompra = r.CostoRef
    FROM dbo.PRODUCTO_TIENDA pt
    INNER JOIN Ref r ON r.IdProducto = pt.IdProducto
    WHERE pt.Activo = 1
      AND r.CostoRef IS NOT NULL;

    PRINT '>> Costos unificados al último precio de compra. Filas: ' + CAST(@@ROWCOUNT AS VARCHAR);
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT '*** ERROR: ' + ERROR_MESSAGE();
    PRINT '*** ROLLBACK: sin cambios.';
END CATCH;
GO
*/

-- ── PASO 3: VERIFICACIÓN — debe dar 0 filas ────────────────────────────────────
-- SELECT p.Codigo, p.Nombre, MIN(pt.CostoPromedio) CostoMin, MAX(pt.CostoPromedio) CostoMax
-- FROM dbo.PRODUCTO_TIENDA pt INNER JOIN dbo.PRODUCTO p ON p.IdProducto=pt.IdProducto
-- WHERE pt.Activo=1
-- GROUP BY p.Codigo, p.Nombre
-- HAVING MIN(ISNULL(pt.CostoPromedio,0)) <> MAX(ISNULL(pt.CostoPromedio,0));
-- GO
